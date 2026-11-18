/// Web stand-in for the Isar collection `LocalCrdtUpdate`
/// (lib/core/database/collections/local_crdt_update.dart).
///
/// Same class name and fields, without Isar annotations, so the shared
/// canvas code compiles for the browser. Keep the fields in step with the
/// Isar class; `test/domain/models/canvas/crdt_update_web_test.dart` checks
/// that they match.
class LocalCrdtUpdate {
  int id = 0;

  late String updateId;

  late String boardId;

  late String? elementId;

  /// Action hint sent to the server ('upsert' | 'delete' | 'clear') and the
  /// authoritative action carried on inbound updates.
  String? action;

  /// Inbound-only: the element ids an owner revert touched.
  List<String>? affectedElementIds;

  /// Base64 encoded CRDT update payload bytes.
  late String payloadBase64;
  late String sourceClientId;
  late DateTime appliedAt;
  int version = 0;

  bool isSynced = false;
  bool isDeleted = false;
}
