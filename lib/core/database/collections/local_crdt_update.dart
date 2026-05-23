import 'package:isar_community/isar.dart';

part 'local_crdt_update.g.dart';

@collection
class LocalCrdtUpdate {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String updateId;

  @Index()
  late String boardId;

  @Index()
  late String? elementId; // Which element this update represents (for in-place edits)

  // Base64 encoded CRDT update payload bytes.
  late String payloadBase64;
  late String sourceClientId;
  late DateTime appliedAt;
  int version = 0;

  bool isSynced = false;
  bool isDeleted = false; // For undo/redo: hidden but not deleted from history
}
