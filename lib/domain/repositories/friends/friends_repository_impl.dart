import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../../core/database/local_database_service.dart';
import '../../../core/database/collections/local_blocked_user.dart';
import '../../../core/database/collections/local_friend_profile.dart';
import '../../../core/database/collections/local_friend_request.dart';
import '../../../core/database/collections/local_non_friend_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/user_model.dart';
import 'friends_repository.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  FriendsRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  String get _currentUid => _authService.getCurrentUserId()!;

  @override
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    final snap = await _firestoreService
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    final users = snap.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
    await _cacheProfileSnapshots(users, source: 'email_search');
    return users;
  }

  @override
  Future<int> countFriendsForUser(String userId) async {
    try {
      final aggregate = await _firestoreService
          .collection('users')
          .doc(userId)
          .collection('friends')
          .count()
          .get();
      return aggregate.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> probeServerAvailability() {
    return _firestoreService
        .collection('users')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 4));
  }

  @override
  Future<bool> hasUserBlockedTarget(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return false;

    final isar = await _localDatabaseService.database;
    final blocked = await isar.localBlockedUsers.getByBlockedUid(
      normalizedTargetUid,
    );

    return blocked != null && blocked.blockerUid == _currentUid;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchBlockedUsers() async* {
    final isar = await _localDatabaseService.database;

    yield* isar.localBlockedUsers
        .where()
        .anyId()
        .watch(fireImmediately: true)
        .map((items) {
          final owned = items
              .where((item) => item.blockerUid == _currentUid)
              .map(_blockedUserToMap)
              .toList();

          owned.sort((a, b) {
            final aName = a['displayName']?.toString().toLowerCase() ?? '';
            final bName = b['displayName']?.toString().toLowerCase() ?? '';
            return aName.compareTo(bName);
          });
          return owned;
        });
  }

  @override
  Future<void> cacheBlockedUser(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    final isar = await _localDatabaseService.database;
    final profileInfo = await _resolveProfileInfo(isar, normalizedTargetUid);
    final displayName = profileInfo.$1;
    final photoUrl = profileInfo.$2;

    await isar.writeTxn(() async {
      final existing = await isar.localBlockedUsers.getByBlockedUid(
        normalizedTargetUid,
      );
      final model =
          existing ??
          LocalBlockedUser(
            blockedUid: normalizedTargetUid,
            blockerUid: _currentUid,
            displayName: displayName,
          );

      model.blockerUid = _currentUid;
      model.displayName = displayName;
      model.photoURL = photoUrl;
      model.lastSource = 'block_action';
      model.cachedAt = DateTime.now();

      await isar.localBlockedUsers.putByBlockedUid(model);
    });
  }

  @override
  Future<void> removeBlockedUser(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localBlockedUsers.deleteByBlockedUid(normalizedTargetUid);
    });
  }

  @override
  Future<bool> removePendingFriendRequestBetweenUsers({
    required String firstUid,
    required String secondUid,
  }) async {
    final normalizedFirstUid = firstUid.trim();
    final normalizedSecondUid = secondUid.trim();
    if (normalizedFirstUid.isEmpty || normalizedSecondUid.isEmpty) {
      return false;
    }

    final requestIdParts = <String>[normalizedFirstUid, normalizedSecondUid]
      ..sort();
    final normalizedRequestId = requestIdParts.join('_');

    final isar = await _localDatabaseService.database;
    final existingRequest = await isar.localFriendRequests
        .filter()
        .requestIdEqualTo(normalizedRequestId)
        .findFirst();
    if (existingRequest == null) {
      return false;
    }

    await isar.writeTxn(() async {
      await isar.localFriendRequests.delete(existingRequest.id);
    });
    return true;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchIncomingRequests() {
    final uid = _currentUid;
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<LocalFriendRequest>>? localSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;

    controller.onListen = () {
      () async {
        final isar = await _localDatabaseService.database;

        localSub = isar.localFriendRequests
            .filter()
            .toUidEqualTo(uid)
            .statusEqualTo('pending')
            .watch(fireImmediately: true)
            .listen((items) {
              controller.add(
                _sortRequestsByTimestampDesc(
                  items.map(_friendRequestToMap).toList(),
                ),
              );
            }, onError: controller.addError);

        remoteSub = _firestoreService
            .collection('friend_requests')
            .where('toUid', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen((snapshot) async {
              final requests = _sortRequestsByTimestampDesc(
                snapshot.docs
                    .map((doc) => _toRequestMap(doc.id, doc.data()))
                    .toList(),
              );
              await _upsertFriendRequests(requests, uid: uid, isIncoming: true);
              await _cacheProfileSnapshots(
                _requestProfiles(requests),
                source: 'friend_request',
                forceNonFriend: true,
              );
            }, onError: controller.addError);
      }();
    };

    controller.onCancel = () async {
      await localSub?.cancel();
      await remoteSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchOutgoingRequests() {
    final uid = _currentUid;
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<LocalFriendRequest>>? localSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;

    controller.onListen = () {
      () async {
        final isar = await _localDatabaseService.database;

        localSub = isar.localFriendRequests
            .filter()
            .fromUidEqualTo(uid)
            .statusEqualTo('pending')
            .watch(fireImmediately: true)
            .listen((items) {
              controller.add(
                _sortRequestsByTimestampDesc(
                  items.map(_friendRequestToMap).toList(),
                ),
              );
            }, onError: controller.addError);

        remoteSub = _firestoreService
            .collection('friend_requests')
            .where('fromUid', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen((snapshot) async {
              final requests = _sortRequestsByTimestampDesc(
                snapshot.docs
                    .map((doc) => _toRequestMap(doc.id, doc.data()))
                    .toList(),
              );

              final recipientUids = requests
                  .map((request) => request['toUid']?.toString() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList();
              if (recipientUids.isNotEmpty) {
                final recipients = await _fetchUsersByIds(recipientUids);
                await _cacheProfileSnapshots(
                  recipients,
                  source: 'outgoing_request',
                  forceNonFriend: true,
                );
              }

              await _upsertFriendRequests(
                requests,
                uid: uid,
                isIncoming: false,
              );
            }, onError: controller.addError);
      }();
    };

    controller.onCancel = () async {
      await localSub?.cancel();
      await remoteSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchFriendsList() {
    final currentUid = _authService.getCurrentUserId();
    if (currentUid == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<LocalFriendProfile>>? localSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;

    controller.onListen = () {
      () async {
        final isar = await _localDatabaseService.database;

        localSub = isar.localFriendProfiles
            .where()
            .anyId()
            .watch(fireImmediately: true)
            .listen((items) {
              if (controller.isClosed) return;
              controller.add(
                _sortProfilesByDisplayName(
                  items.map(_friendProfileToMap).toList(),
                ),
              );
            }, onError: controller.addError);

        remoteSub = _firestoreService
            .collection('users')
            .doc(currentUid)
            .collection('friends')
            .snapshots()
            .listen((snapshot) async {
              final friendUids = snapshot.docs.map((doc) => doc.id).toList();

              if (friendUids.isEmpty) {
                await _clearFriendProfiles();
                return;
              }

              final users = await _fetchUsersByIds(friendUids);
              await _cacheFriendProfiles(users);
            }, onError: controller.addError);
      }();
    };

    controller.onCancel = () async {
      await localSub?.cancel();
      await remoteSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> _clearFriendProfiles() async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localFriendProfiles.clear();
    });
  }

  List<Map<String, dynamic>> _sortRequestsByTimestampDesc(
    List<Map<String, dynamic>> requests,
  ) {
    requests.sort((a, b) {
      final aTs = _timestampToMillis(a['timestamp']);
      final bTs = _timestampToMillis(b['timestamp']);
      return bTs.compareTo(aTs);
    });
    return requests;
  }

  List<Map<String, dynamic>> _sortProfilesByDisplayName(
    List<Map<String, dynamic>> profiles,
  ) {
    profiles.sort((a, b) {
      final aName = a['displayName']?.toString().toLowerCase() ?? '';
      final bName = b['displayName']?.toString().toLowerCase() ?? '';
      return aName.compareTo(bName);
    });
    return profiles;
  }

  int _timestampToMillis(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  List<Map<String, dynamic>> _requestProfiles(
    List<Map<String, dynamic>> requests,
  ) {
    final profiles = <Map<String, dynamic>>[];

    for (final request in requests) {
      final fromUid = request['fromUid']?.toString();
      if (fromUid == null || fromUid.isEmpty) {
        continue;
      }

      if (fromUid == _currentUid) {
        continue;
      }

      profiles.add({
        'uid': fromUid,
        'displayName': request['senderName']?.toString() ?? 'User',
        'photoURL': request['senderPic']?.toString(),
      });
    }

    return profiles;
  }

  Future<void> _upsertFriendRequests(
    List<Map<String, dynamic>> requests, {
    required String uid,
    required bool isIncoming,
  }) async {
    if (requests.isEmpty) {
      return;
    }

    final isar = await _localDatabaseService.database;
    final requestIds = requests
        .map((request) => request['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final toUids = requests
        .map((request) => request['toUid']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final existingRequests = await isar.localFriendRequests.getAllByRequestId(
      requestIds,
    );
    final existingRequestMap = <String, LocalFriendRequest?>{
      for (var i = 0; i < requestIds.length; i++)
        requestIds[i]: existingRequests[i],
    };

    final resolvedNames = await _resolveDisplayNamesBulk(isar, toUids);
    final resolvedPhotos = await _resolvePhotoUrlsBulk(isar, toUids);
    final seenRequestIds = <String>{};

    await isar.writeTxn(() async {
      for (final request in requests) {
        final requestId = request['id']?.toString();
        final fromUid = request['fromUid']?.toString();
        final toUid = request['toUid']?.toString();
        final senderName = request['senderName']?.toString();
        final recipientNameRaw = request['recipientName']?.toString();
        final recipientPicRaw = request['recipientPic']?.toString();
        final status = request['status']?.toString() ?? 'pending';
        final timestamp = _toDateTime(request['timestamp']) ?? DateTime.now();

        if (requestId == null || requestId.isEmpty) continue;
        if (fromUid == null || fromUid.isEmpty) continue;
        if (toUid == null || toUid.isEmpty) continue;

        seenRequestIds.add(requestId);

        final model = existingRequestMap[requestId] ?? LocalFriendRequest();

        model.requestId = requestId;
        model.fromUid = fromUid;
        model.toUid = toUid;
        model.senderName = senderName?.isNotEmpty == true
            ? senderName!
            : 'User';
        model.senderPic = request['senderPic']?.toString();

        if (recipientNameRaw != null && recipientNameRaw.isNotEmpty) {
          model.recipientName = recipientNameRaw;
        } else {
          model.recipientName = resolvedNames[toUid] ?? 'User';
        }

        if (recipientPicRaw != null && recipientPicRaw.isNotEmpty) {
          model.recipientPic = recipientPicRaw;
        } else {
          model.recipientPic = resolvedPhotos[toUid];
        }

        model.status = status;
        model.timestamp = timestamp;
        model.cachedAt = DateTime.now();

        await isar.localFriendRequests.putByRequestId(model);
      }

      final staleQuery = isIncoming
          ? isar.localFriendRequests.filter().toUidEqualTo(uid)
          : isar.localFriendRequests.filter().fromUidEqualTo(uid);
      final staleItems = await staleQuery.statusEqualTo('pending').findAll();

      for (final item in staleItems) {
        if (!seenRequestIds.contains(item.requestId)) {
          await isar.localFriendRequests.delete(item.id);
        }
      }
    });
  }

  Map<String, dynamic> _friendRequestToMap(LocalFriendRequest item) {
    return {
      'id': item.requestId,
      'requestId': item.requestId,
      'fromUid': item.fromUid,
      'toUid': item.toUid,
      'senderName': item.senderName,
      'senderPic': item.senderPic,
      'recipientName': item.recipientName,
      'recipientPic': item.recipientPic,
      'status': item.status,
      'timestamp': item.timestamp,
      'cachedAt': item.cachedAt,
    };
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchUsersByIds(
    List<String> friendUids,
  ) async {
    if (friendUids.isEmpty) return <Map<String, dynamic>>[];

    final users = <Map<String, dynamic>>[];
    const batchSize = 30;

    for (var index = 0; index < friendUids.length; index += batchSize) {
      final end = index + batchSize > friendUids.length
          ? friendUids.length
          : index + batchSize;
      final batch = friendUids.sublist(index, end);

      final snap = await _firestoreService
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      users.addAll(snap.docs.map((doc) => {'uid': doc.id, ...doc.data()}));
    }

    return users;
  }

  Future<void> _cacheFriendProfiles(List<Map<String, dynamic>> users) async {
    await _cacheProfileSnapshots(
      users,
      source: 'friend_list',
      forceFriend: true,
    );

    final friendUids = users
        .map((user) => user['uid']?.toString() ?? '')
        .where((uid) => uid.isNotEmpty && uid != _currentUid)
        .toSet()
        .toList(growable: false);
    await _deletePendingRequestsForFriendships(friendUids);
  }

  Future<void> _deletePendingRequestsForFriendships(
    List<String> friendUids,
  ) async {
    if (friendUids.isEmpty) {
      return;
    }

    final requestIds = friendUids
        .map((friendUid) => _buildFriendRequestId(_currentUid, friendUid))
        .toSet()
        .toList(growable: false);
    if (requestIds.isEmpty) {
      return;
    }

    final isar = await _localDatabaseService.database;
    final existingRequests = await isar.localFriendRequests.getAllByRequestId(
      requestIds,
    );
    final toDeleteIds = existingRequests
        .whereType<LocalFriendRequest>()
        .map((request) => request.id)
        .toList(growable: false);
    if (toDeleteIds.isEmpty) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.localFriendRequests.deleteAll(toDeleteIds);
    });
  }

  String _buildFriendRequestId(String firstUid, String secondUid) {
    final ordered = <String>[firstUid, secondUid]..sort();
    return ordered.join('_');
  }

  Future<void> _cacheProfileSnapshots(
    List<Map<String, dynamic>> users, {
    required String source,
    bool forceFriend = false,
    bool forceNonFriend = false,
  }) async {
    if (users.isEmpty) {
      return;
    }

    final isar = await _localDatabaseService.database;
    final uids = users
        .map((user) => user['uid']?.toString())
        .whereType<String>()
        .where((uid) => uid.isNotEmpty && uid != _currentUid)
        .toList(growable: false);

    if (uids.isEmpty) {
      return;
    }

    final existingUserModels = await isar.userModels.getAllByUid(uids);
    final existingFriendProfiles = await isar.localFriendProfiles.getAllByUid(
      uids,
    );
    final existingNonFriendProfiles = await isar.localNonFriendProfiles
        .getAllByUid(uids);

    final userModelMap = <String, UserModel?>{
      for (var i = 0; i < uids.length; i++) uids[i]: existingUserModels[i],
    };
    final friendMap = <String, LocalFriendProfile?>{
      for (var i = 0; i < uids.length; i++) uids[i]: existingFriendProfiles[i],
    };
    final nonFriendMap = <String, LocalNonFriendProfile?>{
      for (var i = 0; i < uids.length; i++)
        uids[i]: existingNonFriendProfiles[i],
    };
    final seenUids = <String>{};

    await isar.writeTxn(() async {
      for (final userData in users) {
        final uid = userData['uid']?.toString();
        if (uid == null || uid.isEmpty) continue;
        if (uid == _currentUid) continue;

        seenUids.add(uid);

        await _upsertUserModelSync(isar, uid, userData, userModelMap[uid]);

        final shouldUseFriendBucket = forceFriend
            ? true
            : forceNonFriend
            ? false
            : friendMap[uid] != null;

        if (shouldUseFriendBucket) {
          final model =
              friendMap[uid] ??
              LocalFriendProfile(uid: uid, displayName: 'User');

          _populateFriendProfile(model, uid, userData, source: source);
          await isar.localFriendProfiles.putByUid(model);
          await isar.localNonFriendProfiles.deleteByUid(uid);
        } else {
          final model =
              nonFriendMap[uid] ??
              LocalNonFriendProfile(uid: uid, displayName: 'User');

          _populateNonFriendProfile(model, uid, userData, source);
          await isar.localNonFriendProfiles.putByUid(model);
          await isar.localFriendProfiles.deleteByUid(uid);
        }
      }

      if (forceFriend) {
        for (final profile
            in existingFriendProfiles.whereType<LocalFriendProfile>()) {
          if (!seenUids.contains(profile.uid) && profile.uid != _currentUid) {
            await isar.localFriendProfiles.deleteByUid(profile.uid);
          }
        }
      }
    });
  }

  Future<void> _upsertUserModelSync(
    Isar isar,
    String uid,
    Map<String, dynamic> userData,
    UserModel? existing,
  ) async {
    final model =
        existing ??
        UserModel(
          uid: uid,
          displayName: userData['displayName']?.toString() ?? 'User',
          email: userData['email']?.toString() ?? '',
          createdAt: DateTime.now(),
        );

    final displayName = userData['displayName']?.toString();
    if (displayName != null && displayName.isNotEmpty) {
      model.displayName = displayName;
    }

    final email = userData['email']?.toString();
    if (email != null && email.isNotEmpty) {
      model.email = email;
    }

    final bio = userData['bio']?.toString();
    if (bio != null) {
      model.bio = bio.isEmpty ? null : bio;
    }

    final photoUrl = userData['photoURL']?.toString();
    if (photoUrl != null) {
      model.photoURL = photoUrl.isEmpty ? null : photoUrl;
    }

    model.friendCount = _toInt(userData['friendCount']);
    model.boardCount = _toInt(userData['boardCount']);

    final createdAt = _toDateTime(userData['createdAt']);
    if (createdAt != null) {
      model.createdAt = createdAt;
    }

    final updatedAt = _toDateTime(userData['updatedAt']);
    if (updatedAt != null) {
      model.updatedAt = updatedAt;
    }

    await isar.userModels.putByUid(model);
  }

  void _populateFriendProfile(
    LocalFriendProfile model,
    String uid,
    Map<String, dynamic> userData, {
    required String source,
  }) {
    _populateProfileModel(model, uid, userData, source: source);
  }

  void _populateNonFriendProfile(
    LocalNonFriendProfile model,
    String uid,
    Map<String, dynamic> userData,
    String source,
  ) {
    _populateProfileModel(model, uid, userData, source: source);
  }

  Map<String, dynamic> _toRequestMap(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'requestId': id,
      ...data,
      'timestamp': _toDateTime(data['timestamp']) ?? DateTime.now(),
    };
  }

  void _populateProfileModel(
    dynamic model,
    String uid,
    Map<String, dynamic> userData, {
    required String source,
  }) {
    model.uid = uid;

    final displayName = userData['displayName']?.toString();
    if (displayName != null && displayName.isNotEmpty) {
      model.displayName = displayName;
    }

    final email = userData['email']?.toString();
    if (email != null && email.isNotEmpty) {
      model.email = email;
    }

    final bio = userData['bio']?.toString();
    if (bio != null) {
      model.bio = bio.isEmpty ? null : bio;
    }

    final photoUrl = userData['photoURL']?.toString();
    if (photoUrl != null) {
      model.photoURL = photoUrl.isEmpty ? null : photoUrl;
    }

    model.friendCount = _toInt(userData['friendCount']);
    model.boardCount = _toInt(userData['boardCount']);

    model.lastSource = source;
    model.lastSeenAt = DateTime.now();
    model.cachedAt = DateTime.now();
  }

  Map<String, dynamic> _friendProfileToMap(LocalFriendProfile profile) {
    return {
      'uid': profile.uid,
      'displayName': profile.displayName,
      'email': profile.email,
      'bio': profile.bio,
      'photoURL': profile.photoURL,
      'friendCount': profile.friendCount,
      'boardCount': profile.boardCount,
      'cachedAt': profile.cachedAt,
      'lastSeenAt': profile.lastSeenAt,
      'lastSource': profile.lastSource,
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<Map<String, String>> _resolveDisplayNamesBulk(
    Isar isar,
    List<String> uids,
  ) async {
    if (uids.isEmpty) return <String, String>{};

    final friends = await isar.localFriendProfiles.getAllByUid(uids);
    final nonFriends = await isar.localNonFriendProfiles.getAllByUid(uids);
    final models = await isar.userModels.getAllByUid(uids);

    final result = <String, String>{};
    for (var index = 0; index < uids.length; index++) {
      final uid = uids[index];
      final friend = friends[index];
      final nonFriend = nonFriends[index];
      final model = models[index];

      result[uid] = friend?.displayName.isNotEmpty == true
          ? friend!.displayName
          : nonFriend?.displayName.isNotEmpty == true
          ? nonFriend!.displayName
          : model?.displayName.isNotEmpty == true
          ? model!.displayName
          : 'User';
    }

    return result;
  }

  Future<Map<String, String?>> _resolvePhotoUrlsBulk(
    Isar isar,
    List<String> uids,
  ) async {
    if (uids.isEmpty) return <String, String?>{};

    final friends = await isar.localFriendProfiles.getAllByUid(uids);
    final nonFriends = await isar.localNonFriendProfiles.getAllByUid(uids);
    final models = await isar.userModels.getAllByUid(uids);

    final result = <String, String?>{};
    for (var index = 0; index < uids.length; index++) {
      final uid = uids[index];
      final friend = friends[index];
      final nonFriend = nonFriends[index];
      final model = models[index];

      result[uid] = friend?.photoURL?.isNotEmpty == true
          ? friend!.photoURL
          : nonFriend?.photoURL?.isNotEmpty == true
          ? nonFriend!.photoURL
          : model?.photoURL?.isNotEmpty == true
          ? model!.photoURL
          : null;
    }

    return result;
  }

  Future<(String, String?)> _resolveProfileInfo(Isar isar, String uid) async {
    final results = await Future.wait([
      isar.localFriendProfiles.getByUid(uid),
      isar.localNonFriendProfiles.getByUid(uid),
      isar.userModels.getByUid(uid),
    ]);

    final friend = results[0] as LocalFriendProfile?;
    final nonFriend = results[1] as LocalNonFriendProfile?;
    final model = results[2] as UserModel?;

    final name = friend?.displayName.isNotEmpty == true
        ? friend!.displayName
        : nonFriend?.displayName.isNotEmpty == true
        ? nonFriend!.displayName
        : model?.displayName.isNotEmpty == true
        ? model!.displayName
        : 'User';

    final photo = friend?.photoURL?.isNotEmpty == true
        ? friend!.photoURL
        : nonFriend?.photoURL?.isNotEmpty == true
        ? nonFriend!.photoURL
        : model?.photoURL?.isNotEmpty == true
        ? model!.photoURL
        : null;

    return (name, photo);
  }

  Map<String, dynamic> _blockedUserToMap(LocalBlockedUser item) {
    return {
      'blockedUid': item.blockedUid,
      'blockerUid': item.blockerUid,
      'displayName': item.displayName,
      'photoURL': item.photoURL,
      'cachedAt': item.cachedAt,
      'lastSource': item.lastSource,
    };
  }
}
