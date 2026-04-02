const admin = require('../../server/firebase-admin');
const FirestorePaths = require('./firestore_paths');
const logger = require('./logger');

function _toStringData(payload = {}) {
  const data = {};
  Object.entries(payload).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    data[key] = String(value);
  });
  return data;
}

async function sendUserNotification({
  recipientUid,
  title,
  body,
  type,
  action,
  targetId,
  senderUid,
  senderName,
  senderPhotoUrl,
  groupingKey,
  extraData = {},
}) {
  const actionStatus =
    type === 'friend_request' || type === 'board_invite' ? 'pending' : 'info';

  const firestore = admin.firestore();

  const userRef = firestore.collection(FirestorePaths.USERS).doc(recipientUid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new Error('Recipient user not found.');
  }

  const userData = userDoc.data() || {};
  const tokenCandidates = [];

  if (typeof userData[FirestorePaths.FCM_TOKEN] === 'string') {
    tokenCandidates.push(userData[FirestorePaths.FCM_TOKEN]);
  }

  if (Array.isArray(userData[FirestorePaths.FCM_TOKENS])) {
    tokenCandidates.push(...userData[FirestorePaths.FCM_TOKENS]);
  }

  const tokens = [...new Set(tokenCandidates.filter((token) => !!token))];

  const notificationPayload = {
    recipientUid,
    [FirestorePaths.TYPE]: type,
    [FirestorePaths.TITLE]: title,
    [FirestorePaths.BODY]: body,
    [FirestorePaths.ACTION]: action || null,
    [FirestorePaths.TARGET_ID]: targetId || null,
    [FirestorePaths.FROM_UID]: senderUid || null,
    [FirestorePaths.SENDER_NAME]: senderName || null,
    [FirestorePaths.SENDER_PIC]: senderPhotoUrl || null,
    [FirestorePaths.GROUPING_KEY]: groupingKey || null,
    [FirestorePaths.STATUS]: actionStatus,
    extraData,
    [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
  };

  const notificationRef = await userRef
    .collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION)
    .add(notificationPayload);

  if (tokens.length === 0) {
    logger.warn('No FCM tokens found for recipient', { recipientUid });
    return { notificationId: notificationRef.id, deliveredToTokens: 0 };
  }

  const data = _toStringData({
    recipientUid,
    type,
    action,
    targetId,
    senderUid,
    senderName,
    senderPhotoUrl,
    notificationId: notificationRef.id,
    groupingKey,
    ...extraData,
  });

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data,
  });

  logger.info('Notification sent', {
    recipientUid,
    deliveredCount: response.successCount,
    attemptedCount: tokens.length,
    notificationId: notificationRef.id,
    type,
  });

  return {
    notificationId: notificationRef.id,
    deliveredToTokens: response.successCount,
  };
}

async function updateUserNotificationStatus({
  recipientUid,
  type,
  targetId,
  status,
  title,
  body,
}) {
  if (!recipientUid || !type || !targetId || !status) {
    return 0;
  }

  const firestore = admin.firestore();
  const snapshot = await firestore
    .collection(FirestorePaths.USERS)
    .doc(recipientUid)
    .collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION)
    .where(FirestorePaths.TYPE, '==', type)
    .where(FirestorePaths.TARGET_ID, '==', targetId)
    .get();

  if (snapshot.empty) {
    return 0;
  }

  const batch = firestore.batch();
  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      [FirestorePaths.STATUS]: status,
      ...(title ? { [FirestorePaths.TITLE]: title } : {}),
      ...(body ? { [FirestorePaths.BODY]: body } : {}),
      [FirestorePaths.ACTION]: null,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return snapshot.docs.length;
}

module.exports = {
  sendUserNotification,
  updateUserNotificationStatus,
};
