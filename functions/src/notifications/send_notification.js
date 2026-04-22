const { HttpsError } = require('firebase-functions/v2/https');
const { validateUID, validateString } = require('../utils/validation');
const { sendUserNotification } = require('../utils/notification_sender');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;

  try {
    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const {
      recipientUid,
      title,
      body,
      type,
      action,
      targetId,
      senderName,
      senderPhotoUrl,
      groupingKey,
      extraData,
    } = data;

    validateUID(recipientUid, 'recipientUid');
    validateString(title, 'title');
    validateString(body, 'body');
    validateString(type, 'type');

    const result = await sendUserNotification({
      recipientUid,
      title,
      body,
      type,
      action,
      targetId,
      senderUid: auth.uid,
      senderName,
      senderPhotoUrl,
      groupingKey,
      extraData,
    });

    return { success: true, ...result };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('sendNotification failed', error);
    throw new HttpsError('internal', 'Failed to send notification.');
  }
};
