const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const {
  getBlockRef,
  getFriendRef,
  getRequestRef,
} = require('./relationship_utils');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;
  const blockerUid = auth?.uid;

  try {
    if (!blockerUid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { targetUid, reason } = data;
    validateUID(targetUid, 'targetUid');
    validateDifferentUIDs(blockerUid, targetUid);

    const firestore = admin.firestore();
    const blockRef = getBlockRef(firestore, blockerUid, targetUid);
    const requestRef = getRequestRef(firestore, blockerUid, targetUid);

    const result = await firestore.runTransaction(async (transaction) => {
      const currentFriendRef = getFriendRef(firestore, blockerUid, targetUid);
      const targetFriendRef = getFriendRef(firestore, targetUid, blockerUid);

      transaction.set(blockRef, {
        blockerUid,
        blockedUid: targetUid,
        reason: typeof reason === 'string' && reason.trim().length > 0
          ? reason.trim()
          : null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.delete(currentFriendRef);
      transaction.delete(targetFriendRef);
      transaction.delete(requestRef);

      return {
        success: true,
        message: 'User blocked successfully.',
        blockId: blockRef.id,
      };
    });

    logger.info('User blocked successfully', {
      uid: blockerUid,
      targetUid,
      blockId: result.blockId,
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('blockUser failed', error);
    throw new HttpsError('internal', 'Failed to block user.');
  }
};