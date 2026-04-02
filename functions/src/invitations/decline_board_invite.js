const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { updateUserNotificationStatus } = require('../utils/notification_sender');

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

    await firestore.runTransaction(async (transaction) => {
      const inviteRef = firestore.collection(FirestorePaths.BOARD_INVITES).doc(inviteId);
      const inviteDoc = await transaction.get(inviteRef);

      if (!inviteDoc.exists) {
        throw new HttpsError('not-found', 'Invite not found.');
      }

      const invite = inviteDoc.data() || {};
      if (invite.toUid !== uid) {
        throw new HttpsError('permission-denied', 'Invite is not assigned to current user.');
      }

      if (invite.status !== 'pending') {
        throw new HttpsError('failed-precondition', 'Invite is no longer pending.');
      }

      transaction.update(inviteRef, {
        status: 'declined',
        declinedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await updateUserNotificationStatus({
      recipientUid: uid,
      type: 'board_invite',
      targetId: inviteId,
      status: 'declined',
      title: 'Board invite declined',
      body: 'You declined this board invite.',
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('declineBoardInvite failed', error);
    throw new HttpsError('internal', 'Failed to decline board invite.');
  }
};
