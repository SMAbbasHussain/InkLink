const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;
  const importedBoardsToKeep = Array.isArray(request.data?.importedBoardsToKeep)
    ? request.data.importedBoardsToKeep
    : [];

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'workspaceId is required.');
    }

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    const workspace = workspaceDoc.data() || {};
    if (workspace.ownerId === uid) {
      throw new HttpsError('failed-precondition', 'Workspace owner cannot leave. Delete workspace or transfer ownership first.');
    }

    return await firestore.runTransaction(async (transaction) => {
      // Get all workspace boards
      const boardsSnapshot = await workspaceRef
        .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
        .get();

      const boardsToRemoveFrom = []; // workspace-native boards
      const importedBoardsToRemoveFrom = []; // imported boards not in keepList

      boardsSnapshot.docs.forEach((boardDoc) => {
        const boardData = boardDoc.data() || {};
        const boardId = boardData.boardId || boardDoc.id;
        const boardSource = boardData[FirestorePaths.BOARD_SOURCE] || 'imported';

        if (boardSource === 'workspace_native') {
          // User will be removed from all workspace-native boards
          boardsToRemoveFrom.push(boardId);
        } else if (
          boardSource === 'imported' &&
          !importedBoardsToKeep.includes(boardId)
        ) {
          // User chose not to keep this imported board
          importedBoardsToRemoveFrom.push(boardId);
        }
      });

      // Remove user from workspace
      const memberRef = workspaceRef
        .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .doc(uid);
      const memberDoc = await transaction.get(memberRef);

      if (memberDoc.exists) {
        transaction.delete(memberRef);
        transaction.set(
          workspaceRef,
          {
            memberCount: admin.firestore.FieldValue.increment(-1),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      // Remove user from workspace in their user doc
      transaction.set(
        firestore.collection(FirestorePaths.USERS).doc(uid),
        {
          [FirestorePaths.WORKSPACE_IDS]: admin.firestore.FieldValue.arrayRemove(
            workspaceId.trim(),
          ),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Remove user from workspace-native boards
      const allBoardsToRemoveFrom = [
        ...boardsToRemoveFrom,
        ...importedBoardsToRemoveFrom,
      ];

      allBoardsToRemoveFrom.forEach((boardId) => {
        const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
        const memberRef = boardRef
          .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
          .doc(uid);

        transaction.delete(memberRef);
        transaction.set(
          firestore.collection(FirestorePaths.USERS).doc(uid),
          {
            [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayRemove(
              boardId,
            ),
            [FirestorePaths.OWNED_BOARDS]: admin.firestore.FieldValue.arrayRemove(boardId),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });

      return {
        success: true,
        workspaceId: workspaceId.trim(),
        removed: {
          workspaceNativeBoards: boardsToRemoveFrom,
          importedBoards: importedBoardsToRemoveFrom,
        },
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('leaveWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to leave workspace.');
  }
};