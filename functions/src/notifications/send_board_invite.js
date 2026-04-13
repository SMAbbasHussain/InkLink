const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateString } = require('../utils/validation');
const FirestorePaths = require('../utils/firestore_paths');
const { sendUserNotification } = require('../utils/notification_sender');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;
  const senderUid = auth?.uid;

  try {
    if (!senderUid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!data) {
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const {
      boardId,
      boardTitle,
      invitedUserIds,
      inviteExpiryHours = 72,
    } = data;

    validateString(boardId, 'boardId');
    validateString(boardTitle, 'boardTitle');

    if (!Array.isArray(invitedUserIds) || invitedUserIds.length === 0) {
      throw new HttpsError(
        'invalid-argument',
        'invitedUserIds must be a non-empty array.',
      );
    }

    const firestore = admin.firestore();

    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
    const boardDoc = await boardRef.get();
    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const boardData = boardDoc.data() || {};
    if (boardData.ownerId !== senderUid) {
      throw new HttpsError(
        'permission-denied',
        'Only the board owner can send invites.',
      );
    }

    const senderDoc = await firestore
      .collection(FirestorePaths.USERS)
      .doc(senderUid)
      .get();
    const senderData = senderDoc.data() || {};

    const expiresAt = new Date(Date.now() + Number(inviteExpiryHours) * 3600000);
    const inviteIdentifiers = [...new Set(invitedUserIds)]
      .filter((value) => typeof value === 'string' && value.trim().length > 0)
      .map((value) => value.trim())
      .filter((value) => value !== senderUid);

    const resolvedRecipientUids = [];
    const unresolvedEmails = [];
    const unresolvedUids = [];
    for (const identifier of inviteIdentifiers) {
      if (identifier.includes('@')) {
        const normalizedEmail = identifier.toLowerCase();

        let userByEmail = await firestore
          .collection(FirestorePaths.USERS)
          .where(FirestorePaths.EMAIL, '==', normalizedEmail)
          .limit(1)
          .get();

        // Fallback for historical records that may not have lowercased emails.
        if (userByEmail.docs.isEmpty && identifier != normalizedEmail) {
          userByEmail = await firestore
            .collection(FirestorePaths.USERS)
            .where(FirestorePaths.EMAIL, '==', identifier)
            .limit(1)
            .get();
        }

        if (userByEmail.docs.isEmpty) {
          unresolvedEmails.push(identifier);
          continue;
        }

        resolvedRecipientUids.push(userByEmail.docs.first.id);
        continue;
      }

      const userDoc = await firestore
        .collection(FirestorePaths.USERS)
        .doc(identifier)
        .get();
      if (!userDoc.exists) {
        unresolvedUids.push(identifier);
        continue;
      }

      resolvedRecipientUids.push(identifier);
    }

    const uniqueInvitees = [...new Set(resolvedRecipientUids)]
      .filter((uid) => uid !== senderUid);

    const results = [];

    for (const recipientUid of uniqueInvitees) {
      validateUID(recipientUid, 'recipientUid');

      const inviteRef = firestore
        .collection(FirestorePaths.BOARD_INVITES)
        .doc(`${boardId}_${recipientUid}`);

      await inviteRef.set(
        {
          boardId,
          boardTitle,
          [FirestorePaths.FROM_UID]: senderUid,
          [FirestorePaths.TO_UID]: recipientUid,
          [FirestorePaths.SENDER_NAME]: senderData.displayName || 'InkLink User',
          [FirestorePaths.SENDER_PIC]: senderData.photoURL || null,
          [FirestorePaths.STATUS]: 'pending',
          [FirestorePaths.EXPIRES_AT]: admin.firestore.Timestamp.fromDate(expiresAt),
          [FirestorePaths.INVITE_EXPIRY_HOURS]: Number(inviteExpiryHours),
          [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const notificationResult = await sendUserNotification({
        recipientUid,
        title: `${senderData.displayName || 'Someone'} invited you to a board`,
        body: `Invitation to join \"${boardTitle}\"`,
        type: 'board_invite',
        action: 'open_invites',
        targetId: inviteRef.id,
        senderUid,
        senderName: senderData.displayName || 'InkLink User',
        senderPhotoUrl: senderData.photoURL || null,
        groupingKey: `board_invite:${senderUid}:${recipientUid}`,
        extraData: {
          boardId,
          boardTitle,
          inviteId: inviteRef.id,
        },
      });

      results.push({ recipientUid, ...notificationResult });
    }

    return {
      success: true,
      invitedCount: results.length,
      results,
      unresolvedEmails,
      unresolvedUids,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('sendBoardInvite failed', error);
    throw new HttpsError('internal', 'Failed to send board invites.');
  }
};
