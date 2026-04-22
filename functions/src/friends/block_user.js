const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const {
  getBlockRef,
  getFriendRef,
  getRequestRef,
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
      const blockerUserRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(blockerUid);
      const targetUserRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(targetUid);

      const [currentFriendDoc, targetFriendDoc, blockerUserDoc, targetUserDoc] = await Promise.all([
        transaction.get(currentFriendRef),
        transaction.get(targetFriendRef),
        transaction.get(blockerUserRef),
        transaction.get(targetUserRef),
      ]);
      const hadFriendship = currentFriendDoc.exists || targetFriendDoc.exists;

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

      if (hadFriendship) {
        const blockerCount = toNonNegativeInt(
          blockerUserDoc.data()?.[FirestorePaths.FRIEND_COUNT],
        );
        const targetCount = toNonNegativeInt(
          targetUserDoc.data()?.[FirestorePaths.FRIEND_COUNT],
        );

        if (blockerUserDoc.exists) {
          transaction.update(blockerUserRef, {
            [FirestorePaths.FRIEND_COUNT]: Math.max(0, blockerCount - 1),
            [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        if (targetUserDoc.exists) {
          transaction.update(targetUserRef, {
            [FirestorePaths.FRIEND_COUNT]: Math.max(0, targetCount - 1),
            [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

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