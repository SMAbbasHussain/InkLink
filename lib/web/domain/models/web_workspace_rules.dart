import '../../../domain/models/workspace.dart';

/// Roles a workspace owner may assign. `owner` is fixed and never assignable.
const List<String> assignableWorkspaceRoles = ['editor', 'member', 'viewer'];

bool isAssignableWorkspaceRole(String role) =>
    assignableWorkspaceRoles.contains(role);

/// Human label for a member's role.
String workspaceRoleLabel(String role) => switch (role) {
  'owner' => 'Owner',
  'editor' => 'Editor',
  'viewer' => 'Viewer',
  _ => 'Member',
};

/// Formats a workspace summary string such as `"4 members • 3 boards"`.
String formatWorkspaceCounts(Workspace w) {
  String n(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
  return '${n(w.memberCount, 'member')} • ${n(w.boardCount, 'board')}';
}

/// Members in mobile's order: owner first, then editor, member, viewer,
/// then alphabetically by display label.
List<WorkspaceMember> sortWorkspaceMembers(Iterable<WorkspaceMember> members) {
  const roleOrder = {'owner': 0, 'editor': 1, 'member': 2, 'viewer': 3};
  return List<WorkspaceMember>.of(members)..sort((a, b) {
    final rank = (roleOrder[a.role] ?? 99).compareTo(roleOrder[b.role] ?? 99);
    if (rank != 0) return rank;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
}
