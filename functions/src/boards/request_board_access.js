const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { sendUserNotification } = require('../utils/notification_sender');

const ROLE_OWNER = 'owner';
const ROLE_EDITOR = 'editor';

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const { boardId, requestType, message } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }
    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }

    const normalizedType =
      typeof requestType === 'string' ? requestType.trim().toLowerCase() : 'join';
    if (normalizedType !== 'join' && normalizedType !== 'edit') {
      throw new HttpsError('invalid-argument', 'requestType must be "join" or "edit".');
    }

    const firestore = admin.firestore();
    const cleanBoardId = boardId.trim();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(cleanBoardId);
    const boardDoc = await boardRef.get();

    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const boardData = boardDoc.data() || {};
    const { ownerId } = boardData;
    const boardTitle = boardData.title || 'Untitled Board';

    if (ownerId === uid) {
      throw new HttpsError('failed-precondition', 'You are already the owner of this board.');
    }

    const members = Array.isArray(boardData.members) ? boardData.members : [];
    const memberRef = boardRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(uid);
    const memberDoc = await memberRef.get();
    const memberData = memberDoc.data() || {};
    const isMember =
      members.includes(uid) || (memberDoc.exists && memberData.status === 'active');

    if (normalizedType === 'join') {
      if (isMember) {
        return {
          success: true,
          alreadyMember: true,
          message: 'You are already a member of this board.',
        };
      }
    } else if (normalizedType === 'edit') {
      if (memberData.role === ROLE_EDITOR || memberData.role === ROLE_OWNER) {
        return {
          success: true,
          alreadyEditor: true,
          message: 'You already have edit permissions on this board.',
        };
      }
    }

    // Get requester profile info
    const senderDoc = await firestore
      .collection(FirestorePaths.USERS)
      .doc(uid)
      .get();
    const senderData = senderDoc.data() || {};
    const senderName = senderData.displayName || 'An InkLink user';
    const senderPhotoUrl = senderData.photoURL || null;

    const notifTitle =
      normalizedType === 'edit' ? 'Edit Access Request' : 'Board Join Request';
    const notifBody =
      normalizedType === 'edit'
        ? `${senderName} requested edit access to "${boardTitle}".`
        : `${senderName} requested access to join "${boardTitle}".`;

    await sendUserNotification({
      recipientUid: ownerId,
      title: notifTitle,
      body: notifBody,
      type:
        normalizedType === 'edit'
          ? 'board_edit_request'
          : 'board_access_request',
      action: 'view_board',
      targetId: cleanBoardId,
      senderUid: uid,
      senderName,
      senderPhotoUrl,
      groupingKey: `board_${normalizedType}_request:${cleanBoardId}:${uid}`,
      extraData: {
        boardId: cleanBoardId,
        boardTitle,
        requestType: normalizedType,
        requesterUid: uid,
        requesterName: senderName,
        message: typeof message === 'string' ? message.trim() : '',
      },
    });

    return {
      success: true,
      message:
        normalizedType === 'edit'
          ? 'Edit access request sent to board owner.'
          : 'Join request sent to board owner.',
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('requestBoardAccess failed', error);
    throw new HttpsError('internal', 'Failed to send request.');
  }
};
