import 'package:isar/isar.dart';

part 'local_crdt_update.g.dart';

@collection
class LocalCrdtUpdate {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String updateId;

  @Index()
  late String boardId;

  // Base64 encoded CRDT update payload bytes.
  late String payloadBase64;
  late String sourceClientId;
  late DateTime appliedAt;

  bool isSynced = false;
}
