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
    const workspaceBoardRef = workspaceRef
      .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
      .doc(boardId.trim());

    const [workspaceDoc, boardDoc, workspaceBoardDoc] = await Promise.all([
      workspaceRef.get(),
      boardRef.get(),
      workspaceBoardRef.get(),
    ]);

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    if (!workspaceBoardDoc.exists) {
      throw new HttpsError('not-found', 'Board is not linked to this workspace.');
    }

    const workspace = workspaceDoc.data() || {};
    const workspaceBoardData = workspaceBoardDoc.data() || {};
    const boardSource = workspaceBoardData[FirestorePaths.BOARD_SOURCE] || 'imported';

    // Only workspace members can remove boards
    const memberDoc = await workspaceRef
      .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
      .doc(uid)
      .get();

    if (workspace.ownerId !== uid && !memberDoc.exists) {
      throw new HttpsError('permission-denied', 'Only workspace members can remove boards.');
    }

    // If imported board: just remove workspace link (existing behavior)
    if (boardSource === 'imported') {
      await workspaceBoardRef.delete();
      await workspaceRef.set(
        {
          boardCount: admin.firestore.FieldValue.increment(-1),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { success: true, workspaceId: workspaceId.trim(), boardId: boardId.trim() };
    }

    // If workspace-native board: remove all non-owner members
    if (boardSource === 'workspace_native') {
      const boardData = boardDoc.data() || {};
      const boardOwnerId = boardData[FirestorePaths.OWNER_ID];

      return await firestore.runTransaction(async (transaction) => {
        // Delete workspace board link
        transaction.delete(workspaceBoardRef);

        // Get all board members
        const membersSnapshot = await boardRef
          .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
          .get();

        // Remove all non-owner members from the board
        membersSnapshot.docs.forEach((memberDoc) => {
          const memberData = memberDoc.data() || {};
          const memberUid = memberData.uid || memberDoc.id;

          if (memberUid !== boardOwnerId) {
            transaction.delete(memberDoc.ref);

            // Remove board from their joinedBoards
            transaction.set(
              firestore.collection(FirestorePaths.USERS).doc(memberUid),
              {
                [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayRemove(
                  boardId.trim(),
                ),
                [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          }
        });

        // Update workspace board count
        transaction.set(
          workspaceRef,
          {
            boardCount: admin.firestore.FieldValue.increment(-1),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        return {
          success: true,
          workspaceId: workspaceId.trim(),
          boardId: boardId.trim(),
          removedNonOwnerMembers: true,
        };
      });
    }

    throw new HttpsError('failed-precondition', `Unknown boardSource: ${boardSource}`);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('removeBoardFromWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to remove board from workspace.');
  }
};