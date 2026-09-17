import 'package:isar_community/isar.dart';

part 'user_model.g.dart';

/// Isar model for caching Firebase user data locally
/// This model stores user profile information in the local database
/// to provide offline access and reduce Firestore read costs
@collection
class UserModel {
  Id? id; // Isar internal ID

  /// Firebase UID (unique identifier)
  @Index(unique: true, replace: true)
  late String uid;

  /// User's display name
  late String displayName;

  /// User's email address
  late String email;

  /// User's bio/about section
  String? bio;

  /// URL to user's profile photo stored in Cloudflare R2
  String? photoURL;

  /// Cached count of friends.
  int friendCount = 0;

  /// Cached count of owned boards.
  int boardCount = 0;

  /// Timestamp when the user was created
  late DateTime createdAt;

  /// Timestamp when the user profile was last updated
  DateTime? updatedAt;

  /// Whether the user is currently online
  bool? isOnline;

  /// Timestamp of user's last activity
  DateTime? lastActive;

  UserModel({
    this.id,
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio,
    this.photoURL,
    this.friendCount = 0,
    this.boardCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isOnline,
    this.lastActive,
  });

  /// Convert from Firestore user data (Map) to UserModel
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      bio: data['bio'],
      photoURL: data['photoURL'],
      friendCount: (data['friendCount'] as num?)?.toInt() ?? 0,
      boardCount: (data['boardCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
      isOnline: data['isOnline'] as bool?,
      lastActive: (data['lastActive'] as dynamic)?.toDate(),
    );
  }

  /// Convert UserModel to Map for Firestore updates
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'photoURL': photoURL,
      'friendCount': friendCount,
      'boardCount': boardCount,
      'updatedAt': updatedAt ?? DateTime.now(),
      'isOnline': isOnline,
      'lastActive': lastActive,
    };
  }
}
