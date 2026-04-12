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

    const result = await firestore.runTransaction(async (transaction) => {
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

      const { expiresAt, boardId } = invite;
      if (
        expiresAt &&
        typeof expiresAt.toDate === 'function' &&
        expiresAt.toDate().getTime() < Date.now()
      ) {
        transaction.update(inviteRef, {
          status: 'expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw new HttpsError('deadline-exceeded', 'Invite has expired.');
      }

      const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }
      const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);

      transaction.update(boardRef, {
        members: admin.firestore.FieldValue.arrayUnion(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayUnion(boardId),
        [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Keep board_invites as a pending-only collection.
      // Once accepted, remove the invite document.
      transaction.delete(inviteRef);

      return { success: true, boardId, inviteId };
    });

    await updateUserNotificationStatus({
      recipientUid: uid,
      type: 'board_invite',
      targetId: inviteId,
      status: 'accepted',
      title: 'Board invite accepted',
      body: 'You accepted this board invite.',
    });

    return result;

  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('acceptBoardInvite failed', error);
    throw new HttpsError('internal', 'Failed to accept board invite.');
  }
};
