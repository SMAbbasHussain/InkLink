import 'package:isar_community/isar.dart';

part 'local_friend_request.g.dart';

@collection
class LocalFriendRequest {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String requestId;

  @Index()
  late String fromUid;

  @Index()
  late String toUid;

  late String senderName;
  String? senderPic;

  @Index()
  late String status;

  @Index()
  late DateTime timestamp;

  late DateTime cachedAt;
}
