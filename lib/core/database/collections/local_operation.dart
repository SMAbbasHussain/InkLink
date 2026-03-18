import 'package:isar/isar.dart';

part 'local_operation.g.dart';

@collection
class LocalOperation {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String opId;

  @Index()
  late String boardId;

  late String objectId;
  late String type;
  late String action;
  late String data;
  late String timestamp;
  late String clientId;

  bool isSynced = false;
}
