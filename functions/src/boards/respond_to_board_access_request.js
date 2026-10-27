const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { sendUserNotification } = require('../utils/notification_sender');

const ROLE_EDITOR = 'editor';
const ROLE_VIEWER = 'viewer';

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { boardId, requesterUid, notificationId, action, requestType } =
    request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }
    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }
    if (typeof requesterUid !== 'string' || requesterUid.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'requesterUid is required.');
    }

    if (typeof action !== 'string' || action.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'action is required.');
    }
    const cleanAction = action.trim().toLowerCase();
    if (cleanAction !== 'accept' && cleanAction !== 'decline') {
      throw new HttpsError(
        'invalid-argument',
        'action must be either "accept" or "decline".',
      );
    }

    if (typeof requestType !== 'string' || requestType.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'requestType is required.');
    }
    const cleanType = requestType.trim().toLowerCase();
    if (cleanType !== 'join' && cleanType !== 'edit') {
      throw new HttpsError(
        'invalid-argument',
        'requestType must be either "join" or "edit".',
      );
    }

    const firestore = admin.firestore();
    const cleanBoardId = boardId.trim();
    const cleanRequesterUid = requesterUid.trim();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(cleanBoardId);
    const requesterRef = firestore.collection(FirestorePaths.USERS).doc(cleanRequesterUid);
    const memberRef = boardRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(cleanRequesterUid);
    const userBoardRef = requesterRef
      .collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION)
      .doc(cleanBoardId);

    const notifRef =
      typeof notificationId === 'string' && notificationId.trim().length > 0
        ? firestore
            .collection(FirestorePaths.USERS)
            .doc(uid)
            .collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION)
            .doc(notificationId.trim())
        : null;

    const result = await firestore.runTransaction(async (transaction) => {
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const boardData = boardDoc.data() || {};
      if (boardData.ownerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Only the board owner can approve access requests.',
        );
      }

      const boardTitle = boardData.title || 'Board';
      const members = Array.isArray(boardData.members) ? boardData.members : [];

      const memberDoc = await transaction.get(memberRef);
      const memberData = memberDoc.exists ? memberDoc.data() : null;
      const isAlreadyActiveMember =
        members.includes(cleanRequesterUid) ||
        (memberData && memberData.status === 'active');

      if (cleanAction === 'accept') {
        const boardUpdates = {
          members: admin.firestore.FieldValue.arrayUnion(cleanRequesterUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Avoid incrementing the member count when the requester is already a member
        if (!isAlreadyActiveMember) {
          boardUpdates[FirestorePaths.MEMBER_COUNT] =
            admin.firestore.FieldValue.increment(1);
        }

        transaction.update(boardRef, boardUpdates);

        if (cleanType === 'join') {
          // Add member as viewer
          transaction.set(
            memberRef,
            {
              uid: cleanRequesterUid,
              role: ROLE_VIEWER,
              status: 'active',
              joinedAt:
                memberData && memberData.joinedAt
                  ? memberData.joinedAt
                  : admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          // Add to requester's user board index doc
          transaction.set(
            userBoardRef,
            {
              boardId: cleanBoardId,
              relation: 'joined',
              addedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          if (!isAlreadyActiveMember) {
            transaction.set(
              requesterRef,
              {
                [FirestorePaths.BOARD_COUNT]:
                  admin.firestore.FieldValue.increment(1),
              },
              { merge: true },
            );
          }
        } else if (cleanType === 'edit') {
          // Promote member to editor
          transaction.set(
            memberRef,
            {
              uid: cleanRequesterUid,
              role: ROLE_EDITOR,
              status: 'active',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          transaction.set(
            userBoardRef,
            {
              boardId: cleanBoardId,
              relation: 'joined',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        // Mark owner notification as accepted if notificationId is provided
        if (notifRef) {
          transaction.update(notifRef, {
            [FirestorePaths.STATUS]: 'accepted',
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        return { action: 'accepted', boardTitle };
      } else {
        // Declined
        if (notifRef) {
          transaction.update(notifRef, {
            [FirestorePaths.STATUS]: 'declined',
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        return { action: 'declined', boardTitle };
      }
    });

    // Notify requester after transaction commits
    if (result.action === 'accepted') {
      await sendUserNotification({
        recipientUid: cleanRequesterUid,
        title:
          cleanType === 'edit'
            ? 'Edit Access Granted'
            : 'Board Access Granted',
        body:
          cleanType === 'edit'
            ? `You can now edit "${result.boardTitle}".`
            : `You have been added to "${result.boardTitle}".`,
        type:
          cleanType === 'edit'
            ? 'board_edit_accepted'
            : 'board_access_accepted',
        action: 'open_board',
        targetId: cleanBoardId,
        senderUid: uid,
        senderName: 'Board Owner',
        extraData: {
          boardId: cleanBoardId,
          boardTitle: result.boardTitle,
          status: 'accepted',
        },
      });

      return { success: true, action: 'accepted' };
    } else {
      await sendUserNotification({
        recipientUid: cleanRequesterUid,
        title:
          cleanType === 'edit'
            ? 'Edit Request Declined'
            : 'Join Request Declined',
        body: `Your request for "${result.boardTitle}" was declined.`,
        type: 'board_access_declined',
        targetId: cleanBoardId,
        senderUid: uid,
        senderName: 'Board Owner',
        extraData: {
          boardId: cleanBoardId,
          boardTitle: result.boardTitle,
          status: 'declined',
        },
      });

      return { success: true, action: 'declined' };
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('respondToBoardAccessRequest failed', error);
    throw new HttpsError('internal', 'Failed to respond to request.');
  }
};
