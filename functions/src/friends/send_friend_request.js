const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const { sendUserNotification } = require('../utils/notification_sender');
const logger = require('../utils/logger');

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

    const { targetUid } = data;
    validateUID(targetUid, 'targetUid');
    validateDifferentUIDs(senderUid, targetUid);

    const firestore = admin.firestore();
    const ids = [senderUid, targetUid].sort();
    const requestId = ids.join('_');

    await firestore.runTransaction(async (transaction) => {
      const senderFriendRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(senderUid)
        .collection(FirestorePaths.FRIENDS_SUBCOLLECTION)
        .doc(targetUid);

      const senderFriendDoc = await transaction.get(senderFriendRef);
      if (senderFriendDoc.exists) {
        throw new HttpsError('already-exists', 'Already friends.');
      }

      const requestRef = firestore
        .collection(FirestorePaths.FRIEND_REQUESTS)
        .doc(requestId);

      const existingRequest = await transaction.get(requestRef);
      if (existingRequest.exists) {
        return;
      }

      const senderDoc = await transaction.get(
        firestore.collection(FirestorePaths.USERS).doc(senderUid),
      );
      if (!senderDoc.exists) {
        throw new HttpsError('not-found', 'Sender account not found.');
      }

      const targetDoc = await transaction.get(
        firestore.collection(FirestorePaths.USERS).doc(targetUid),
      );
      if (!targetDoc.exists) {
        throw new HttpsError('not-found', 'Target user not found.');
      }

      const senderData = senderDoc.data() || {};

      transaction.set(requestRef, {
        [FirestorePaths.FROM_UID]: senderUid,
        [FirestorePaths.TO_UID]: targetUid,
        [FirestorePaths.SENDER_NAME]: senderData.displayName || 'InkLink User',
        [FirestorePaths.SENDER_PIC]: senderData.photoURL || null,
        [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
        [FirestorePaths.STATUS]: 'pending',
      });
    });

    const senderDoc = await firestore
      .collection(FirestorePaths.USERS)
      .doc(senderUid)
      .get();
    const senderData = senderDoc.data() || {};

    const notificationResult = await sendUserNotification({
      recipientUid: targetUid,
      title: `${senderData.displayName || 'Someone'} sent you a friend request`,
      body: 'Open requests to accept or decline.',
      type: 'friend_request',
      action: 'open_friend_requests',
      targetId: requestId,
      senderUid,
      senderName: senderData.displayName || 'InkLink User',
      senderPhotoUrl: senderData.photoURL || null,
      groupingKey: `friend_request:${senderUid}:${targetUid}`,
      extraData: {
        requestId,
      },
    });

    return {
      success: true,
      requestId,
      ...notificationResult,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('sendFriendRequest failed', error);
    throw new HttpsError('internal', 'Failed to send friend request.');
  }
};
