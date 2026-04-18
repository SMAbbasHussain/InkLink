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

    const userDoc = await firestore.collection(FirestorePaths.USERS).doc(uid).get();
    const userData = userDoc.data() || {};
    const ownedBoards = Array.isArray(userData.ownedBoards) ? userData.ownedBoards : [];
    const joinedBoards = Array.isArray(userData.joinedBoards) ? userData.joinedBoards : [];

    if (!ownedBoards.includes(boardId.trim()) && !joinedBoards.includes(boardId.trim())) {
      throw new HttpsError('permission-denied', 'You can only add boards you own or joined.');
    }

    return await firestore.runTransaction(async (transaction) => {
      const boardData = boardDoc.data() || {};
      const boardOwnerId = boardData[FirestorePaths.OWNER_ID];
      const now = admin.firestore.FieldValue.serverTimestamp();

      const memberTargets = [];
      for (const memberDoc of workspaceMembersSnapshot.docs) {
        const memberData = memberDoc.data() || {};
        const memberUid = (memberData[FirestorePaths.UID] || memberDoc.id).toString().trim();
        if (!memberUid) {
          continue;
        }

        const boardMemberRef = boardRef
          .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
          .doc(memberUid);
        const existingBoardMemberDoc = await transaction.get(boardMemberRef);

        memberTargets.push({
          memberUid,
          boardMemberRef,
          existingBoardMemberDoc,
        });
      }

      transaction.set(
        workspaceRef
          .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
          .doc(boardId.trim()),
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
        transaction.set(
          workspaceRef,
          {
            boardCount: admin.firestore.FieldValue.increment(1),
            [FirestorePaths.UPDATED_AT]: now,
          },
          { merge: true },
        );
      }

      for (const target of memberTargets) {
        transaction.set(
          target.boardMemberRef,
          target.existingBoardMemberDoc.exists
            ? {
                status: 'active',
                [FirestorePaths.UPDATED_AT]: now,
              }
            : {
                uid: target.memberUid,
                role: boardOwnerId === target.memberUid ? 'owner' : 'viewer',
                status: 'active',
                joinedAt: now,
                invitedBy: uid,
                [FirestorePaths.UPDATED_AT]: now,
              },
          { merge: true },
        );

        transaction.update(boardRef, {
          members: admin.firestore.FieldValue.arrayUnion(target.memberUid),
          [FirestorePaths.UPDATED_AT]: now,
        });

        transaction.set(
          firestore.collection(FirestorePaths.USERS).doc(target.memberUid),
          boardOwnerId === target.memberUid
            ? {
                [FirestorePaths.OWNED_BOARDS]: admin.firestore.FieldValue.arrayUnion(boardId.trim()),
                [FirestorePaths.UPDATED_AT]: now,
              }
            : {
                [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayUnion(boardId.trim()),
                [FirestorePaths.UPDATED_AT]: now,
              },
          { merge: true },
        );
      }

      return { success: true, workspaceId: workspaceId.trim(), boardId: boardId.trim() };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('addBoardToWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to add board to workspace.');
  }
};