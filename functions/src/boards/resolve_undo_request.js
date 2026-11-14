const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const {
  sendUserNotification,
  updateUserNotificationStatus,
} = require('../utils/notification_sender');

const MAX_NOTE_LENGTH = 1000;

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const {
    boardId,
    requestId,
    status,
    note,
    appliedVersion,
  } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }
    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }
    if (typeof requestId !== 'string' || requestId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'requestId is required.');
    }
    if (status !== 'approved' && status !== 'denied') {
      throw new HttpsError('invalid-argument', 'status must be "approved" or "denied".');
    }
    const cleanNote = typeof note === 'string' ? note.trim() : '';
    if (cleanNote.length > MAX_NOTE_LENGTH) {
      throw new HttpsError('invalid-argument', 'Note is too long.');
    }
    // `Number(null)` is 0, so check presence first: a denial (or any resolution
    // without an applied version) must stay null rather than claiming version 0.
    const hasAppliedVersion = appliedVersion !== undefined
      && appliedVersion !== null
      && appliedVersion !== '';
    const cleanAppliedVersion = hasAppliedVersion
      && Number.isFinite(Number(appliedVersion))
      ? Math.trunc(Number(appliedVersion))
      : null;

    const firestore = admin.firestore();
    const cleanBoardId = boardId.trim();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(cleanBoardId);
    const boardDoc = await boardRef.get();
    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const boardData = boardDoc.data() || {};
    if (boardData.ownerId !== uid) {
      throw new HttpsError(
        'permission-denied',
        'Only the board owner can resolve undo requests.',
      );
    }
    const boardTitle = boardData.title || 'Board';

    const requestRef = boardRef
      .collection('undo_requests')
      .doc(requestId.trim());
    const requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw new HttpsError('not-found', 'Undo request not found.');
    }

    const requestData = requestDoc.data() || {};
    if (requestData.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'This request is already resolved.');
    }

    await requestRef.update({
      status,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: uid,
      resolutionNote: cleanNote || null,
      appliedVersion: cleanAppliedVersion,
    });

    try {
      await updateUserNotificationStatus({
        recipientUid: uid,
        type: 'undo_request',
        targetId: cleanBoardId,
        status: status === 'approved' ? 'accepted' : 'declined',
      });
    } catch (notifyError) {
      logger.warn('resolveUndoRequest: owner notification update failed', {
        boardId: cleanBoardId,
        errorMessage: notifyError.message,
      });
    }

    const requesterUid = requestData.requesterUid;
    if (requesterUid) {
      try {
        await sendUserNotification({
          recipientUid: requesterUid,
          type: status === 'approved' ? 'undo_request_approved' : 'undo_request_denied',
          title: status === 'approved' ? 'Undo request approved' : 'Undo request declined',
          body: status === 'approved'
            ? `The owner undid your edits on "${boardTitle}".`
            : `The owner declined your undo request on "${boardTitle}".`,
          action: 'open_board',
          targetId: cleanBoardId,
          senderName: 'Board Owner',
          extraData: {
            boardId: cleanBoardId,
            requestId: requestRef.id,
            note: cleanNote || null,
            appliedVersion: cleanAppliedVersion,
          },
        });
      } catch (notifyError) {
        logger.warn('resolveUndoRequest: requester notification failed', {
          boardId: cleanBoardId,
          errorMessage: notifyError.message,
        });
      }
    }

    logger.info('Undo request resolved', {
      uid,
      boardId: cleanBoardId,
      requestId: requestRef.id,
      status,
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('resolveUndoRequest failed', error);
    throw new HttpsError('internal', 'Failed to resolve the undo request.');
  }
};
