const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;
  const boardId = request.data?.boardId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'workspaceId is required.');
    }

    if (typeof boardId !== 'string' || boardId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId.trim());

    const [workspaceDoc, boardDoc, workspaceBoardDoc, workspaceMembersSnapshot] = await Promise.all([
      workspaceRef.get(),
      boardRef.get(),
      workspaceRef
        .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
        .doc(boardId.trim())
        .get(),
      workspaceRef
        .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .where(FirestorePaths.STATUS, '==', 'active')
        .get(),
    ]);

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const workspaceMemberDoc = await workspaceRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(uid)
      .get();

    if (!workspaceMemberDoc.exists || workspaceMemberDoc.data()?.status !== 'active') {
      throw new HttpsError('permission-denied', 'You are not an active workspace member.');
    }

    const boardData = boardDoc.data() || {};
    const boardOwnerId = boardData[FirestorePaths.OWNER_ID];
    const boardMembers = Array.isArray(boardData.members) ? boardData.members : [];

    if (boardOwnerId !== uid && !boardMembers.includes(uid)) {
      throw new HttpsError('permission-denied', 'You can only add boards you own or joined.');
    }

    // Use a batched write to avoid long transactions and repeated locks for large workspaces.
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Prepare member UIDs and their board-member doc refs
    const memberUids = [];
    const boardMemberRefs = [];
    for (const memberDoc of workspaceMembersSnapshot.docs) {
      const memberData = memberDoc.data() || {};
      const memberUid = (memberData[FirestorePaths.UID] || memberDoc.id).toString().trim();
      if (!memberUid) continue;
      memberUids.push(memberUid);
      boardMemberRefs.push(
        boardRef.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(memberUid),
      );
    }

    const batch = firestore.batch();

    // Upsert workspace->board link
    batch.set(
      workspaceRef.collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION).doc(boardId.trim()),
      {
        boardId: boardId.trim(),
        [FirestorePaths.BOARD_SOURCE]: 'imported',
        addedBy: uid,
        addedAt: now,
        visibilityInWorkspace: 'private',
        [FirestorePaths.UPDATED_AT]: now,
      },
      { merge: true },
    );

    if (!workspaceBoardDoc.exists) {
      batch.set(
        workspaceRef,
        {
          boardCount: admin.firestore.FieldValue.increment(1),
          [FirestorePaths.UPDATED_AT]: now,
        },
        { merge: true },
      );
    }

    // Fetch existing board member docs in parallel to determine whether to insert full doc or just update status
    const existingPromises = boardMemberRefs.map((ref) => ref.get());
    const existingDocs = await Promise.all(existingPromises);

    for (let idx = 0; idx < memberUids.length; idx++) {
      const memberUid = memberUids[idx];
      const existing = existingDocs[idx];
      if (existing.exists) {
        batch.set(
          boardMemberRefs[idx],
          {
            status: 'active',
            [FirestorePaths.UPDATED_AT]: now,
          },
          { merge: true },
        );
      } else {
        batch.set(
          boardMemberRefs[idx],
          {
            uid: memberUid,
            role: boardOwnerId === memberUid ? 'owner' : 'viewer',
            status: 'active',
            joinedAt: now,
            invitedBy: uid,
            [FirestorePaths.UPDATED_AT]: now,
          },
          { merge: true },
        );
      }
    }

    // Update board members array once with all member UIDs
    if (memberUids.length > 0) {
      batch.update(boardRef, {
        members: admin.firestore.FieldValue.arrayUnion(...memberUids),
        [FirestorePaths.MEMBER_COUNT]: admin.firestore.FieldValue.increment(memberUids.length),
        [FirestorePaths.UPDATED_AT]: now,
      });
    }

    for (const memberUid of memberUids) {
      const userRef = firestore.collection(FirestorePaths.USERS).doc(memberUid);
      // Increment user's board count
      batch.set(userRef, {
        [FirestorePaths.BOARD_COUNT]: admin.firestore.FieldValue.increment(1),
        [FirestorePaths.UPDATED_AT]: now,
      }, { merge: true });
      // Also create user-level board index document for newer schema
      const userBoardRef = userRef.collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION).doc(boardId.trim());
      const relation = boardOwnerId === memberUid ? 'owned' : 'joined';
      batch.set(userBoardRef, {
        boardId: boardId.trim(),
        relation,
        addedAt: now,
        [FirestorePaths.UPDATED_AT]: now,
      }, { merge: true });
    }

    await batch.commit();
    return { success: true, workspaceId: workspaceId.trim(), boardId: boardId.trim() };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('addBoardToWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to add board to workspace.');
  }
};