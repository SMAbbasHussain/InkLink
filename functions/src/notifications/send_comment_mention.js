const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const { validateString } = require('../utils/validation');
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

  const { boardId, commentId, commentText } = data;

  validateString(boardId, 'boardId');

  const senderUid = auth.uid;
  const firestore = admin.firestore();

  // 1. Verify board exists
  const boardDoc = await firestore.collection(FirestorePaths.BOARDS).doc(boardId).get();
  if (!boardDoc.exists) {
    throw new HttpsError('not-found', 'Board not found.');
  }
  const boardData = boardDoc.data() || {};

  // 2. Verify caller has access to the board
  const isOwner = boardData.ownerId === senderUid;
  const callerMemberDoc = await firestore
    .collection(FirestorePaths.BOARDS)
    .doc(boardId)
    .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
    .doc(senderUid)
    .get();
  const isMember = callerMemberDoc.exists && callerMemberDoc.data()?.status === 'active';

  if (!isOwner && !isMember) {
    throw new HttpsError('permission-denied', 'You do not have access to this board.');
  }

  // 3. Verify comment authorship if commentId is provided
  let actualCommentText = typeof commentText === 'string' ? commentText : '';
  if (commentId) {
    const commentDoc = await firestore
      .collection(FirestorePaths.BOARDS)
      .doc(boardId)
      .collection('comments')
      .doc(commentId)
      .get();
    if (commentDoc.exists) {
      const cData = commentDoc.data() || {};
      if (cData.authorUid && cData.authorUid !== senderUid) {
        throw new HttpsError('permission-denied', 'Caller is not the author of this comment.');
      }
      if (cData.text) {
        actualCommentText = cData.text;
      }
    }
  }

  // 4. Extract all @mentions from verified comment text
  const mentionMatches = actualCommentText.match(/@([a-zA-Z0-9_\.\-]+)/g) || [];
  if (mentionMatches.length === 0) {
    return { success: true, notifiedCount: 0 };
  }

  const rawTokens = [...new Set(mentionMatches.map((m) => m.substring(1)))];
  logger.info('Parsed mentions from comment', { boardId, commentId, rawTokens });

  // 5. Load verified sender profile and board title from Firestore (prevent spoofing)
  const senderUserDoc = await firestore.collection(FirestorePaths.USERS).doc(senderUid).get();
  const senderProfile = senderUserDoc.data() || {};
  const verifiedSenderName = senderProfile.displayName || data.senderName || 'InkLink User';
  const verifiedSenderPhotoUrl = senderProfile.photoURL || null;
  const verifiedBoardTitle = boardData.title || data.boardTitle || 'Board';

  // 6. Retrieve active board members to ensure mentioned users belong to the board
  const boardMemberUids = new Set();
  if (boardData.ownerId) {
    boardMemberUids.add(boardData.ownerId);
  }
  const membersSnapshot = await firestore
    .collection(FirestorePaths.BOARDS)
    .doc(boardId)
    .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
    .where('status', '==', 'active')
    .get();
  for (const doc of membersSnapshot.docs) {
    boardMemberUids.add(doc.id);
  }

  // Exclude sender
  const candidateUids = [...boardMemberUids].filter((uid) => uid !== senderUid);
  if (candidateUids.length === 0) {
    return { success: true, notifiedCount: 0 };
  }

  const userRefs = candidateUids.map((uid) => firestore.collection(FirestorePaths.USERS).doc(uid));
  const userSnapshots = await firestore.getAll(...userRefs);

  const memberProfiles = [];
  for (const uDoc of userSnapshots) {
    if (uDoc.exists) {
      const uData = uDoc.data() || {};
      memberProfiles.push({
        uid: uDoc.id,
        displayName: uData.displayName || '',
        username: uData.username || '',
        email: uData.email || '',
      });
    }
  }

  let notifiedCount = 0;
  const notifiedUids = new Set();

  for (const token of rawTokens) {
    try {
      const tokenLower = token.toLowerCase();

      // Match token against board members case-insensitively & with space/underscore normalization
      const matchedMember = memberProfiles.find((p) => {
        const dName = (p.displayName || '').toLowerCase();
        const dNameNoSpaces = dName.replace(/\s+/g, '');
        const dNameUnderscores = dName.replace(/\s+/g, '_');
        const uName = (p.username || '').toLowerCase();
        const emailPrefix = (p.email || '').split('@')[0].toLowerCase();

        return (
          dName === tokenLower ||
          dNameNoSpaces === tokenLower ||
          dNameUnderscores === tokenLower ||
          (uName && uName === tokenLower) ||
          (emailPrefix && emailPrefix === tokenLower)
        );
      });

      if (!matchedMember) {
        logger.debug('Mentioned user not found among board members', { token });
        continue;
      }

      const recipientUid = matchedMember.uid;
      if (notifiedUids.has(recipientUid)) continue;
      notifiedUids.add(recipientUid);

      const title = `${verifiedSenderName} mentioned you on "${verifiedBoardTitle}"`;
      const body =
        actualCommentText.length > 120
          ? `${actualCommentText.substring(0, 117)}...`
          : actualCommentText;

      await sendUserNotification({
        recipientUid,
        title,
        body,
        type: 'mention',
        action: 'open_board',
        targetId: boardId,
        senderUid,
        senderName: verifiedSenderName,
        senderPhotoUrl: verifiedSenderPhotoUrl,
        groupingKey: `mention:${boardId}:${commentId || Date.now()}`,
        extraData: {
          boardId,
          commentId: commentId || '',
          senderUid,
        },
      });

      notifiedCount++;
    } catch (userErr) {
      logger.warn('Failed to notify mentioned user', { token, error: userErr.message });
    }
  }

  return { success: true, notifiedCount };
};
