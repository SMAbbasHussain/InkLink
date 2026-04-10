import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/database/local_database_service.dart';
import '../../models/user_model.dart';
import 'profile_repository.dart';

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
      _revalidateUserFromFirestore(uid);
      return cached;
    }

    final doc = await _firestoreService.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    await _upsertCachedUser(uid, data);
    return data;
  }

  /// Fetches fresh user data from Firestore and updates cache silently.
  /// Does not block—intended for background revalidation after cache hit.
  void _revalidateUserFromFirestore(String uid) {
    _firestoreService
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          final data = doc.data();
          if (data != null) {
            _upsertCachedUser(uid, data);
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
        await _upsertCachedUser(uid, data);
      }
      return data;
    });
  }

  @override
  Future<bool> checkFriendshipStatus(String targetUid) async {
    final currentUid = _authService.getCurrentUserId();
    if (currentUid == null) return false;

    final doc = await _firestoreService
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  @override
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    await _firestoreService.collection('users').doc(uid).update(data);

    await _upsertCachedUser(uid, data);
  }

  Future<Map<String, dynamic>?> _getCachedUserMap(String uid) async {
    final isar = await _localDatabaseService.database;
    final user = await isar.userModels.getByUid(uid);
    if (user == null) return null;

    return {
      'displayName': user.displayName,
      'bio': user.bio,
      'email': user.email,
      'photoURL': user.photoURL,
      'createdAt': user.createdAt,
      'updatedAt': user.updatedAt,
    };
  }

  Future<void> _upsertCachedUser(String uid, Map<String, dynamic> data) async {
    final isar = await _localDatabaseService.database;
    final existingModel = await isar.userModels.getByUid(uid);

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

    final createdAtRaw = data['createdAt'];
    if (createdAtRaw != null) {
      model.createdAt = _toDateTime(createdAtRaw) ?? model.createdAt;
    }

    final updatedAtRaw = data['updatedAt'];
    if (updatedAtRaw != null) {
      model.updatedAt = _toDateTime(updatedAtRaw);
    }

    await isar.writeTxn(() async {
      await isar.userModels.putByUid(model);
    });
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
}
