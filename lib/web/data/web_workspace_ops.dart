import '../../domain/models/workspace.dart';

// Pure workspace rules shared by the web repository implementations and the
// members section. The role strings are the ones the phone stores in
// `workspaces/{id}/members/{uid}`.

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

/// Members in the phone's order: owner first, then editor, member, viewer,
/// then by name.
List<WorkspaceMember> sortWorkspaceMembers(Iterable<WorkspaceMember> members) {
  const roleOrder = {'owner': 0, 'editor': 1, 'member': 2, 'viewer': 3};
  return List<WorkspaceMember>.of(members)..sort((a, b) {
    final rank = (roleOrder[a.role] ?? 99).compareTo(roleOrder[b.role] ?? 99);
    if (rank != 0) return rank;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
}
