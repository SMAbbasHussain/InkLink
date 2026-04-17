import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../../core/database/collections/local_friend_profile.dart';
import '../../../core/database/collections/local_invitation.dart';
import '../../../core/database/collections/local_non_friend_profile.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/user_model.dart';
import 'invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  InvitationRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() {
    final uid = _authService.getCurrentUserId();
    if (uid == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<LocalInvitation>>? localSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;

    controller.onListen = () {
      () async {
        final isar = await _localDatabaseService.database;

        localSub = isar.localInvitations
            .filter()
            .toUidEqualTo(uid)
            .statusEqualTo('pending')
            .watch(fireImmediately: true)
            .listen((items) {
              if (controller.isClosed) return;
              controller.add(
                _sortInvitesByTimestampDesc(items.map(_inviteToMap).toList()),
              );
            }, onError: controller.addError);

        remoteSub = _firestoreService
            .collection('board_invites')
            .where('toUid', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen((snapshot) async {
              final invites = _sortInvitesByTimestampDesc(
                snapshot.docs
                    .map((doc) => _toInviteMap(doc.id, doc.data()))
                    .toList(),
              );
              await _upsertInvites(invites, uid: uid);
              await _cacheInviteProfiles(invites);
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
  Future<void> removeHandledInvite(String inviteId) async {
    if (inviteId.trim().isEmpty) return;

    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localInvitations.deleteByInviteId(inviteId);
    });
  }

  @override
  Future<void> probeServerAvailability() {
    return _firestoreService
        .collection('users')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 4));
  }

  Future<void> _upsertInvites(
    List<Map<String, dynamic>> invites, {
    required String uid,
  }) async {
    if (invites.isEmpty) return;

    final isar = await _localDatabaseService.database;
    final inviteIds = invites
        .map((invite) => invite['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final existingInvites = await isar.localInvitations.getAllByInviteId(
      inviteIds,
    );
    final existingInviteMap = <String, LocalInvitation?>{
      for (var i = 0; i < inviteIds.length; i++)
        inviteIds[i]: existingInvites[i],
    };
    final seenInviteIds = <String>{};

    await isar.writeTxn(() async {
      for (final invite in invites) {
        final inviteId = invite['id']?.toString();
        final boardId = invite['boardId']?.toString();
        final boardTitle = invite['boardTitle']?.toString();
        final fromUid = invite['fromUid']?.toString();
        final toUid = invite['toUid']?.toString();
        final senderName = invite['senderName']?.toString();
        final status = invite['status']?.toString() ?? 'pending';
        final timestamp = _toDateTime(invite['timestamp']) ?? DateTime.now();

        if (inviteId == null || inviteId.isEmpty) continue;
        if (boardId == null || boardId.isEmpty) continue;
        if (fromUid == null || fromUid.isEmpty) continue;
        if (toUid == null || toUid.isEmpty) continue;

        seenInviteIds.add(inviteId);

        final model = existingInviteMap[inviteId] ?? LocalInvitation();

        model.inviteId = inviteId;
        model.boardId = boardId;
        model.boardTitle = boardTitle?.isNotEmpty == true
            ? boardTitle!
            : 'Untitled Board';
        model.fromUid = fromUid;
        model.toUid = toUid;
        model.senderName = senderName?.isNotEmpty == true
            ? senderName!
            : 'InkLink User';
        model.senderPic = invite['senderPic']?.toString();
        model.status = status;
        model.targetRole = _normalizeTargetRole(
          invite['targetRole']?.toString(),
        );
        model.inviterRoleSnapshot = invite['inviterRoleSnapshot']?.toString();
        model.timestamp = timestamp;
        model.expiresAt = _toDateTime(invite['expiresAt']);
        model.inviteExpiryHours = _toInt(invite['inviteExpiryHours']);
        model.acceptedAt = _toDateTime(invite['acceptedAt']);
        model.rejectedAt = _toDateTime(invite['rejectedAt']);
        model.resolvedAt = _toDateTime(invite['resolvedAt']);
        model.cachedAt = DateTime.now();

        await isar.localInvitations.putByInviteId(model);
      }

      final stale = await isar.localInvitations
          .filter()
          .toUidEqualTo(uid)
          .statusEqualTo('pending')
          .findAll();

      for (final item in stale) {
        if (!seenInviteIds.contains(item.inviteId)) {
          await isar.localInvitations.delete(item.id);
        }
      }
    });
  }

  Future<void> _cacheInviteProfiles(List<Map<String, dynamic>> invites) async {
    if (invites.isEmpty) return;

    final currentUid = _authService.getCurrentUserId();
    final isar = await _localDatabaseService.database;
    final fromUids = invites
        .map((invite) => invite['fromUid']?.toString())
        .whereType<String>()
        .where((uid) => uid.isNotEmpty && uid != currentUid)
        .toList(growable: false);

    if (fromUids.isEmpty) {
      return;
    }

    final existingUserModels = await isar.userModels.getAllByUid(fromUids);
    final existingFriendProfiles = await isar.localFriendProfiles.getAllByUid(
      fromUids,
    );
    final existingNonFriendProfiles = await isar.localNonFriendProfiles
        .getAllByUid(fromUids);

    final userModelMap = <String, UserModel?>{
      for (var i = 0; i < fromUids.length; i++)
        fromUids[i]: existingUserModels[i],
    };
    final friendMap = <String, LocalFriendProfile?>{
      for (var i = 0; i < fromUids.length; i++)
        fromUids[i]: existingFriendProfiles[i],
    };
    final nonFriendMap = <String, LocalNonFriendProfile?>{
      for (var i = 0; i < fromUids.length; i++)
        fromUids[i]: existingNonFriendProfiles[i],
    };

    await isar.writeTxn(() async {
      for (final invite in invites) {
        final fromUid = invite['fromUid']?.toString();
        if (fromUid == null || fromUid.isEmpty) continue;
        if (fromUid == currentUid) continue;

        final userData = <String, dynamic>{
          'uid': fromUid,
          'displayName': invite['senderName']?.toString() ?? 'InkLink User',
          'photoURL': invite['senderPic']?.toString(),
        };

        _upsertUserModelSync(isar, fromUid, userData, userModelMap[fromUid]);

        final isFriend = friendMap[fromUid] != null;
        if (isFriend) {
          final model =
              friendMap[fromUid] ??
              LocalFriendProfile(uid: fromUid, displayName: 'InkLink User');
          _populateProfileModel(
            model,
            fromUid,
            userData,
            source: 'board_invite',
          );
          await isar.localFriendProfiles.putByUid(model);
          await isar.localNonFriendProfiles.deleteByUid(fromUid);
        } else {
          final model =
              nonFriendMap[fromUid] ??
              LocalNonFriendProfile(uid: fromUid, displayName: 'InkLink User');
          _populateProfileModel(
            model,
            fromUid,
            userData,
            source: 'board_invite',
          );
          await isar.localNonFriendProfiles.putByUid(model);
          await isar.localFriendProfiles.deleteByUid(fromUid);
        }
      }
    });
  }

  Map<String, dynamic> _toInviteMap(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'inviteId': id,
      ...data,
      'timestamp': _toDateTime(data['timestamp']) ?? DateTime.now(),
      'expiresAt': _toDateTime(data['expiresAt']),
    };
  }

  Map<String, dynamic> _inviteToMap(LocalInvitation item) {
    return {
      'id': item.inviteId,
      'inviteId': item.inviteId,
      'boardId': item.boardId,
      'boardTitle': item.boardTitle,
      'fromUid': item.fromUid,
      'toUid': item.toUid,
      'senderName': item.senderName,
      'senderPic': item.senderPic,
      'status': item.status,
      'targetRole': item.targetRole,
      'inviterRoleSnapshot': item.inviterRoleSnapshot,
      'timestamp': item.timestamp,
      'expiresAt': item.expiresAt,
      'inviteExpiryHours': item.inviteExpiryHours,
      'acceptedAt': item.acceptedAt,
      'rejectedAt': item.rejectedAt,
      'resolvedAt': item.resolvedAt,
      'cachedAt': item.cachedAt,
    };
  }

  String _normalizeTargetRole(String? role) {
    if (role == 'editor') return 'editor';
    return 'viewer';
  }

  List<Map<String, dynamic>> _sortInvitesByTimestampDesc(
    List<Map<String, dynamic>> invites,
  ) {
    invites.sort((a, b) {
      final aTs = _timestampToMillis(a['timestamp']);
      final bTs = _timestampToMillis(b['timestamp']);
      return bTs.compareTo(aTs);
    });
    return invites;
  }

  void _upsertUserModelSync(
    Isar isar,
    String uid,
    Map<String, dynamic> userData,
    UserModel? existing,
  ) {
    final model =
        existing ??
        UserModel(
          uid: uid,
          displayName: userData['displayName']?.toString() ?? 'InkLink User',
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

    isar.userModels.putByUidSync(model);
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

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _timestampToMillis(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }
}
