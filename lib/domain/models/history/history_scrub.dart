import 'dart:typed_data';

import 'board_operation.dart';

/// An active scrub session on the canvas preview: a list of stops (ops in
/// version order), the board state before the first stop, and the board-state
/// delta at every stop.
///
/// Two flavours share this shape:
/// - Version scrub ([targetUid] == null): the stops are one archived block's
///   ops and the deltas are those ops' own CRDT payloads (they replay the
///   block's consecutive versions).
/// - User scrub: the stops are one user's logged ops and the deltas are
///   server-captured board states at each of them, so the replay shows the
///   true historical board including other people's concurrent edits.
class HistoryScrub {
  /// Stops in ascending version order. The slider starts at the last stop
  /// (the newest state in range) and moves back.
  final List<BoardOperation> stops;

  /// Board state just before [stops.first].
  final Uint8List baseStateBytes;

  /// Deltas parallel to [stops]: applying base + deltas[0..i] reproduces the
  /// board at stops[i].
  final List<Uint8List> stepDeltas;

  /// The replayed user, or null for a version scrub.
  final String? targetUid;

  /// Undo-request scope (D5): the element ids the member picked (an area
  /// resolved client-side and/or double-tapped elements). Only their ops that
  /// touched these elements are stops, and scoped load-older requests pass
  /// the same ids back to the server. Empty for owner replays.
  final List<String> elementIds;

  /// User scrub only: older pages can still be prepended.
  final bool hasMore;
  final int? nextBeforeVersion;

  const HistoryScrub({
    required this.stops,
    required this.baseStateBytes,
    required this.stepDeltas,
    this.targetUid,
    this.elementIds = const [],
    this.hasMore = false,
    this.nextBeforeVersion,
  });

  BoardOperation stopAt(int index) =>
      stops[index.clamp(0, stops.length - 1)];

  int get lastIndex => stops.length - 1;
}
