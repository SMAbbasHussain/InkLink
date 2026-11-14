import 'dart:typed_data';

import '../../models/history/board_operation.dart';
import '../../models/history/revert_plan.dart';
import '../../models/history/undo_request.dart';
import '../../models/history/user_timeline.dart';

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
}/// One element whose latest state was written by someone else than the user
/// asking for the undo. The client turns these into the "your work has been
/// changed — send a request to the owner" flow (§7.2).
class RevertConflict {
  final String elementId;
  final String? lastEditorUid;

  const RevertConflict({required this.elementId, this.lastEditorUid});

  factory RevertConflict.fromMap(Map<String, dynamic> map) {
    return RevertConflict(
      elementId: (map['elementId'] ?? '').toString(),
      lastEditorUid: (map['lastEditorUid'] as String?)?.isEmpty == true
          ? null
          : map['lastEditorUid'] as String?,
    );
  }
}

/// Result of `history_apply_revert` / `history_undo_own`.
class RevertResult {
  final int appliedVersion;
  final List<String> reverted;
  final List<String> skipped;

  /// Elements the server could not revert because another user modified them
  /// afterwards. Empty when the revert succeeded cleanly. Non-empty with an
  /// empty [reverted] means the entire undo was blocked by conflicts.
  final List<RevertConflict> conflicts;

  const RevertResult({
    this.appliedVersion = 0,
    this.reverted = const [],
    this.skipped = const [],
    this.conflicts = const [],
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

  /// One user's replay timeline (D15): the ops plus the board-state delta at
  /// each of them, so the owner can scrub that user's work on the canvas.
  /// Members may request their OWN timeline: [elementIds] scopes the stops to
  /// the undo-request elements they picked and [afterVersion] anchors the
  /// base at a version (the evidence window between a requested state and
  /// the current one).
  Future<UserTimeline> getUserTimeline(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    List<String>? elementIds,
    int? afterVersion,
    int limit = 100,
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

    /// `ops` mode only: versions of the logged ops to undo. When omitted,
    /// `targetUid` + [afterVersion] select that user's in-scope ops instead.
    List<int>? opVersions,

    /// `ops` mode only: undo the target user's ops AFTER this version (the
    /// owner's restore point between a request's state and the current one).
    int? afterVersion,
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

  /// Member → owner escalation (D5). The member sends a DESIRED STATE:
  /// [targetVersion] is the stop they picked on their own replay slider — the
  /// owner restores the scope to that version instead of deleting every edit
  /// the member made.
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    required int targetVersion,
    UndoRequestArea? area,
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
