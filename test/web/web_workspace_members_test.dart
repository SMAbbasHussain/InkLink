import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';

/// The web repository's workspace rules mirror the phone's Firestore rules:
/// only the owner manages members, the owner is never demoted or removed, and
/// only the phone's role values are accepted.
void main() {
  late SampleWebCompanionRepository repo;

  setUp(() {
    repo = SampleWebCompanionRepository();
  });

  Future<void> expectMessage(Future<void> call, String message) => expectLater(
    call,
    throwsA(predicate((e) => e.toString().contains(message))),
  );

  test('members come with their roles, sorted owner first', () async {
    final members = await repo.watchWorkspaceMembers('w-product').first;
    expect(members.map((m) => m.role).toList(), [
      'owner',
      'editor',
      'member',
      'viewer',
    ]);
    expect(members.first.displayName, 'Sam Rivera');
    expect(members.first.email, 'sam.rivera@example.com');
  });

  test('the owner can change a role', () async {
    await repo.updateWorkspaceMemberRole(
      workspaceId: 'w-product',
      memberUid: 'u2',
      role: 'viewer',
    );
    final members = await repo.watchWorkspaceMembers('w-product').first;
    expect(members.firstWhere((m) => m.uid == 'u2').role, 'viewer');
  });

  test('the owner can remove a member and the count drops', () async {
    final before = (await repo.watchMyWorkspaces().first)
        .firstWhere((w) => w.id == 'w-product')
        .memberCount;

    await repo.removeWorkspaceMember(workspaceId: 'w-product', memberUid: 'u4');

    final after = (await repo.watchMyWorkspaces().first)
        .firstWhere((w) => w.id == 'w-product')
        .memberCount;
    expect(after, before - 1);
    final members = await repo.watchWorkspaceMembers('w-product').first;
    expect(members.any((m) => m.uid == 'u4'), isFalse);
  });

  test('a non-owner cannot change roles or remove members', () async {
    await expectMessage(
      repo.updateWorkspaceMemberRole(
        workspaceId: 'w-home',
        memberUid: 'u3',
        role: 'viewer',
      ),
      'Only the workspace owner can change member roles.',
    );
    await expectMessage(
      repo.removeWorkspaceMember(workspaceId: 'w-home', memberUid: 'u3'),
      'Only the workspace owner can remove members.',
    );
  });

  test('the owner is never demoted or removed', () async {
    await expectMessage(
      repo.updateWorkspaceMemberRole(
        workspaceId: 'w-product',
        memberUid: 'me',
        role: 'viewer',
      ),
      "The workspace owner's role cannot be changed.",
    );
    await expectMessage(
      repo.removeWorkspaceMember(workspaceId: 'w-product', memberUid: 'me'),
      'The workspace owner cannot be removed.',
    );
  });

  test('only the phone role values are accepted', () async {
    await expectMessage(
      repo.updateWorkspaceMemberRole(
        workspaceId: 'w-product',
        memberUid: 'u2',
        role: 'admiral',
      ),
      'Choose a valid workspace role.',
    );
  });

  test('a member who left is reported instead of silently ignored', () async {
    await repo.removeWorkspaceMember(workspaceId: 'w-product', memberUid: 'u4');
    await expectMessage(
      repo.updateWorkspaceMemberRole(
        workspaceId: 'w-product',
        memberUid: 'u4',
        role: 'editor',
      ),
      'That member is no longer in this workspace.',
    );
  });

  test('the owner can invite someone who is not yet a member', () async {
    await repo.inviteToWorkspace(workspaceId: 'w-product', userIds: ['u5']);
    await expectMessage(
      repo.inviteToWorkspace(workspaceId: 'w-product', userIds: ['u5']),
      'Everyone you picked is already in this workspace.',
    );
  });

  test('a non-owner cannot invite', () async {
    await expectMessage(
      repo.inviteToWorkspace(workspaceId: 'w-home', userIds: ['u5']),
      'Only the workspace owner can invite members.',
    );
  });

  test('a member can leave, and the workspace leaves their list', () async {
    await repo.leaveWorkspace('w-home');
    final workspaces = await repo.watchMyWorkspaces().first;
    expect(workspaces.any((w) => w.id == 'w-home'), isFalse);

    await expectMessage(
      repo.leaveWorkspace('w-product'),
      'The workspace owner cannot leave',
    );
  });

  test('only the owner can delete a workspace', () async {
    await expectMessage(
      repo.deleteWorkspace('w-home'),
      'Only the workspace owner can delete the workspace.',
    );
    await repo.deleteWorkspace('w-product');
    final workspaces = await repo.watchMyWorkspaces().first;
    expect(workspaces.any((w) => w.id == 'w-product'), isFalse);
  });

  test(
    'workspace details write the phone fields name and description',
    () async {
      await repo.updateWorkspace(
        workspaceId: 'w-product',
        name: 'Product Guild',
        description: 'Renamed from the web.',
      );
      final workspace = (await repo.watchMyWorkspaces().first).firstWhere(
        (w) => w.id == 'w-product',
      );
      expect(workspace.name, 'Product Guild');
      expect(workspace.description, 'Renamed from the web.');
    },
  );
}
