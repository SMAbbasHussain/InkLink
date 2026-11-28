import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/firestore_batch_fetcher.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/workspace.dart';
import '../../core/web_stream_utils.dart';
import '../models/user_board_index.dart';
import '../models/web_workspace_rules.dart';

/// Firestore data source for workspaces, workspace-linked boards, and
/// workspace membership reads/mutations on the web companion.
class WebWorkspaceDataSource {
  final AuthService _auth;
  final FirestoreService _firestore;
  final FirestoreBatchFetcher _batchFetcher;
  final Stream<UserBoardIndex> Function(String uid) _boardIndexForUser;

  WebWorkspaceDataSource({
    required AuthService authService,
    required FirestoreService firestoreService,
    required this._batchFetcher,
    required this._boardIndexForUser,
  }) : _auth = authService,
       _firestore = firestoreService;

  String? get _uid => _auth.getCurrentUserId();

  Stream<List<Workspace>> watchMyWorkspaces() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids =
              ((snapshot.data()?[FirestorePaths.workspaceIds] as List?) ??
                      const [])
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .toList();
          if (ids.isEmpty) return const <Workspace>[];
          final result = await _batchFetcher.fetchDocumentsByIdSet(
            collectionPath: FirestorePaths.workspaces,
            ids: ids,
            trackMissingIds: false,
          );
          return [
            for (final entry in result.docsById.entries)
              _workspaceFrom(entry.key, entry.value, uid),
          ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
  }

  Workspace _workspaceFrom(String id, Map<String, dynamic> data, String uid) {
    DateTime date(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
    return Workspace(
      id: id,
      ownerId: (data[FirestorePaths.ownerId] as String?) ?? '',
      name: (data[FirestorePaths.name] as String?) ?? '',
      description: (data[FirestorePaths.description] as String?) ?? '',
      memberCount: (data[FirestorePaths.memberCount] as num?)?.toInt() ?? 0,
      boardCount: (data[FirestorePaths.boardCount] as num?)?.toInt() ?? 0,
      createdAt: date(data[FirestorePaths.createdAt]),
      updatedAt: date(data[FirestorePaths.updatedAt]),
      currentUserRole: data[FirestorePaths.ownerId] == uid ? 'owner' : 'member',
    );
  }

  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    final links = _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceBoardsSubcollection)
        .snapshots();
    final combined =
        combineLatest2<
          QuerySnapshot<Map<String, dynamic>>,
          UserBoardIndex,
          (QuerySnapshot<Map<String, dynamic>>, UserBoardIndex)
        >(
          links,
          _boardIndexForUser(uid),
          (linkSnapshot, index) => (linkSnapshot, index),
        );
    return combined.asyncMap((pair) async {
      final linkSnapshot = pair.$1;
      final index = pair.$2;
      final ids = visibleWorkspaceBoardIds(
        linkSnapshot.docs.map((d) => MapEntry(d.id, d.data())),
        index.all,
      );
      if (ids.isEmpty) return const <Board>[];
      final result = await _batchFetcher.fetchDocumentsByIdSet(
        collectionPath: FirestorePaths.boards,
        ids: ids,
        trackMissingIds: false,
      );
      return [
        for (final id in ids)
          if (result.docsById[id] case final data?)
            Board.fromMap(data, id).copyWith(
              currentUserRole:
                  index.owned.contains(id) ||
                      data[FirestorePaths.ownerId] == uid
                  ? Board.roleOwner
                  : null,
            ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceMembersSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final docs = snapshot.docs;
          final profiles = await _workspaceMemberProfiles([
            for (final doc in docs)
              (doc.data()[FirestorePaths.uid] as String?) ?? doc.id,
          ]);
          final members = <WorkspaceMember>[];
          for (final doc in docs) {
            final data = doc.data();
            final memberUid = (data[FirestorePaths.uid] as String?) ?? doc.id;
            final profile = profiles[memberUid];
            members.add(
              WorkspaceMember(
                uid: memberUid,
                role: (data['role'] as String?) ?? 'member',
                status: (data[FirestorePaths.status] as String?) ?? 'active',
                joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
                displayName: profile?[FirestorePaths.displayName] as String?,
                email: profile?[FirestorePaths.email] as String?,
                photoUrl: profile?[FirestorePaths.photoURL] as String?,
              ),
            );
          }
          return sortWorkspaceMembers(members);
        });
  }

  Future<Map<String, Map<String, dynamic>>> _workspaceMemberProfiles(
    List<String> uids,
  ) async {
    final profiles = <String, Map<String, dynamic>>{};
    await Future.wait([
      for (final id in uids)
        () async {
          try {
            final doc = await _firestore
                .collection(FirestorePaths.users)
                .doc(id)
                .get();
            final data = doc.data();
            if (data != null) profiles[id] = data;
          } on FirebaseException {
            // Keep the membership without a profile.
          }
        }(),
    ]);
    return profiles;
  }

  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final normalized = role.trim().toLowerCase();
    if (!isAssignableWorkspaceRole(normalized)) {
      throw 'Choose a valid workspace role.';
    }
    final workspaceRef = _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    try {
      final workspace = await workspaceRef.get();
      final ownerId = workspace.data()?[FirestorePaths.ownerId] as String?;
      if (ownerId != uid) {
        throw 'Only the workspace owner can change member roles.';
      }
      if (memberUid == ownerId) {
        throw "The workspace owner's role cannot be changed.";
      }
      await workspaceRef
          .collection(FirestorePaths.workspaceMembersSubcollection)
          .doc(memberUid)
          .update({'role': normalized});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Only the workspace owner can change member roles.';
      }
      throw 'That role could not be changed. Please try again.';
    }
  }

  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final firestore = _firestore.getInstance();
    final workspaceRef = firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(workspaceRef);
        final ownerId = snapshot.data()?[FirestorePaths.ownerId] as String?;
        if (ownerId != uid) {
          throw 'Only the workspace owner can remove members.';
        }
        if (memberUid == ownerId) {
          throw 'The workspace owner cannot be removed.';
        }
        transaction.delete(
          workspaceRef
              .collection(FirestorePaths.workspaceMembersSubcollection)
              .doc(memberUid),
        );
        transaction.update(workspaceRef, {
          FirestorePaths.memberCount: FieldValue.increment(-1),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Only the workspace owner can remove members.';
      }
      throw 'That member could not be removed. Please try again.';
    }
  }
}
