const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const {
  getFriendRef,
  getRequestRef,
  hasAnyBlock,
} = require('./relationship_utils');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;
  const currentUid = auth?.uid;

  try {
    if (!currentUid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { targetUid } = data;
    validateUID(targetUid, 'targetUid');
    validateDifferentUIDs(currentUid, targetUid);

    const firestore = admin.firestore();

    const result = await firestore.runTransaction(async (transaction) => {
      const currentFriendRef = getFriendRef(firestore, currentUid, targetUid);
      const targetFriendRef = getFriendRef(firestore, targetUid, currentUid);
      const requestRef = getRequestRef(firestore, currentUid, targetUid);

      const [currentFriendDoc, targetFriendDoc] = await Promise.all([
        transaction.get(currentFriendRef),
        transaction.get(targetFriendRef),
      ]);

      if (!currentFriendDoc.exists && !targetFriendDoc.exists) {
        return { success: true, message: 'Users are not friends.' };
      }

      if (await hasAnyBlock(transaction, firestore, currentUid, targetUid)) {
        transaction.delete(requestRef);
      }

      transaction.delete(currentFriendRef);
      transaction.delete(targetFriendRef);
      transaction.delete(requestRef);

      return {
        success: true,
        message: 'Friendship removed successfully.',
      };
    });

    logger.info('User unfriended successfully', {
      uid: currentUid,
      targetUid,
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('unfriendUser failed', error);
    throw new HttpsError('internal', 'Failed to remove friendship.');
  }
};