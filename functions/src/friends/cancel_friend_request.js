const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateRequestId, validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { getRequestRef } = require('./relationship_utils');
const { updateUserNotificationStatus } = require('../utils/notification_sender');

module.exports = async (request) => {
  const { auth, data } = request;
  const senderUid = auth?.uid;

  try {
    if (!senderUid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { requestId, targetUid } = data;
    validateRequestId(requestId);
    validateUID(targetUid, 'targetUid');
    validateDifferentUIDs(senderUid, targetUid);

    const firestore = admin.firestore();
    const requestRef = getRequestRef(firestore, senderUid, targetUid);

    const result = await firestore.runTransaction(async (transaction) => {
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw new HttpsError('not-found', 'Friend request not found.');
      }

      const requestData = requestDoc.data() || {};
      if (requestData[FirestorePaths.FROM_UID] !== senderUid) {
        throw new HttpsError('permission-denied', 'You can only cancel requests you sent.');
      }

      if (requestData[FirestorePaths.TO_UID] !== targetUid) {
        throw new HttpsError('permission-denied', 'Request target mismatch.');
      }

      transaction.delete(requestRef);

      return {
        success: true,
        requestId,
        targetUid,
      };
    });

    await updateUserNotificationStatus({
      recipientUid: targetUid,
      type: 'friend_request',
      targetId: requestId,
      status: 'cancelled',
      title: 'Friend request cancelled',
      body: 'The request was cancelled.',
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('cancelFriendRequest failed', error);
    throw new HttpsError('internal', 'Failed to cancel friend request.');
  }
};