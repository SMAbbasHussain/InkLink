import '../../../core/utils/helpers.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/database/database_service.dart';
import '../../models/user_model.dart';
import 'profile_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final CloudFunctionsService _functionsService;
  final DatabaseService _dbService;

  ProfileRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required CloudFunctionsService functionsService,
    required DatabaseService dbService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _functionsService = functionsService,
       _dbService = dbService;

  @override
  String? getCurrentUserId() {
    return _authService.getCurrentUserId();
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final cached = await _getCachedUserMap(uid);
    if (cached != null) {
      return cached;
    }

    final doc = await _firestoreService.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    await _upsertCachedUser(uid, data);
    return data;
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
  Future<void> updateUserProfile({
    required String name,
    required String bio,
  }) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    // 1. Update Firebase Auth (for local app instance)
    await user.updateDisplayName(name);

    // 2. Generate new search keywords for the new name
    final keywords = generateSearchKeywords(name);

    // 3. Update Firestore (Source of truth for friends)
    await _firestoreService.collection('users').doc(user.uid).update({
      'displayName': name,
      'bio': bio,
      'searchKeywords': keywords,
    });

    await _upsertCachedUser(user.uid, {
      'displayName': name,
      'bio': bio,
      'email': user.email,
      'photoURL': user.photoURL,
      'updatedAt': DateTime.now(),
    });
  }

  @override
  Future<String> uploadProfilePhoto({
    required String imageData,
    required String filename,
  }) async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Call the Cloud Function to upload to Cloudflare R2
      final result = await _functionsService
          .httpsCallable('uploadProfilePhoto')
          .call({'imageData': imageData, 'filename': filename});

      // Extract the photo URL from the result
      final photoUrl = result.data['photoUrl'];
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Failed to get photo URL from server');
      }

      // Update Firestore with the new photo URL
      await _firestoreService.collection('users').doc(user.uid).update({
        'photoURL': photoUrl,
      });

      await _upsertCachedUser(user.uid, {
        'displayName': user.displayName,
        'bio': null,
        'email': user.email,
        'photoURL': photoUrl,
        'updatedAt': DateTime.now(),
      });

      return photoUrl;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  Future<Map<String, dynamic>?> _getCachedUserMap(String uid) async {
    final isar = await _dbService.database;
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
    final isar = await _dbService.database;
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
