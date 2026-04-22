const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

/**
 * Create a new board directly within a workspace (workspace-native board).
 * Only workspace members can create workspace-native boards.
 * The creator becomes the board owner.
 */
module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { workspaceId, title, description, visibility } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'workspaceId is required.');
    }

    if (typeof title !== 'string' || title.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'title is required and cannot be empty.');
    }

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    // Verify user is an active workspace member
    const memberDoc = await workspaceRef
      .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
      .doc(uid)
      .get();

    if (!memberDoc.exists || memberDoc.data()?.status !== 'active') {
      throw new HttpsError('permission-denied', 'You must be an active workspace member to create boards.');
    }

    // Create the new board with creator as owner
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc();
    const boardId = boardRef.id;
    const now = admin.firestore.FieldValue.serverTimestamp();

    return await firestore.runTransaction(async (transaction) => {
      // Create board document
      transaction.set(boardRef, {
        [FirestorePaths.OWNER_ID]: uid,
        [FirestorePaths.TITLE]: title.trim(),
        [FirestorePaths.DESCRIPTION]: description?.trim() || '',
        [FirestorePaths.VISIBILITY]: visibility || 'private',
        [FirestorePaths.CREATED_AT]: now,
        [FirestorePaths.UPDATED_AT]: now,
      });

      // Add creator as board owner in members subcollection
      transaction.set(
        boardRef.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid),
        {
          uid,
          role: 'owner',
          status: 'active',
          joinedAt: now,
          [FirestorePaths.UPDATED_AT]: now,
        },
      );

      // Link board to workspace as workspace-native
      transaction.set(
        workspaceRef
          .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
          .doc(boardId),
        {
          boardId,
          [FirestorePaths.BOARD_SOURCE]: 'workspace_native',
          addedBy: uid,
          addedAt: now,
          visibilityInWorkspace: 'private',
          [FirestorePaths.UPDATED_AT]: now,
        },
      );

      // Update user's ownedBoards list
      transaction.set(
        firestore.collection(FirestorePaths.USERS).doc(uid),
        {
          [FirestorePaths.OWNED_BOARDS]: admin.firestore.FieldValue.arrayUnion(boardId),
          [FirestorePaths.BOARD_COUNT]: admin.firestore.FieldValue.increment(1),
          [FirestorePaths.UPDATED_AT]: now,
        },
        { merge: true },
      );

      // Update workspace board count
      transaction.set(
        workspaceRef,
        {
          boardCount: admin.firestore.FieldValue.increment(1),
          [FirestorePaths.UPDATED_AT]: now,
        },
        { merge: true },
      );

      return {
        success: true,
        boardId,
        workspaceId: workspaceId.trim(),
        title: title.trim(),
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('createWorkspaceBoard failed', error);
    throw new HttpsError('internal', 'Failed to create board in workspace.');
  }
};
