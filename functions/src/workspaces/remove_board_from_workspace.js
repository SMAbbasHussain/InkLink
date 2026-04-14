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
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    const workspace = workspaceDoc.data() || {};
    const memberDoc = await workspaceRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(uid)
      .get();

    if (workspace.ownerId !== uid && !memberDoc.exists) {
      throw new HttpsError('permission-denied', 'Only workspace members can remove boards.');
    }

    await workspaceRef.collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION).doc(boardId.trim()).delete();

    await workspaceRef.set(
      {
        boardCount: admin.firestore.FieldValue.increment(-1),
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { success: true, workspaceId: workspaceId.trim(), boardId: boardId.trim() };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('removeBoardFromWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to remove board from workspace.');
  }
};