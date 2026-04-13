const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

const VISIBILITY_PUBLIC = 'public';
const VISIBILITY_PRIVATE = 'private';
const POLICY_OWNER_ONLY = 'owner_only_invite';
const POLICY_LINK_CAN_JOIN = 'link_can_join';

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const joinCodeRaw = request.data?.joinCode;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Please sign in to join a board.');
    }

    if (typeof joinCodeRaw !== 'string' || joinCodeRaw.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'joinCode is required.');
    }

    const joinCode = joinCodeRaw.trim();
    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(joinCode);
    const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);

    return await firestore.runTransaction(async (transaction) => {
          const boardDoc = await transaction.get(boardRef);
          if (!boardDoc.exists) {
            throw new HttpsError('not-found', 'Board not found. Check the join code and try again.');
          }
    
          const boardData = boardDoc.data() || {};
          const {ownerId} = boardData;
          const members = Array.isArray(boardData.members) ? boardData.members : [];
          const visibility = boardData[FirestorePaths.VISIBILITY] || VISIBILITY_PRIVATE;
          const privatePolicy =
            boardData[FirestorePaths.PRIVATE_JOIN_POLICY] || POLICY_OWNER_ONLY;
          const joinViaCodeEnabled =
            typeof boardData[FirestorePaths.JOIN_VIA_CODE_ENABLED] === 'boolean'
              ? boardData[FirestorePaths.JOIN_VIA_CODE_ENABLED]
              : (visibility === VISIBILITY_PUBLIC || privatePolicy === POLICY_LINK_CAN_JOIN);
    
          if (ownerId === uid || members.includes(uid)) {
            const userBoardUpdate = ownerId === uid
              ? {
                  joinedBoards: admin.firestore.FieldValue.arrayRemove(joinCode),
                  ownedBoards: admin.firestore.FieldValue.arrayUnion(joinCode),
                  lastActive: admin.firestore.FieldValue.serverTimestamp(),
                }
              : {
                  joinedBoards: admin.firestore.FieldValue.arrayUnion(joinCode),
                  ownedBoards: admin.firestore.FieldValue.arrayRemove(joinCode),
                  lastActive: admin.firestore.FieldValue.serverTimestamp(),
                };
    
            transaction.set(
              userRef,
              userBoardUpdate,
              { merge: true },
            );
    
            return {
              success: true,
              boardId: joinCode,
              alreadyMember: true,
            };
          }
    
          const canJoin =
            visibility === VISIBILITY_PUBLIC ||
            (visibility === VISIBILITY_PRIVATE &&
              privatePolicy === POLICY_LINK_CAN_JOIN &&
              joinViaCodeEnabled === true);
    
          if (!canJoin) {
            throw new HttpsError(
              'failed-precondition',
              'This private board only allows owner invites.',
            );
          }
    
          transaction.update(boardRef, {
            members: admin.firestore.FieldValue.arrayUnion(uid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
    
          transaction.set(
            userRef,
            {
              joinedBoards: admin.firestore.FieldValue.arrayUnion(joinCode),
              ownedBoards: admin.firestore.FieldValue.arrayRemove(joinCode),
              lastActive: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
    
          return {
            success: true,
            boardId: joinCode,
          };
        });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('joinBoardByCode failed', error);
    throw new HttpsError('internal', 'Failed to join board. Please try again.');
  }
};
