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

  /// D13 action hint sent to the server ('upsert' | 'delete' | 'clear') and
  /// the authoritative action carried on inbound updates.
  String? action;

  /// Inbound-only: the element ids an owner revert touched (D14 pruning).
  List<String>? affectedElementIds;

  // Base64 encoded CRDT update payload bytes.
  late String payloadBase64;
  late String sourceClientId;
  late DateTime appliedAt;
  int version = 0;

  bool isSynced = false;
  bool isDeleted = false; // For undo/redo: hidden but not deleted from history
}
