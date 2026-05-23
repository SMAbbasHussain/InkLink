import 'package:isar_community/isar.dart';

part 'local_canvas_sync_state.g.dart';

@collection
class LocalCanvasSyncState {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String boardId;

  int lastAppliedVersion = 0;
  int lastSnapshotVersion = 0;
  DateTime? lastSnapshotAt;
  DateTime? lastSyncedAppliedAt;
}
