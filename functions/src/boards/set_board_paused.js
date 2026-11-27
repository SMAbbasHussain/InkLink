const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { publishBoardEvent } = require('../utils/redis');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { boardId, isPaused } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }

    if (typeof isPaused !== 'boolean') {
      throw new HttpsError('invalid-argument', 'isPaused must be a boolean.');
    }

    const resolvedBoardId = boardId.trim();
    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(resolvedBoardId);

    await firestore.runTransaction(async (transaction) => {
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const boardData = boardDoc.data() || {};
      if (boardData.ownerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Only the board owner can pause or resume this board.',
        );
      }

      transaction.update(boardRef, {
        isPaused,
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    publishBoardEvent({
      type: 'board_paused_changed',
      boardId: resolvedBoardId,
      isPaused,
    }).catch(() => {});

    return {
      success: true,
      boardId: resolvedBoardId,
      isPaused,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('setBoardPaused failed', {
      uid,
      boardId,
      error: error?.message || String(error),
    });
    throw new HttpsError('internal', 'Failed to update board pause state.');
  }
};
