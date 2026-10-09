import 'dart:async';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/collections/local_profile.dart';
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
      // Return cached data immediately for fast page load.
      // Revalidate in background only if cached value is stale.
      if (cached.bucket != _ProfileBucket.self) {
        final cachedAtRaw = cached.data['cachedAt'];
        if (cachedAtRaw is DateTime) {
          final age = DateTime.now().difference(cachedAtRaw);
          // TTL: 5 minutes
          if (age > const Duration(minutes: 5)) {
            _revalidateUserFromFirestore(uid, cached.bucket);
          }
        } else {
          // If no cachedAt, conservatively revalidate
          _revalidateUserFromFirestore(uid, cached.bucket);
        }
      }

      return cached.data;
    }

    final doc = await _firestoreService.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    final currentUid = _authService.getCurrentUserId();
    final isSelf = currentUid == uid;
    final isFriend = !isSelf && await _isFriendInCachedList(uid);
    await cacheUserProfile(
      uid,
      data,
      isFriend: isFriend,
      isSelf: isSelf,
      source: 'fetch_miss',
    );
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
    final existingProfile = await isar.localProfiles.getByUid(uid);

    await isar.writeTxn(() async {
      final status = isSelf
          ? FriendshipStatus.self
          : isFriend
              ? FriendshipStatus.friend
              : FriendshipStatus.nonFriend;
      final model =
          existingProfile ??
          LocalProfile(uid: uid, displayName: 'User', friendshipStatus: status);
      _applyProfileFields(model, uid, data, source, timestamp);
      model.friendshipStatus = status;
      await isar.localProfiles.putByUid(model);
    });
  }

  @override
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    await _firestoreService.collection('users').doc(uid).update(data);

    await cacheUserProfile(
      uid,
      data,
      isFriend: false,
      isSelf: true,
      source: 'update',
    );
  }

  Future<_CachedProfileHit?> _getCachedUserMap(String uid) async {
    final isar = await _localDatabaseService.database;

    final profile = await isar.localProfiles.getByUid(uid);
    if (profile != null) {
      return _CachedProfileHit(
        _profileToMap(profile),
        profile.friendshipStatus == FriendshipStatus.self
            ? _ProfileBucket.self
            : profile.friendshipStatus == FriendshipStatus.friend
                ? _ProfileBucket.friend
                : _ProfileBucket.nonFriend,
      );
    }

    return null;
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

  Map<String, dynamic> _profileToMap(LocalProfile profile) {
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

  Future<bool> _isFriendInCachedList(String targetUid) async {
    final isar = await _localDatabaseService.database;
    final profile = await isar.localProfiles.getByUid(targetUid);
    return profile?.friendshipStatus == FriendshipStatus.friend;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
