const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateDifferentUIDs } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;
  const reporterUid = auth?.uid;

  try {
    if (!reporterUid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { targetUid, reason } = data;
    validateUID(targetUid, 'targetUid');
    validateDifferentUIDs(reporterUid, targetUid);

    const firestore = admin.firestore();
    const reportRef = firestore.collection(FirestorePaths.USER_REPORTS).doc();

    await reportRef.set({
      reporterUid,
      targetUid,
      reason: typeof reason === 'string' && reason.trim().length > 0 ? reason.trim() : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'open',
    });

    logger.info('User reported successfully', {
      uid: reporterUid,
      targetUid,
      reportId: reportRef.id,
    });

    return {
      success: true,
      message: 'Report submitted successfully.',
      reportId: reportRef.id,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('reportUser failed', error);
    throw new HttpsError('internal', 'Failed to submit report.');
  }
};