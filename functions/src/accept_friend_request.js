/**
 * Cloud Function: Accept Friend Request
 * 
 * Accepts a friend request and creates bidirectional friendship documents.
 * Uses Firestore transactions to ensure atomicity.
 * 
 * @param {object} request - The callable request object
 * @param {object} request.auth - Authentication context {uid, token, ...}
 * @param {object} request.data - Request data {requestId}
 * @returns {object} {success: true, message: string}
 * @throws {HttpsError} Various validation and execution errors
 */

const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("../server/firebase-admin");
const { validateRequestId, validateUID, validateDifferentUIDs } = require("./utils/validation");
const FirestorePaths = require("./utils/firestore_paths");
const logger = require("./utils/logger");

module.exports = async (request) => {
  const { data, auth } = request;
  const uid = auth?.uid;

  try {
    // FIX: Validate authentication
    if (!auth) {
      logger.warn('Accept friend request: Missing authentication');
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!uid) {
      logger.warn('Accept friend request: Invalid auth object');
      throw new HttpsError('unauthenticated', 'Invalid authentication.');
    }

    // FIX: Validate input data
    if (!data) {
      logger.warn('Accept friend request: Missing request data', { uid });
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { requestId } = data;

    // FIX: Comprehensive input validation
    try {
      validateRequestId(requestId);
    } catch (validationError) {
      logger.warn('Accept friend request: Invalid requestId', { 
        requestId, 
        uid,
        error: validationError.message 
      });
      throw new HttpsError('invalid-argument', `Invalid request ID: ${validationError.message}`);
    }

    logger.debug('Processing friend request acceptance', {
      requestId,
      uid
    });

    const firestore = admin.firestore();

    // FIX: Use transaction for atomicity and race condition prevention
    const result = await firestore.runTransaction(async (transaction) => {
      const requestRef = firestore.collection(FirestorePaths.FRIEND_REQUESTS).doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      // Check request exists
      if (!requestDoc.exists) {
        logger.warn('Accept friend request: Request not found', {
          requestId,
          uid
        });
        throw new HttpsError('not-found', 'Friend request not found.');
      }

      const requestData = requestDoc.data();
      const fromUid = requestData?.[FirestorePaths.FROM_UID];
      const toUid = requestData?.[FirestorePaths.TO_UID];

      // FIX: Validate request data integrity
      try {
        validateUID(fromUid, 'fromUid');
        validateUID(toUid, 'toUid');
        validateDifferentUIDs(fromUid, toUid);
      } catch (validationError) {
        logger.error('Accept friend request: Invalid request document structure', {
          requestId,
          requestData,
          error: validationError.message
        });
        throw new HttpsError('internal', 'Request document is corrupted.');
      }

      // FIX: Verify the current user is the recipient
      if (uid !== toUid) {
        logger.warn('Accept friend request: Unauthorized access attempt', {
          requestId,
          requestedToUid: toUid,
          attemptedBy: uid
        });
        throw new HttpsError('permission-denied', 'You can only accept requests sent to you.');
      }

      // FIX: Check if users still exist (prevents orphaned friendships)
      const senderRef = firestore.collection(FirestorePaths.USERS).doc(fromUid);
      const senderDoc = await transaction.get(senderRef);
      if (!senderDoc.exists) {
        logger.warn('Accept friend request: Sender account not found', {
          requestId,
          fromUid,
          toUid
        });
        throw new HttpsError('not-found', 'Sender account no longer exists.');
      }

      const recipientRef = firestore.collection(FirestorePaths.USERS).doc(toUid);
      const recipientDoc = await transaction.get(recipientRef);
      if (!recipientDoc.exists) {
        logger.warn('Accept friend request: Recipient account not found', {
          requestId,
          fromUid,
          toUid
        });
        throw new HttpsError('not-found', 'Recipient account no longer exists.');
      }

      // FIX: Check for idempotency - prevent accepting if already friends
      const existingFriendshipRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(toUid)
        .collection(FirestorePaths.FRIENDS_SUBCOLLECTION)
        .doc(fromUid);
      
      const existingFriendship = await transaction.get(existingFriendshipRef);
      if (existingFriendship.exists) {
        logger.info('Accept friend request: Users already friends (idempotent call)', {
          requestId,
          fromUid,
          toUid
        });
        // Delete the request and return success (idempotent)
        transaction.delete(requestRef);
        return { success: true, message: 'Already friends.' };
      }

      // Create friendship documents with only UID and timestamp
      // Profile data stays in /users collection to avoid duplication
      const friendshipData = {
        [FirestorePaths.UID]: null, // Will be set to the friend's UID in next lines
        [FirestorePaths.SINCE]: admin.firestore.FieldValue.serverTimestamp()
      };

      // Recipient's view: friend is fromUid
      const recipientFriendData = { ...friendshipData };
      recipientFriendData[FirestorePaths.UID] = fromUid;
      transaction.set(existingFriendshipRef, recipientFriendData);

      // Sender's view: friend is toUid
      const senderFriendRef = firestore
        .collection(FirestorePaths.USERS)
        .doc(fromUid)
        .collection(FirestorePaths.FRIENDS_SUBCOLLECTION)
        .doc(toUid);
      
      const senderFriendData = { ...friendshipData };
      senderFriendData[FirestorePaths.UID] = toUid;
      transaction.set(senderFriendRef, senderFriendData);

      // Delete the request
      transaction.delete(requestRef);

      return { 
        success: true, 
        message: 'Friend request accepted successfully.' 
      };
    });

    logger.info('Friend request accepted successfully', {
      requestId,
      uid,
      timestamp: new Date().toISOString()
    });

    return result;

  } catch (error) {
    // FIX: Better error handling with proper logging
    if (error instanceof HttpsError) {
      // Already properly formatted error
      throw error;
    }

    // Unexpected errors
    logger.error('Accept friend request failed with unexpected error', {
      error: error instanceof Error ? error.message : String(error),
      uid: auth?.uid,
      stack: error instanceof Error ? error.stack : undefined
    });

    throw new HttpsError(
      'internal',
      'Failed to accept friend request. Please try again later.'
    );
  }
};
