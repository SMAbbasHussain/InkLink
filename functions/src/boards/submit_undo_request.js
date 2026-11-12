const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { sendUserNotification } = require('../utils/notification_sender');

const ROLE_OWNER = 'owner';
const ROLE_EDITOR = 'editor';
const MAX_ELEMENTS = 200;
const MAX_REASON_LENGTH = 1000;

function parseOptionalDate(value, fieldName) {
  if (value === undefined || value === null || value === '') return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError('invalid-argument', `${fieldName} must be an ISO date string.`);
  }
  return date;
}

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const {
    boardId,
    targetElementIds,
    reason,
    timeRangeStart,
    timeRangeEnd,
  } = request.data || {};

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }
    if (typeof boardId !== 'string' || boardId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }
    if (!Array.isArray(targetElementIds) || targetElementIds.length === 0) {
      throw new HttpsError('invalid-argument', 'Select at least one element to undo.');
    }
    const elementIds = [...new Set(
      targetElementIds
        .filter(id => typeof id === 'string' && id.trim().length > 0)
        .map(id => id.trim()),
    )];
    if (elementIds.length === 0) {
      throw new HttpsError('invalid-argument', 'targetElementIds must contain element ids.');
    }
    if (elementIds.length > MAX_ELEMENTS) {
      throw new HttpsError('invalid-argument', `Select at most ${MAX_ELEMENTS} elements.`);
    }
    if (typeof reason !== 'string' || reason.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'A reason is required.');
    }
    if (reason.trim().length > MAX_REASON_LENGTH) {
      throw new HttpsError('invalid-argument', 'Reason is too long.');
    }

    const rangeStart = parseOptionalDate(timeRangeStart, 'timeRangeStart');
    const rangeEnd = parseOptionalDate(timeRangeEnd, 'timeRangeEnd');

    const firestore = admin.firestore();
    const cleanBoardId = boardId.trim();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(cleanBoardId);
    const boardDoc = await boardRef.get();

    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const boardData = boardDoc.data() || {};
    const ownerId = boardData.ownerId;
    const boardTitle = boardData.title || 'Untitled Board';

    // Requester must be able to edit this board (owner or editor).
    const members = Array.isArray(boardData.members) ? boardData.members : [];
    const memberDoc = await boardRef
      .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
      .doc(uid)
      .get();
    const memberData = memberDoc.data() || {};
    const isOwner = ownerId === uid;
    const canEdit = isOwner
      || memberData.role === ROLE_EDITOR
      || memberData.role === ROLE_OWNER
      || (members.includes(uid) && memberData.role !== 'viewer');
    if (!canEdit) {
      throw new HttpsError(
        'permission-denied',
        'Only board editors can request an undo.',
      );
    }

    // Idempotency: one pending request per board per user.
    const pendingSnap = await firestore
      .collection(FirestorePaths.BOARDS)
      .doc(cleanBoardId)
      .collection('undo_requests')
      .where('requesterUid', '==', uid)
      .where('status', '==', 'pending')
      .get();
    if (!pendingSnap.empty) {
      const existing = pendingSnap.docs[0];
      throw new HttpsError(
        'failed-precondition',
        'You already have a pending undo request on this board.',
        { requestId: existing.id },
      );
    }

    const userDoc = await firestore.collection(FirestorePaths.USERS).doc(uid).get();
    const userData = userDoc.data() || {};
    const requesterName = userData.displayName || 'An InkLink user';
    const requesterPhotoUrl = userData.photoURL || null;

    const requestRef = firestore
      .collection(FirestorePaths.BOARDS)
      .doc(cleanBoardId)
      .collection('undo_requests')
      .doc();

    await requestRef.set({
      requestId: requestRef.id,
      boardId: cleanBoardId,
      requesterUid: uid,
      requesterName,
      requesterPhotoUrl,
      targetElementIds: elementIds,
      timeRangeStart: rangeStart
        ? admin.firestore.Timestamp.fromDate(rangeStart)
        : null,
      timeRangeEnd: rangeEnd
        ? admin.firestore.Timestamp.fromDate(rangeEnd)
        : null,
      reason: reason.trim(),
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedAt: null,
      resolvedBy: null,
      resolutionNote: null,
      appliedVersion: null,
    });

    if (ownerId && ownerId !== uid) {
      try {
        await sendUserNotification({
          recipientUid: ownerId,
          type: 'undo_request',
          title: 'Undo request',
          body: `${requesterName} wants you to undo their edits on "${boardTitle}".`,
          action: 'view_board',
          targetId: cleanBoardId,
          senderUid: uid,
          senderName: requesterName,
          senderPhotoUrl: requesterPhotoUrl,
          groupingKey: `undo_request:${cleanBoardId}:${uid}`,
          extraData: {
            boardId: cleanBoardId,
            requestId: requestRef.id,
            requesterUid: uid,
            requesterName,
            elementCount: elementIds.length,
            reason: reason.trim(),
          },
        });
      } catch (notifyError) {
        logger.warn('submitUndoRequest: owner notification failed', {
          boardId: cleanBoardId,
          errorMessage: notifyError.message,
        });
      }
    }

    logger.info('Undo request submitted', { uid, boardId: cleanBoardId, requestId: requestRef.id });
    return { success: true, requestId: requestRef.id };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('submitUndoRequest failed', error);
    throw new HttpsError('internal', 'Failed to submit the undo request.');
  }
};
