const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
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
  const uid = request.auth?.uid;
  const boardId = request.data?.boardId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }

    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId.trim());

    const result = await firestore.runTransaction(async (transaction) => {
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const board = boardDoc.data() || {};
      if (board.ownerId !== uid) {
        throw new HttpsError('permission-denied', 'Only the board owner can delete this board.');
      }

      const members = Array.isArray(board.members) ? [...new Set(board.members)] : [];
      const ownerRef = firestore.collection(FirestorePaths.USERS).doc(uid);
      const ownerDoc = await transaction.get(ownerRef);
      const ownerCount = toNonNegativeInt(ownerDoc.data()?.[FirestorePaths.BOARD_COUNT]);

      transaction.delete(boardRef);

      transaction.set(ownerRef, {
        [FirestorePaths.BOARD_COUNT]: Math.max(0, ownerCount - 1),
        [FirestorePaths.OWNED_BOARDS]: admin.firestore.FieldValue.arrayRemove([boardId.trim()]),
        [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayRemove([boardId.trim()]),
        [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      for (const memberUid of members) {
        if (typeof memberUid !== 'string' || memberUid.trim().length === 0) {
          continue;
        }

        transaction.set(
          firestore.collection(FirestorePaths.USERS).doc(memberUid.trim()),
          {
            [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayRemove([boardId.trim()]),
            [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      return {
        success: true,
        boardId: boardId.trim(),
        removedMembers: members.length,
      };
    });

    logger.info('Board deleted successfully', {
      uid,
      boardId: boardId.trim(),
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('deleteBoard failed', error);
    throw new HttpsError('internal', 'Failed to delete board.');
  }
};