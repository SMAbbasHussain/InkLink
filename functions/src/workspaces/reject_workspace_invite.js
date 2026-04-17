const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const inviteId = request.data?.inviteId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof inviteId !== 'string' || inviteId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'inviteId is required.');
    }

    const firestore = admin.firestore();

    return await firestore.runTransaction(async (transaction) => {
      const inviteRef = firestore
        .collection(FirestorePaths.WORKSPACE_INVITES)
        .doc(inviteId.trim());
      const inviteDoc = await transaction.get(inviteRef);

      if (!inviteDoc.exists) {
        throw new HttpsError('not-found', 'Workspace invite not found.');
      }

      const invite = inviteDoc.data() || {};
      if (invite[FirestorePaths.TO_UID] !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Invite is not assigned to current user.',
        );
      }

      if (invite[FirestorePaths.STATUS] !== 'pending') {
        throw new HttpsError('failed-precondition', 'Invite is no longer pending.');
      }

      transaction.set(
        inviteRef,
        {
          [FirestorePaths.STATUS]: 'rejected',
          [FirestorePaths.REJECTED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { success: true, inviteId: inviteId.trim() };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('rejectWorkspaceInvite failed', error);
    throw new HttpsError('internal', 'Failed to reject workspace invite.');
  }
};
