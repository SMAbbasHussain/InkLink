import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/profile/profile_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileViewData {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;

  const ProfileViewData({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
  });
}

abstract class ProfileService {
  Future<ProfileViewData> loadProfile(String userId);
  Stream<Map<String, dynamic>?> watchUserById(String userId);
  Future<void> updateProfile({required String name, required String bio});
  Future<String> uploadProfilePhoto({
    required String imageData,
    required String filename,
  });
  Future<String?> saveProfileChanges({
    required String name,
    required String bio,
    String? imageData,
    String? filename,
  });
}

class ProfileServiceImpl implements ProfileService {
  final ProfileRepository _profileRepository;
  final AuthService _authService;
  final CloudFunctionsService _cloudFunctionsService;

  ProfileServiceImpl({
    required ProfileRepository profileRepository,
    required AuthService authService,
    required CloudFunctionsService cloudFunctionsService,
  }) : _profileRepository = profileRepository,
       _authService = authService,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Future<ProfileViewData> loadProfile(String userId) async {
    final currentUid = _profileRepository.getCurrentUserId();
    if (currentUid == null) {
      throw Exception('User not authenticated');
    }

    final userData = await _profileRepository.getUserById(userId);
    if (userData == null) {
      throw Exception('User not found');
    }

    final isSelf = currentUid == userId;
    var isFriend = false;
    if (!isSelf) {
      isFriend = await _profileRepository.checkFriendshipStatus(userId);
    }

    return ProfileViewData(
      userData: userData,
      isSelf: isSelf,
      isFriend: isFriend,
    );
  }

  @override
  Stream<Map<String, dynamic>?> watchUserById(String userId) {
    return _profileRepository.getUserByIdStream(userId);
  }

  @override
  Future<void> updateProfile({required String name, required String bio}) {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return _profileRepository.updateUserFields(user.uid, {
      'displayName': name,
      'bio': bio,
      'searchKeywords': generateSearchKeywords(name),
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
      final result = await _cloudFunctionsService
          .httpsCallable('uploadProfilePhoto')
          .call({'imageData': imageData, 'filename': filename});

      final photoUrl = result.data['photoUrl'];
      if (photoUrl == null || photoUrl.toString().isEmpty) {
        throw Exception('Failed to get photo URL from server');
      }

      await _profileRepository.updateUserFields(user.uid, {
        'photoURL': photoUrl,
      });

      return photoUrl.toString();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  @override
  Future<String?> saveProfileChanges({
    required String name,
    required String bio,
    String? imageData,
    String? filename,
  }) async {
    await updateProfile(name: name, bio: bio);

    final shouldUploadPhoto =
        imageData != null &&
        imageData.isNotEmpty &&
        filename != null &&
        filename.isNotEmpty;

    if (!shouldUploadPhoto) {
      return null;
    }

    final photoUrl = await uploadProfilePhoto(
      imageData: imageData,
      filename: filename,
    );

    return photoUrl;
  }
}
