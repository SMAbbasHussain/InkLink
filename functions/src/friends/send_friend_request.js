const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const {
  sendUserNotification,
  updateUserNotificationStatus,
} = require('../utils/notification_sender');
const { hasAnyBlock, getFriendRef, getRequestRef } = require('./relationship_utils');
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
    const requestId = getRequestRef(firestore, senderUid, targetUid).id;

    const transactionResult = await firestore.runTransaction(async (transaction) => {
      const senderFriendRef = getFriendRef(firestore, senderUid, targetUid);

      const senderFriendDoc = await transaction.get(senderFriendRef);
      if (senderFriendDoc.exists) {
        throw new HttpsError('already-exists', 'Already friends.');
      }

      if (await hasAnyBlock(transaction, firestore, senderUid, targetUid)) {
        throw new HttpsError('permission-denied', 'You cannot send a request to this user.');
      }

      const requestRef = getRequestRef(firestore, senderUid, targetUid);

      const existingRequest = await transaction.get(requestRef);
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
      const targetData = targetDoc.data() || {};

      if (existingRequest.exists) {
        const existingData = existingRequest.data() || {};
        const isReciprocalPending =
          existingData[FirestorePaths.FROM_UID] === targetUid &&
          existingData[FirestorePaths.TO_UID] === senderUid &&
          existingData[FirestorePaths.STATUS] === 'pending';

        if (!isReciprocalPending) {
          return {
            mode: 'already_pending',
            requestId,
            senderName: senderData.displayName || 'InkLink User',
            senderPhotoUrl: senderData.photoURL || null,
          };
        }

        const targetFriendRef = getFriendRef(firestore, targetUid, senderUid);
        const targetFriendDoc = await transaction.get(targetFriendRef);
        if (!targetFriendDoc.exists) {
          transaction.set(targetFriendRef, {
            [FirestorePaths.UID]: senderUid,
            [FirestorePaths.SINCE]: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        if (!senderFriendDoc.exists) {
          transaction.set(senderFriendRef, {
            [FirestorePaths.UID]: targetUid,
            [FirestorePaths.SINCE]: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const senderFriendCount = toNonNegativeInt(
          senderData[FirestorePaths.FRIEND_COUNT],
        );
        const targetFriendCount = toNonNegativeInt(
          targetData[FirestorePaths.FRIEND_COUNT],
        );

        if (!senderFriendDoc.exists) {
          transaction.update(
            firestore.collection(FirestorePaths.USERS).doc(senderUid),
            {
              [FirestorePaths.FRIEND_COUNT]: senderFriendCount + 1,
              [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
            },
          );
        }

        if (!targetFriendDoc.exists) {
          transaction.update(
            firestore.collection(FirestorePaths.USERS).doc(targetUid),
            {
              [FirestorePaths.FRIEND_COUNT]: targetFriendCount + 1,
              [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
            },
          );
        }

        // Remove the pending request only after friendship is established.
        transaction.delete(requestRef);

        return {
          mode: 'accepted_reciprocal',
          requestId,
          senderName: senderData.displayName || 'InkLink User',
          senderPhotoUrl: senderData.photoURL || null,
          targetName: targetData.displayName || 'InkLink User',
          targetPhotoUrl: targetData.photoURL || null,
        };
      }

      transaction.set(requestRef, {
        [FirestorePaths.FROM_UID]: senderUid,
        [FirestorePaths.TO_UID]: targetUid,
        [FirestorePaths.SENDER_NAME]: senderData.displayName || 'InkLink User',
        [FirestorePaths.SENDER_PIC]: senderData.photoURL || null,
        recipientName: targetData.displayName || 'InkLink User',
        recipientPic: targetData.photoURL || null,
        [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
        [FirestorePaths.STATUS]: 'pending',
      });

      return {
        mode: 'new_request',
        requestId,
        senderName: senderData.displayName || 'InkLink User',
        senderPhotoUrl: senderData.photoURL || null,
      };
    });

    if (transactionResult.mode === 'already_pending') {
      return {
        success: true,
        requestId,
        alreadyPending: true,
      };
    }

    if (transactionResult.mode === 'accepted_reciprocal') {
      await updateUserNotificationStatus({
        recipientUid: senderUid,
        type: 'friend_request',
        targetId: requestId,
        status: 'accepted',
        title: 'Friend request accepted',
        body: `You accepted ${transactionResult.targetName || 'this'} friend request.`,
      });

      const notificationResult = await sendUserNotification({
        recipientUid: targetUid,
        title: `${transactionResult.senderName} accepted your friend request`,
        body: 'You are now friends on InkLink.',
        type: 'friend_request_accepted',
        action: 'open_friends',
        targetId: senderUid,
        senderUid,
        senderName: transactionResult.senderName,
        senderPhotoUrl: transactionResult.senderPhotoUrl,
        groupingKey: `friend_request_accepted:${senderUid}:${targetUid}`,
        extraData: {
          friendUid: senderUid,
          requestId,
        },
      });

      return {
        success: true,
        requestId,
        autoAccepted: true,
        ...notificationResult,
      };
    }

    const notificationResult = await sendUserNotification({
      recipientUid: targetUid,
      title: `${transactionResult.senderName || 'Someone'} sent you a friend request`,
      body: 'Open requests to accept or decline.',
      type: 'friend_request',
      action: 'open_friend_requests',
      targetId: requestId,
      senderUid,
      senderName: transactionResult.senderName || 'InkLink User',
      senderPhotoUrl: transactionResult.senderPhotoUrl || null,
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
