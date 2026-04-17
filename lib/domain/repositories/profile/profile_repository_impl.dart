import 'dart:async';

import 'package:isar_community/isar.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/collections/local_friend_profile.dart';
import '../../../core/database/collections/local_non_friend_profile.dart';
import '../../models/user_model.dart';
import 'profile_repository.dart';

enum _ProfileBucket { self, friend, nonFriend }

class _CachedProfileHit {
  final Map<String, dynamic> data;
  final _ProfileBucket bucket;

  const _CachedProfileHit(this.data, this.bucket);
}

class ProfileRepositoryImpl implements ProfileRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  ProfileRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  String? getCurrentUserId() {
    return _authService.getCurrentUserId();
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final cached = await _getCachedUserMap(uid);
    if (cached != null) {
      // Return cached data immediately for fast page load, but revalidate
      // in background to catch profile edits made on other devices
      _revalidateUserFromFirestore(uid, cached.bucket);
      return cached.data;
    }

    final doc = await _firestoreService.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    await _upsertCachedUser(uid, data);
    return data;
  }

  /// Fetches fresh user data from Firestore and updates cache silently.
  /// Does not block—intended for background revalidation after cache hit.
  void _revalidateUserFromFirestore(String uid, _ProfileBucket bucket) {
    _firestoreService
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          final data = doc.data();
          if (data != null) {
            unawaited(
              cacheUserProfile(
                uid,
                data,
                isFriend: bucket == _ProfileBucket.friend,
                isSelf: bucket == _ProfileBucket.self,
                source: 'firestore_revalidation',
              ),
            );
          }
        })
        .catchError((_) {
          // Silently ignore revalidation errors; cache remains valid
        });
  }

  @override
  Stream<Map<String, dynamic>?> getUserByIdStream(String uid) {
    return _firestoreService.collection('users').doc(uid).snapshots().asyncMap((
      snapshot,
    ) async {
      final data = snapshot.data();
      if (data != null) {
        await _cacheLiveProfileSnapshot(uid, data);
      }
      return data;
    });
  }

  @override
  Future<bool> checkFriendshipStatus(String targetUid) async {
    final currentUid = _authService.getCurrentUserId();
    if (currentUid == null) return false;

    try {
      final doc = await _firestoreService
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (_) {
      return await _isFriendInCachedList(targetUid);
    }
  }

  @override
  Future<void> cacheUserProfile(
    String uid,
    Map<String, dynamic> data, {
    required bool isFriend,
    required bool isSelf,
    String source = 'profile_open',
  }) async {
    final isar = await _localDatabaseService.database;
    final timestamp = DateTime.now();
    final existingUserModel = await isar.userModels.getByUid(uid);
    final existingFriendProfile = await isar.localFriendProfiles.getByUid(uid);
    final existingNonFriendProfile = await isar.localNonFriendProfiles.getByUid(
      uid,
    );

    await isar.writeTxn(() async {
      await _upsertUserModel(isar, uid, data, existingModel: existingUserModel);

      if (isSelf) {
        await isar.localFriendProfiles.deleteByUid(uid);
        await isar.localNonFriendProfiles.deleteByUid(uid);
        return;
      }

      if (isFriend) {
        final model =
            existingFriendProfile ??
            LocalFriendProfile(uid: uid, displayName: 'User');
        _applyProfileFields(model, uid, data, source, timestamp);
        await isar.localFriendProfiles.putByUid(model);
        await isar.localNonFriendProfiles.deleteByUid(uid);
      } else {
        final model =
            existingNonFriendProfile ??
            LocalNonFriendProfile(uid: uid, displayName: 'User');
        _applyProfileFields(model, uid, data, source, timestamp);
        await isar.localNonFriendProfiles.putByUid(model);
        await isar.localFriendProfiles.deleteByUid(uid);
      }
    });
  }

  @override
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    await _firestoreService.collection('users').doc(uid).update(data);

    await _upsertCachedUser(uid, data);
  }

  Future<_CachedProfileHit?> _getCachedUserMap(String uid) async {
    final isar = await _localDatabaseService.database;

    final results = await Future.wait([
      isar.localFriendProfiles.getByUid(uid),
      isar.localNonFriendProfiles.getByUid(uid),
      isar.userModels.getByUid(uid),
    ]);

    final friendProfile = results[0] as LocalFriendProfile?;
    if (friendProfile != null) {
      return _CachedProfileHit(
        _friendProfileToMap(friendProfile),
        _ProfileBucket.friend,
      );
    }

    final nonFriendProfile = results[1] as LocalNonFriendProfile?;
    if (nonFriendProfile != null) {
      return _CachedProfileHit(
        _nonFriendProfileToMap(nonFriendProfile),
        _ProfileBucket.nonFriend,
      );
    }

    final user = results[2] as UserModel?;
    if (user == null) return null;

    return _CachedProfileHit(_userModelToMap(user), _ProfileBucket.self);
  }

  Future<void> _upsertCachedUser(String uid, Map<String, dynamic> data) async {
    final isar = await _localDatabaseService.database;
    final existingUserModel = await isar.userModels.getByUid(uid);
    await isar.writeTxn(() async {
      await _upsertUserModel(isar, uid, data, existingModel: existingUserModel);
    });
  }

  Future<void> _cacheLiveProfileSnapshot(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final currentUid = _authService.getCurrentUserId();
    final isSelf = currentUid == uid;
    final isFriend = !isSelf && await _isFriendInCachedList(uid);

    await cacheUserProfile(
      uid,
      data,
      isFriend: isFriend,
      isSelf: isSelf,
      source: 'profile_live',
    );
  }

  Future<void> _upsertUserModel(
    Isar isar,
    String uid,
    Map<String, dynamic> data, {
    UserModel? existingModel,
  }) async {
    final model =
        existingModel ??
        UserModel(
          uid: uid,
          displayName: (data['displayName'] as String?) ?? 'User',
          email: (data['email'] as String?) ?? '',
          createdAt: DateTime.now(),
        );

    model.uid = uid;
    model.displayName = (data['displayName'] as String?) ?? model.displayName;
    model.email = (data['email'] as String?) ?? model.email;
    model.bio = (data['bio'] as String?) ?? model.bio;
    model.photoURL = (data['photoURL'] as String?) ?? model.photoURL;
    model.friendCount = _toInt(data['friendCount']);
    model.boardCount = _toInt(data['boardCount']);
    model.isOnline = data['isOnline'] as bool? ?? model.isOnline;
    model.lastActive = _toDateTime(data['lastActive']) ?? model.lastActive;

    final createdAtRaw = data['createdAt'];
    if (createdAtRaw != null) {
      model.createdAt = _toDateTime(createdAtRaw) ?? model.createdAt;
    }

    final updatedAtRaw = data['updatedAt'];
    if (updatedAtRaw != null) {
      model.updatedAt = _toDateTime(updatedAtRaw);
    }

    await isar.userModels.putByUid(model);
  }

  Map<String, dynamic> _userModelToMap(UserModel user) {
    return {
      'displayName': user.displayName,
      'bio': user.bio,
      'email': user.email,
      'photoURL': user.photoURL,
      'friendCount': user.friendCount,
      'boardCount': user.boardCount,
      'createdAt': user.createdAt,
      'updatedAt': user.updatedAt,
      'isOnline': user.isOnline,
      'lastActive': user.lastActive,
    };
  }

  Map<String, dynamic> _friendProfileToMap(LocalFriendProfile profile) {
    return {
      'displayName': profile.displayName,
      'bio': profile.bio,
      'email': profile.email,
      'photoURL': profile.photoURL,
      'friendCount': profile.friendCount,
      'boardCount': profile.boardCount,
      'cachedAt': profile.cachedAt,
      'lastSeenAt': profile.lastSeenAt,
      'lastSource': profile.lastSource,
    };
  }

  Map<String, dynamic> _nonFriendProfileToMap(LocalNonFriendProfile profile) {
    return {
      'displayName': profile.displayName,
      'bio': profile.bio,
      'email': profile.email,
      'photoURL': profile.photoURL,
      'friendCount': profile.friendCount,
      'boardCount': profile.boardCount,
      'cachedAt': profile.cachedAt,
      'lastSeenAt': profile.lastSeenAt,
      'lastSource': profile.lastSource,
    };
  }

  void _applyProfileFields(
    dynamic model,
    String uid,
    Map<String, dynamic> data,
    String source,
    DateTime timestamp,
  ) {
    model.uid = uid;

    final displayName = data['displayName']?.toString();
    if (displayName != null && displayName.isNotEmpty) {
      model.displayName = displayName;
    }

    final email = data['email']?.toString();
    if (email != null && email.isNotEmpty) {
      model.email = email;
    }

    final bio = data['bio']?.toString();
    if (bio != null) {
      model.bio = bio.isEmpty ? null : bio;
    }

    final photoUrl = data['photoURL']?.toString();
    if (photoUrl != null) {
      model.photoURL = photoUrl.isEmpty ? null : photoUrl;
    }

    model.friendCount = _toInt(data['friendCount']);
    model.boardCount = _toInt(data['boardCount']);

    model.lastSource = source;
    model.lastSeenAt = timestamp;
    model.cachedAt = timestamp;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value != null) {
      try {
        return value.toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<bool> _isFriendInCachedList(String targetUid) async {
    final isar = await _localDatabaseService.database;
    final profile = await isar.localFriendProfiles.getByUid(targetUid);
    return profile != null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
