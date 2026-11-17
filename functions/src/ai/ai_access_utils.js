/**
 * Board edit-access check for the AI functions.
 *
 * Mirrors the realtime server's rule (server/src/index.js canUserAccessBoard
 * with requireEdit=true): the owner can edit; a user listed in the board's
 * `members` array can edit unless their member document has role "viewer".
 *
 * Ends in `_utils.js` so functions/index.js does not export it.
 */

const { HttpsError } = require('firebase-functions/v2/https');
const FirestorePaths = require('../utils/firestore_paths');

async function assertBoardEditAccess(firestore, boardId, uid) {
  const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
  const boardDoc = await boardRef.get();
  if (!boardDoc.exists) {
    throw new HttpsError('not-found', 'Board not found.');
  }

  const board = boardDoc.data() || {};
  if (board.ownerId === uid) {
    return { role: 'owner' };
  }

  const members = Array.isArray(board.members) ? board.members : [];
  if (!members.includes(uid)) {
    throw new HttpsError('permission-denied', 'You do not have access to this board.');
  }

  const memberDoc = await boardRef
    .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
    .doc(uid)
    .get();
  const role = memberDoc.exists ? memberDoc.data()?.role : undefined;
  if (role === 'viewer') {
    throw new HttpsError(
      'permission-denied',
      'Viewers cannot use AI images. Ask the board owner for edit access.',
    );
  }

  return { role: role || 'editor' };
}

module.exports = { assertBoardEditAccess };
