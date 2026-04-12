import 'package:isar_community/isar.dart';

part 'local_friend_profile.g.dart';

@collection
class LocalFriendProfile {
  Id? id;

  @Index(unique: true, replace: true)
  late String uid;

  late String displayName;

  String? email;

  String? bio;

  String? photoURL;

  int friendCount = 0;

  int boardCount = 0;

  String? lastSource;

  DateTime? lastSeenAt;

  late DateTime cachedAt;

  LocalFriendProfile({
    this.id,
    required this.uid,
    required this.displayName,
    this.email,
    this.bio,
    this.photoURL,
    this.friendCount = 0,
    this.boardCount = 0,
    this.lastSource,
    this.lastSeenAt,
  });
}
