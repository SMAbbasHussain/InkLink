const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

const ROLE_EDITOR = 'editor';
const ROLE_VIEWER = 'viewer';

function normalizeRole(role, fallback = ROLE_VIEWER) {
  if (typeof role !== 'string') return fallback;
  const normalized = role.trim().toLowerCase();
  if (normalized === ROLE_EDITOR || normalized === ROLE_VIEWER) {
    return normalized;
  }
  return fallback;
}

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { boardId, targetUid, role } = request.data || {};

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

    const newRole = normalizeRole(role);
    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId.trim());

    return await firestore.runTransaction(async (transaction) => {
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const boardData = boardDoc.data() || {};
      if (boardData.ownerId !== uid) {
        throw new HttpsError('permission-denied', 'Only the board owner can change member roles.');
      }

      if (boardData.ownerId === targetUid) {
        throw new HttpsError('invalid-argument', 'Cannot change the role of the board owner.');
      }

      const members = Array.isArray(boardData.members) ? boardData.members : [];
      if (!members.includes(targetUid)) {
        throw new HttpsError('not-found', 'User is not a member of this board.');
      }

      const memberRef = boardRef
        .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
        .doc(targetUid.trim());
        
      transaction.set(
        memberRef,
        {
          role: newRole,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      transaction.update(boardRef, {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        boardId: boardId.trim(),
        targetUid: targetUid.trim(),
        role: newRole,
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('updateBoardMemberRole failed', error);
    throw new HttpsError('internal', 'Failed to update member role.');
  }
};
