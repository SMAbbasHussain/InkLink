const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { boardId, targetUid } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }
    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }
    if (typeof targetUid !== 'string' || targetUid.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'targetUid is required.');
    }

    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId.trim());
    const targetUserRef = firestore.collection(FirestorePaths.USERS).doc(targetUid.trim());

    return await firestore.runTransaction(async (transaction) => {
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const boardData = boardDoc.data() || {};
      if (boardData.ownerId !== uid) {
        throw new HttpsError('permission-denied', 'Only the board owner can remove members.');
      }

      if (boardData.ownerId === targetUid) {
        throw new HttpsError('invalid-argument', 'Cannot remove the board owner.');
      }

      const members = Array.isArray(boardData.members) ? boardData.members : [];
      if (!members.includes(targetUid)) {
        throw new HttpsError('not-found', 'User is not a member of this board.');
      }

      transaction.update(boardRef, {
        members: admin.firestore.FieldValue.arrayRemove(targetUid.trim()),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const memberRef = boardRef
        .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
        .doc(targetUid.trim());
      transaction.delete(memberRef);

      transaction.set(
        targetUserRef,
        {
          joinedBoards: admin.firestore.FieldValue.arrayRemove(boardId.trim()),
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: true,
        boardId: boardId.trim(),
        targetUid: targetUid.trim(),
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('removeBoardMember failed', error);
    throw new HttpsError('internal', 'Failed to remove board member.');
  }
};
