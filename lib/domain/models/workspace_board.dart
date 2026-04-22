import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a board linked to a workspace with workspace-specific metadata.
class WorkspaceBoard {
  static const String sourceImported = 'imported';
  static const String sourceWorkspaceNative = 'workspace_native';

  final String boardId;
  final String source; // 'imported' or 'workspace_native'
  final String addedBy;
  final DateTime addedAt;
  final String visibilityInWorkspace;
  final DateTime updatedAt;

  const WorkspaceBoard({
    required this.boardId,
    required this.source,
    required this.addedBy,
    required this.addedAt,
    required this.visibilityInWorkspace,
    required this.updatedAt,
  });

  factory WorkspaceBoard.fromMap(Map<String, dynamic> map) {
    return WorkspaceBoard(
      boardId: (map['boardId'] ?? map['id'] ?? '') as String,
      source: (map['boardSource'] ?? 'imported') as String,
      addedBy: (map['addedBy'] ?? '') as String,
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visibilityInWorkspace:
          (map['visibilityInWorkspace'] ?? 'private') as String,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'boardId': boardId,
    'boardSource': source,
    'addedBy': addedBy,
    'addedAt': Timestamp.fromDate(addedAt),
    'visibilityInWorkspace': visibilityInWorkspace,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  bool get isWorkspaceNative => source == sourceWorkspaceNative;
  bool get isImported => source == sourceImported;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceBoard &&
          runtimeType == other.runtimeType &&
          boardId == other.boardId &&
          source == other.source;

  @override
  int get hashCode => boardId.hashCode ^ source.hashCode;

  @override
  String toString() =>
      'WorkspaceBoard(boardId: $boardId, source: $source, addedAt: $addedAt)';
}
