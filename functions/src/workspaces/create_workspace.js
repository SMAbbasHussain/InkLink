const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const rawName = request.data?.name;
  const rawDescription = request.data?.description;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof rawName !== 'string' || rawName.trim().length < 2) {
      throw new HttpsError('invalid-argument', 'Workspace name must be at least 2 characters.');
    }

    const name = rawName.trim();
    const description = typeof rawDescription === 'string' ? rawDescription.trim() : '';

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc();

    await firestore.runTransaction(async (transaction) => {
      transaction.set(workspaceRef, {
        workspaceId: workspaceRef.id,
        ownerId: uid,
        [FirestorePaths.NAME]: name,
        [FirestorePaths.DESCRIPTION]: description,
        memberCount: 1,
        boardCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(
        workspaceRef.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid),
        {
          uid,
          role: 'owner',
          status: 'active',
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
      );
    });

    return { success: true, workspaceId: workspaceRef.id };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('createWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to create workspace.');
  }
};