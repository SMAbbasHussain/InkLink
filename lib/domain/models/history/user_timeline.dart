import 'dart:convert';
import 'dart:typed_data';

import 'board_operation.dart';

/// One board-state delta captured at a scrub stop by the server
/// (`history_preview_user_timeline`). Applying [deltaBytes] to the state at
/// the previous stop yields the board exactly as it was at [version].
class TimelineStep {
  final int version;
  final Uint8List deltaBytes;

  const TimelineStep({required this.version, required this.deltaBytes});

  factory TimelineStep.fromMap(Map<String, dynamic> map) {
    return TimelineStep(
      version: (map['version'] as num?)?.toInt() ?? 0,
      deltaBytes: decodeState(map['stateUpdate']),
    );
  }
}

/// Result of `history_preview_user_timeline`: one user's ops (ascending), the
/// board state just before the page's first op, and a delta per op so the
/// owner can replay that user's work on the canvas without more requests.
class UserTimeline {
  /// The page's ops, ascending by version, with plain-English labels filled
  /// in server-side even for un-archived (stream tail) ops.
  final List<BoardOperation> ops;

  /// Whether older pages exist (fetch with [nextBeforeVersion]).
  final bool hasMore;
  final int? nextBeforeVersion;

  /// Board state at (first op version − 1) — the scrub's starting point.
  final int baseVersion;
  final Uint8List baseStateBytes;

  /// Board-state deltas, aligned by index with [ops].
  final List<TimelineStep> steps;

  const UserTimeline({
    this.ops = const [],
    this.hasMore = false,
    this.nextBeforeVersion,
    this.baseVersion = 0,
    required this.baseStateBytes,
    this.steps = const [],
  });

  factory UserTimeline.fromMap(Map<String, dynamic> map) {
    final rawOps = map['ops'];
    final ops = <BoardOperation>[];
    if (rawOps is List) {
      for (final entry in rawOps) {
        if (entry is Map) {
          ops.add(BoardOperation.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    final rawSteps = map['steps'];
    final steps = <TimelineStep>[];
    if (rawSteps is List) {
      for (final entry in rawSteps) {
        if (entry is Map) {
          steps.add(TimelineStep.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    final base = map['base'];
    final baseVersion = base is Map
        ? (base['version'] as num?)?.toInt() ?? 0
        : 0;
    final baseState = base is Map
        ? decodeState(base['stateUpdate'])
        : Uint8List(0);
    return UserTimeline(
      ops: ops,
      hasMore: map['hasMore'] == true,
      nextBeforeVersion: (map['nextBeforeVersion'] as num?)?.toInt(),
      baseVersion: baseVersion,
      baseStateBytes: baseState,
      steps: steps,
    );
  }
}

/// Decode a base64 CRDT update; empty/invalid input becomes an empty list so
/// callers can branch on `isNotEmpty` instead of throwing.
Uint8List decodeState(dynamic value) {
  final encoded = (value as String?) ?? '';
  if (encoded.isEmpty) return Uint8List(0);
  try {
    return base64Decode(encoded);
  } on FormatException {
    return Uint8List(0);
  }
}
