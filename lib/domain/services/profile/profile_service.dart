import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/profile/profile_repository.dart';
import '../../repositories/friends/friends_repository.dart';
import '../../repositories/board/board_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileViewData {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;
  final bool isBlocked;
  final int friendCount;
  final int boardCount;
  final bool isOnline;
  final DateTime? lastActive;

  const ProfileViewData({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
    required this.isBlocked,
    this.friendCount = 0,
    this.boardCount = 0,
    this.isOnline = false,
    this.lastActive,
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
  final FriendsRepository _friendsRepository;
  final BoardRepository _boardRepository;

  ProfileServiceImpl({
    required ProfileRepository profileRepository,
    required AuthService authService,
    required CloudFunctionsService cloudFunctionsService,
    required FriendsRepository friendsRepository,
    required BoardRepository boardRepository,
  }) : _profileRepository = profileRepository,
       _authService = authService,
       _cloudFunctionsService = cloudFunctionsService,
       _friendsRepository = friendsRepository,
       _boardRepository = boardRepository;

  @override
  Future<ProfileViewData> loadProfile(String userId) async {
    final currentUid = _profileRepository.getCurrentUserId();
    if (currentUid == null) {
      throw Exception('User not authenticated');
    }

    final isSelf = currentUid == userId;
    var isFriend = false;
    var isBlocked = false;
    if (!isSelf) {
      try {
        isFriend = await _profileRepository.checkFriendshipStatus(userId);
      } catch (_) {
        isFriend = false;
      }
      try {
        isBlocked = await _friendsRepository.hasUserBlockedTarget(userId);
      } catch (_) {
        isBlocked = false;
      }
    }

    final userData = await _profileRepository.getUserById(userId);
    if (userData == null) {
      throw Exception('User not found');
    }

    await _profileRepository.cacheUserProfile(
      userId,
      userData,
      isFriend: isFriend,
      isSelf: isSelf,
      source: 'profile_open',
    );

    int friendCount = 0;
    int boardCount = 0;

    if (isSelf) {
      // These repository queries depend on rules that may only allow
      // the authenticated user to read their own friends/boards.
      friendCount = await _friendsRepository.countFriendsForUser(userId);
      boardCount = await _boardRepository.countBoardsForUser(userId);
    } else {
      // For other users, rely on public denormalized fields when available.
      friendCount = _toInt(userData['friendCount']);
      boardCount = _toInt(userData['boardCount']);
    }

    final isOnline = userData['isOnline'] == true;
    final lastActive = _toDateTime(userData['lastActive']);

    return ProfileViewData(
      userData: userData,
      isSelf: isSelf,
      isFriend: isFriend,
      isBlocked: isBlocked,
      friendCount: friendCount,
      boardCount: boardCount,
      isOnline: isOnline,
      lastActive: lastActive,
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

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;

    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
