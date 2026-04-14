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

    const [workspaceDoc, boardDoc] = await Promise.all([workspaceRef.get(), boardRef.get()]);

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

    await workspaceRef
      .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
      .doc(boardId.trim())
      .set(
        {
          boardId: boardId.trim(),
          addedBy: uid,
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
          visibilityInWorkspace: 'private',
        },
        { merge: true },
      );

    await workspaceRef.set(
      {
        boardCount: admin.firestore.FieldValue.increment(1),
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { success: true, workspaceId: workspaceId.trim(), boardId: boardId.trim() };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('addBoardToWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to add board to workspace.');
  }
};