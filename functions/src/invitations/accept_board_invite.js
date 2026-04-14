const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { updateUserNotificationStatus } = require('../utils/notification_sender');

const ROLE_OWNER = 'owner';
const ROLE_EDITOR = 'editor';
const ROLE_VIEWER = 'viewer';

function normalizeInviteRole(role) {
  if (typeof role !== 'string') return ROLE_VIEWER;
  const normalized = role.trim().toLowerCase();
  if (normalized === ROLE_EDITOR || normalized === ROLE_VIEWER) {
    return normalized;
  }
  return ROLE_VIEWER;
}

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const inviteId = request.data?.inviteId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof inviteId !== 'string' || inviteId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'inviteId is required.');
    }

    const firestore = admin.firestore();

    const result = await firestore.runTransaction(async (transaction) => {
      const inviteRef = firestore.collection(FirestorePaths.BOARD_INVITES).doc(inviteId);
      const inviteDoc = await transaction.get(inviteRef);

      if (!inviteDoc.exists) {
        throw new HttpsError('not-found', 'Invite not found.');
      }

      const invite = inviteDoc.data() || {};
      if (invite.toUid !== uid) {
        throw new HttpsError('permission-denied', 'Invite is not assigned to current user.');
      }

      if (invite.status !== 'pending') {
        throw new HttpsError('failed-precondition', 'Invite is no longer pending.');
      }

      const { expiresAt, boardId } = invite;
      if (
        expiresAt &&
        typeof expiresAt.toDate === 'function' &&
        expiresAt.toDate().getTime() < Date.now()
      ) {
        transaction.update(inviteRef, {
          status: 'expired',
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw new HttpsError('deadline-exceeded', 'Invite has expired.');
      }

      const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
      const boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw new HttpsError('not-found', 'Board not found.');
      }

      const boardData = boardDoc.data() || {};
      const roleFromInvite = normalizeInviteRole(invite[FirestorePaths.TARGET_ROLE]);
      const resolvedRole = boardData.ownerId === uid ? ROLE_OWNER : roleFromInvite;

      const memberRef = boardRef
        .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
        .doc(uid);

      transaction.set(memberRef, {
        uid,
        role: resolvedRole,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        invitedBy: invite[FirestorePaths.FROM_UID] || null,
        invitedAt: invite[FirestorePaths.TIMESTAMP] || null,
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);

      transaction.update(boardRef, {
        members: admin.firestore.FieldValue.arrayUnion(uid),
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayUnion(boardId),
        [FirestorePaths.LAST_ACTIVE]: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Keep board_invites as a pending-only collection.
      // Once accepted, remove the invite document.
      transaction.delete(inviteRef);

      return {
        success: true,
        boardId,
        inviteId,
        role: resolvedRole,
      };
    });

    await updateUserNotificationStatus({
      recipientUid: uid,
      type: 'board_invite',
      targetId: inviteId,
      status: 'accepted',
      title: 'Board invite accepted',
      body: 'You accepted this board invite.',
    });

    return result;

  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('acceptBoardInvite failed', error);
    throw new HttpsError('internal', 'Failed to accept board invite.');
  }
};
