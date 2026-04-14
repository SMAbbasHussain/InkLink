const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;
  const boardId = request.data?.boardId;
  const visibility = request.data?.visibility;

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

    const normalizedVisibility = visibility === 'public' ? 'public' : 'private';

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    const workspaceData = workspaceDoc.data() || {};
    if (workspaceData.ownerId !== uid) {
      throw new HttpsError('permission-denied', 'Only workspace owner can update workspace board visibility.');
    }

    const workspaceBoardRef = workspaceRef
      .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
      .doc(boardId.trim());

    await workspaceBoardRef.set(
      {
        boardId: boardId.trim(),
        visibilityInWorkspace: normalizedVisibility,
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      success: true,
      workspaceId: workspaceId.trim(),
      boardId: boardId.trim(),
      visibility: normalizedVisibility,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('setWorkspaceBoardVisibility failed', error);
    throw new HttpsError('internal', 'Failed to update workspace board visibility.');
  }
};