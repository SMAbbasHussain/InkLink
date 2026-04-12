const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const {
  getFriendRef,
  getRequestRef,
  hasAnyBlock,
} = require('./relationship_utils');
const logger = require('../utils/logger');

function toNonNegativeInt(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value < 0 ? 0 : Math.trunc(value);
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isNaN(parsed)) {
      return parsed < 0 ? 0 : parsed;
    }
  }
  return 0;
}

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
      const currentUserRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(currentUid);
      const targetUserRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(targetUid);

      const [currentFriendDoc, targetFriendDoc, currentUserDoc, targetUserDoc] = await Promise.all([
        transaction.get(currentFriendRef),
        transaction.get(targetFriendRef),
        transaction.get(currentUserRef),
        transaction.get(targetUserRef),
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

      const currentCount = toNonNegativeInt(
        currentUserDoc.data()?.[FirestorePaths.FRIEND_COUNT],
      );
      const targetCount = toNonNegativeInt(
        targetUserDoc.data()?.[FirestorePaths.FRIEND_COUNT],
      );

      if (currentUserDoc.exists) {
        transaction.update(currentUserRef, {
          [FirestorePaths.FRIEND_COUNT]: Math.max(0, currentCount - 1),
          [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      if (targetUserDoc.exists) {
        transaction.update(targetUserRef, {
          [FirestorePaths.FRIEND_COUNT]: Math.max(0, targetCount - 1),
          [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

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