class Workspace {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final int memberCount;
  final int boardCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? currentUserRole; // 'owner' or other roles if added later

  const Workspace({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.boardCount,
    required this.createdAt,
    required this.updatedAt,
    this.currentUserRole,
  });

  Workspace copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    int? memberCount,
    int? boardCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currentUserRole,
  }) {
    return Workspace(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      memberCount: memberCount ?? this.memberCount,
      boardCount: boardCount ?? this.boardCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentUserRole: currentUserRole ?? this.currentUserRole,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workspace &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerId == other.ownerId &&
          name == other.name &&
          description == other.description &&
          memberCount == other.memberCount &&
          boardCount == other.boardCount &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          currentUserRole == other.currentUserRole;

  @override
  int get hashCode =>
      id.hashCode ^
      ownerId.hashCode ^
      name.hashCode ^
      description.hashCode ^
      memberCount.hashCode ^
      boardCount.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      currentUserRole.hashCode;

  @override
  String toString() =>
      'Workspace(id: $id, ownerId: $ownerId, name: $name, description: $description, memberCount: $memberCount, boardCount: $boardCount, currentUserRole: $currentUserRole)';
}

class WorkspaceInvite {
  final String id;
  final String workspaceId;
  final String fromUid;
  final String toUid;
  final String senderName;
  final String? senderPhotoUrl;
  final String workspaceName;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;

  const WorkspaceInvite({
    required this.id,
    required this.workspaceId,
    required this.fromUid,
    required this.toUid,
    this.senderName = 'InkLink User',
    this.senderPhotoUrl,
    this.workspaceName = 'Workspace',
    required this.status,
    required this.timestamp,
    this.acceptedAt,
    this.rejectedAt,
  });

  WorkspaceInvite copyWith({
    String? id,
    String? workspaceId,
    String? fromUid,
    String? toUid,
    String? senderName,
    String? senderPhotoUrl,
    String? workspaceName,
    String? status,
    DateTime? timestamp,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
  }) {
    return WorkspaceInvite(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      workspaceName: workspaceName ?? this.workspaceName,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceInvite &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          fromUid == other.fromUid &&
          toUid == other.toUid &&
          senderName == other.senderName &&
          senderPhotoUrl == other.senderPhotoUrl &&
          workspaceName == other.workspaceName &&
          status == other.status &&
          timestamp == other.timestamp &&
          acceptedAt == other.acceptedAt &&
          rejectedAt == other.rejectedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      workspaceId.hashCode ^
      fromUid.hashCode ^
      toUid.hashCode ^
      senderName.hashCode ^
      senderPhotoUrl.hashCode ^
      workspaceName.hashCode ^
      status.hashCode ^
      timestamp.hashCode ^
      acceptedAt.hashCode ^
      rejectedAt.hashCode;

  @override
  String toString() =>
      'WorkspaceInvite(id: $id, workspaceId: $workspaceId, fromUid: $fromUid, toUid: $toUid, senderName: $senderName, workspaceName: $workspaceName, status: $status)';
}

class WorkspaceMember {
  final String uid;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const WorkspaceMember({
    required this.uid,
    required this.role,
    required this.status,
    this.joinedAt,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!;
    }
    return uid;
  }
}
