import 'dart:typed_data';

import 'board_operation.dart';
import 'undo_request.dart';

/// Summary of differences between a scrub stop and the current live board
/// within the selected scope.
class HistoryScrubDiff {
  final int addedCount;
  final int updatedCount;
  final int deletedCount;
  final List<String> changedElementIds;

  const HistoryScrubDiff({
    this.addedCount = 0,
    this.updatedCount = 0,
    this.deletedCount = 0,
    this.changedElementIds = const [],
  });

  int get totalChanges => addedCount + updatedCount + deletedCount;

  String get summaryLabel {
    if (totalChanges == 0) return 'Matches current state';
    final parts = <String>[];
    if (addedCount > 0) parts.add('+$addedCount added');
    if (updatedCount > 0) parts.add('~$updatedCount edited');
    if (deletedCount > 0) parts.add('-$deletedCount removed');
    return '${parts.join(' · ')} vs current';
  }
}

/// An active scrub session on the canvas preview: a list of stops (ops in
/// version order), the board state before the first stop, and the board-state
/// delta at every stop.
///
/// Flavours sharing this shape:
/// - Version scrub ([targetUid] == null && [area] == null): the stops are one
///   archived block's ops and the deltas are those ops' own CRDT payloads.
/// - Area scrub ([area] != null, [targetUid] == null): the stops are all ops
///   that touched the selected part of the board.
/// - User / Undo Request scrub: the stops are one user's logged ops (or area
///   ops when [scopeMode] is [UndoRequestScopeMode.areaState]).
class HistoryScrub {
  /// Stops in ascending version order. The slider starts at the last stop
  /// (the newest state in range) and moves back.
  final List<BoardOperation> stops;

  /// Board state just before [stops.first].
  final Uint8List baseStateBytes;

  /// Deltas parallel to [stops]: applying base + deltas[0..i] reproduces the
  /// board at stops[i].
  final List<Uint8List> stepDeltas;

  /// The replayed user, or null for a version / area scrub.
  final String? targetUid;

  /// Undo-request or area-history scope (D5): the element ids picked.
  final List<String> elementIds;

  /// Optional world-space rectangle when scrubbing a selected part of the board.
  final UndoRequestArea? area;

  /// Whether this scrub rewinds only one user's changes or the whole area state.
  final UndoRequestScopeMode scopeMode;

  /// Per-stop diff summary against the live board state.
  final List<HistoryScrubDiff> stepDiffs;

  /// User/area scrub pagination: older pages can still be prepended.
  final bool hasMore;
  final int? nextBeforeVersion;

  const HistoryScrub({
    required this.stops,
    required this.baseStateBytes,
    required this.stepDeltas,
    this.targetUid,
    this.elementIds = const [],
    this.area,
    this.scopeMode = UndoRequestScopeMode.myChanges,
    this.stepDiffs = const [],
    this.hasMore = false,
    this.nextBeforeVersion,
  });

  BoardOperation stopAt(int index) =>
      stops[index.clamp(0, stops.length - 1)];

  HistoryScrubDiff? diffAt(int index) {
    if (stepDiffs.isEmpty) return null;
    return stepDiffs[index.clamp(0, stepDiffs.length - 1)];
  }

  int get lastIndex => stops.length - 1;
}
