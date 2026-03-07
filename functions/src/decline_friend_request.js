/**
 * Cloud Function: Decline Friend Request
 * 
 * Declines a friend request by deleting it from Firestore.
 * Only the recipient can decline a request.
 * 
 * @param {object} request - The callable request object
 * @param {object} request.auth - Authentication context {uid, token, ...}
 * @param {object} request.data - Request data {requestId}
 * @returns {object} {success: true, message: string}
 * @throws {HttpsError} Various validation and execution errors
 */

const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("../server/firebase-admin");
const { validateRequestId, validateUID } = require("./utils/validation");
const FirestorePaths = require("./utils/firestore_paths");
const logger = require("./utils/logger");

module.exports = async (request) => {
  const { data, auth } = request;
  const uid = auth?.uid;

  try {
    // Validate authentication
    if (!auth || !uid) {
      logger.warn('Decline friend request: Missing authentication');
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      logger.warn('Decline friend request: Missing request data', { uid });
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { requestId } = data;

    // Validate input
    try {
      validateRequestId(requestId);
    } catch (validationError) {
      logger.warn('Decline friend request: Invalid requestId', {
        requestId,
        uid,
        error: validationError.message
      });
      throw new HttpsError('invalid-argument', `Invalid request ID: ${validationError.message}`);
    }

    logger.debug('Processing friend request decline', {
      requestId,
      uid
    });

    const firestore = admin.firestore();

    // Use transaction for safety
    const result = await firestore.runTransaction(async (transaction) => {
      const requestRef = firestore.collection(FirestorePaths.FRIEND_REQUESTS).doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      // Check request exists
      if (!requestDoc.exists) {
        logger.warn('Decline friend request: Request not found', {
          requestId,
          uid
        });
        throw new HttpsError('not-found', 'Friend request not found.');
      }

      const requestData = requestDoc.data();
      const toUid = requestData?.[FirestorePaths.TO_UID];

      // Validate that recipient is declining their own request
      try {
        validateUID(toUid, 'toUid');
      } catch (validationError) {
        logger.error('Decline friend request: Invalid request document', {
          requestId,
          requestData,
          error: validationError.message
        });
        throw new HttpsError('internal', 'Request document is corrupted.');
      }

      if (uid !== toUid) {
        logger.warn('Decline friend request: Unauthorized access attempt', {
          requestId,
          requestedToUid: toUid,
          attemptedBy: uid
        });
        throw new HttpsError('permission-denied', 'You can only decline requests sent to you.');
      }

      // Delete the request
      transaction.delete(requestRef);

      return {
        success: true,
        message: 'Friend request declined successfully.'
      };
    });

    logger.info('Friend request declined successfully', {
      requestId,
      uid,
      timestamp: new Date().toISOString()
    });

    return result;

  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('Decline friend request failed with unexpected error', {
      error: error instanceof Error ? error.message : String(error),
      uid: auth?.uid,
      stack: error instanceof Error ? error.stack : undefined
    });

    throw new HttpsError(
      'internal',
      'Failed to decline friend request. Please try again later.'
    );
  }
};
