import 'dart:typed_data';

import '../../models/history/board_operation.dart';
import '../../models/history/revert_plan.dart';

/// Thrown when a history socket request fails. [code] is the server's error
/// token (e.g. `forbidden`, `plan_expired`, `window_expired`, `nothing_to_undo`).
class HistoryServiceException implements Exception {
  final String code;
  final String message;

  const HistoryServiceException(this.code, [String? message])
    : message = message ?? code;

  @override
  String toString() => 'HistoryServiceException($code): $message';
}

/// Result of `history_preview_version`.
class HistoryPreview {
  final int version;
  final Uint8List stateUpdateBytes;
  final int elementCount;

  const HistoryPreview({
    required this.version,
    required this.stateUpdateBytes,
    required this.elementCount,
  });
}

/// Result of `history_apply_revert` / `history_undo_own`.
class RevertResult {
  final int appliedVersion;
  final List<String> reverted;
  final List<String> skipped;

  const RevertResult({
    this.appliedVersion = 0,
    this.reverted = const [],
    this.skipped = const [],
  });
}

/// One page of a single user's timeline (D15).
class UserOpsPage {
  final List<BoardOperation> ops;
  final bool hasMore;
  final int? nextBeforeVersion;

  const UserOpsPage({
    this.ops = const [],
    this.hasMore = false,
    this.nextBeforeVersion,
  });
}

abstract class BoardHistoryService {
  /// R2 block ops via the socket (bounded client-side LRU cache).
  Future<List<BoardOperation>> getBlock(String boardId, String blockId);

  /// One user's action history, newest first, paginated (D15).
  Future<UserOpsPage> getUserOps(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    int limit = 50,
  });

  /// Read-only reconstruction of a past version.
  Future<HistoryPreview> previewVersion(String boardId, int version);

  Future<RevertPlan> planRevert(
    String boardId, {
    required String mode,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    String? requestId,
  });

  Future<RevertResult> applyRevert(
    String boardId, {
    required String planId,
    required Map<String, String> decisions,
    String? requestId,
  });

  /// Cross-device fallback for a member's own ≤15-minute edits (D2).
  Future<RevertResult> undoOwn(String boardId, {List<String>? updateIds});

  /// Member → owner escalation (D5).
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    DateTime? fromTime,
    DateTime? toTime,
  });

  /// Owner decision on an undo request.
  Future<void> resolveUndoRequest({
    required String boardId,
    required String requestId,
    required String status,
    String? note,
    int? appliedVersion,
  });

  void dispose();
}
