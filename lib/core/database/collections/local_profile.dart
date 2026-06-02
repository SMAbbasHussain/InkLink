import 'package:isar_community/isar.dart';

part 'local_profile.g.dart';

enum FriendshipStatus {
  friend,
  nonFriend,
  self,
  blocked,
}

@collection
class LocalProfile {
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

  @enumerated
  late FriendshipStatus friendshipStatus;

  LocalProfile({
    this.id,
    required this.uid,
    required this.displayName,
    required this.friendshipStatus,
    this.email,
    this.bio,
    this.photoURL,
    this.friendCount = 0,
    this.boardCount = 0,
    this.lastSource,
    this.lastSeenAt,
    DateTime? cachedAtOverride,
  }) : cachedAt = cachedAtOverride ?? DateTime.now();
}
