const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateUID, validateString } = require('../utils/validation');
const { sendUserNotification } = require('../utils/notification_sender');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const { auth, data } = request;

  if (!auth?.uid) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  if (!data) {
    throw new HttpsError('invalid-argument', 'Request data is required.');
  }

  const { boardId, boardTitle, commentId, commentText, senderName, senderPhotoUrl } = data;

  validateString(boardId, 'boardId');
  validateString(commentText, 'commentText');

  const senderUid = auth.uid;
  const firestore = admin.firestore();

  // Extract all @mentions from commentText (e.g. @Alice, @john_doe)
  const mentionMatches = commentText.match(/@([a-zA-Z0-9_\.\-]+)/g) || [];
  if (mentionMatches.length === 0) {
    return { success: true, notifiedCount: 0 };
  }

  const mentionedNames = [...new Set(mentionMatches.map((m) => m.substring(1).toLowerCase()))];
  logger.info('Parsed mentions from comment', { boardId, commentId, mentionedNames });

  let notifiedCount = 0;

  for (const name of mentionedNames) {
    try {
      // Find user by displayName or username
      const snapshot = await firestore
        .collection(FirestorePaths.USERS)
        .where('displayNameLower', '==', name)
        .limit(1)
        .get();

      let targetUserDoc = !snapshot.empty ? snapshot.docs[0] : null;

      if (!targetUserDoc) {
        // Fallback search by username
        const byUsername = await firestore
          .collection(FirestorePaths.USERS)
          .where('username', '==', name)
          .limit(1)
          .get();
        if (!byUsername.empty) {
          targetUserDoc = byUsername.docs[0];
        }
      }

      if (!targetUserDoc) {
        // Fallback search by standard displayName
        const byDisplayName = await firestore
          .collection(FirestorePaths.USERS)
          .where('displayName', '==', name)
          .limit(1)
          .get();
        if (!byDisplayName.empty) {
          targetUserDoc = byDisplayName.docs[0];
        }
      }

      if (!targetUserDoc) {
        logger.debug('Mentioned user not found', { name });
        continue;
      }

      const recipientUid = targetUserDoc.id;
      // Do not notify self
      if (recipientUid === senderUid) continue;

      const title = `${senderName || 'Someone'} mentioned you on "${boardTitle || 'Board'}"`;
      const body = commentText.length > 120 ? `${commentText.substring(0, 117)}...` : commentText;

      await sendUserNotification({
        recipientUid,
        title,
        body,
        type: 'mention',
        action: 'open_board',
        targetId: boardId,
        senderUid,
        senderName: senderName || 'User',
        senderPhotoUrl: senderPhotoUrl || null,
        groupingKey: `mention:${boardId}:${commentId || Date.now()}`,
        extraData: {
          boardId,
          commentId: commentId || '',
          senderUid,
        },
      });

      notifiedCount++;
    } catch (userErr) {
      logger.warn('Failed to notify mentioned user', { name, error: userErr.message });
    }
  }

  return { success: true, notifiedCount };
};
