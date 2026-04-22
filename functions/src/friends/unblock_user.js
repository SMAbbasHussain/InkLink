const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const { getBlockRef } = require('./relationship_utils');
const logger = require('../utils/logger');

/**
 * Callable: Unblock a user
 * 
 * Removes a block relationship between the current user and target user.
 * 
 * Rules enforced:
 * - User must be authenticated
 * - Block document must exist before deletion
 * 
 * Returns: { success: bool, message: string }
 */
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
    const blockRef = getBlockRef(firestore, currentUid, targetUid);

    const result = await firestore.runTransaction(async (transaction) => {
      const blockDoc = await transaction.get(blockRef);

      if (!blockDoc.exists) {
        throw new HttpsError('not-found', 'No active block found for this user.');
      }

      transaction.delete(blockRef);

      return {
        success: true,
        message: 'User unblocked successfully.',
      };
    });

    logger.info('User unblocked successfully', {
      uid: currentUid,
      targetUid,
    });

    return result;
  } catch (error) {
    logger.error('Failed to unblock user', {
      uid: currentUid,
      targetUid: data?.targetUid,
      error: error.message,
    });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Unable to unblock user right now.');
  }
};
