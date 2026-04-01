import 'package:isar/isar.dart';

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

  /// Timestamp when the user was created
  late DateTime createdAt;

  /// Timestamp when the user profile was last updated
  DateTime? updatedAt;

  UserModel({
    this.id,
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio,
    this.photoURL,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert from Firestore user data (Map) to UserModel
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      bio: data['bio'],
      photoURL: data['photoURL'],
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
    );
  }

  /// Convert UserModel to Map for Firestore updates
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'photoURL': photoURL,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }
}
