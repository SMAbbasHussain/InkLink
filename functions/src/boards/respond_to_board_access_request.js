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

    const cleanAction =
      typeof action === 'string' ? action.trim().toLowerCase() : 'decline';
    const cleanType =
      typeof requestType === 'string' ? requestType.trim().toLowerCase() : 'join';

    const firestore = admin.firestore();
    const cleanBoardId = boardId.trim();
    const cleanRequesterUid = requesterUid.trim();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(cleanBoardId);
    const requesterRef = firestore.collection(FirestorePaths.USERS).doc(cleanRequesterUid);
    const memberRef = boardRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(cleanRequesterUid);

    const boardDoc = await boardRef.get();
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

    if (cleanAction === 'accept') {
      const batch = firestore.batch();

      if (cleanType === 'join') {
        // Add member as viewer
        batch.update(boardRef, {
          members: admin.firestore.FieldValue.arrayUnion(cleanRequesterUid),
          [FirestorePaths.MEMBER_COUNT]: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batch.set(
          memberRef,
          {
            uid: cleanRequesterUid,
            role: ROLE_VIEWER,
            status: 'active',
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        // Add to requester's user board index doc
        const userBoardRef = requesterRef
          .collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION)
          .doc(cleanBoardId);
        batch.set(
          userBoardRef,
          {
            boardId: cleanBoardId,
            relation: 'joined',
            addedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        batch.set(
          requesterRef,
          {
            [FirestorePaths.BOARD_COUNT]: admin.firestore.FieldValue.increment(1),
          },
          { merge: true },
        );
      } else if (cleanType === 'edit') {
        // Promote member to editor
        batch.update(boardRef, {
          members: admin.firestore.FieldValue.arrayUnion(cleanRequesterUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batch.set(
          memberRef,
          {
            uid: cleanRequesterUid,
            role: ROLE_EDITOR,
            status: 'active',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      // Mark owner notification as accepted if notificationId is provided
      if (typeof notificationId === 'string' && notificationId.trim().length > 0) {
        const notifRef = firestore
          .collection(FirestorePaths.USERS)
          .doc(uid)
          .collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION)
          .doc(notificationId.trim());
        batch.update(notifRef, {
          [FirestorePaths.STATUS]: 'accepted',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Notify requester that request was accepted
      await sendUserNotification({
        recipientUid: cleanRequesterUid,
        title:
          cleanType === 'edit'
            ? 'Edit Access Granted'
            : 'Board Access Granted',
        body:
          cleanType === 'edit'
            ? `You can now edit "${boardTitle}".`
            : `You have been added to "${boardTitle}".`,
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
          boardTitle,
          status: 'accepted',
        },
      });

      return { success: true, action: 'accepted' };
    } else {
      // Declined
      if (typeof notificationId === 'string' && notificationId.trim().length > 0) {
        const notifRef = firestore
          .collection(FirestorePaths.USERS)
          .doc(uid)
          .collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION)
          .doc(notificationId.trim());
        await notifRef.update({
          [FirestorePaths.STATUS]: 'declined',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Notify requester that request was declined
      await sendUserNotification({
        recipientUid: cleanRequesterUid,
        title:
          cleanType === 'edit'
            ? 'Edit Request Declined'
            : 'Join Request Declined',
        body: `Your request for "${boardTitle}" was declined.`,
        type: 'board_access_declined',
        targetId: cleanBoardId,
        senderUid: uid,
        senderName: 'Board Owner',
        extraData: {
          boardId: cleanBoardId,
          boardTitle,
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
