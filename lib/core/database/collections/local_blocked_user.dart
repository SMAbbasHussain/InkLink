import 'package:isar_community/isar.dart';

part 'local_blocked_user.g.dart';

@collection
class LocalBlockedUser {
  Id? id;

  @Index(unique: true, replace: true)
  late String blockedUid;

  late String blockerUid;

  late String displayName;

  String? photoURL;

  String? lastSource;

  late DateTime cachedAt;

  LocalBlockedUser({
    this.id,
    required this.blockedUid,
    required this.blockerUid,
    required this.displayName,
    this.photoURL,
    this.lastSource,
  });
}
