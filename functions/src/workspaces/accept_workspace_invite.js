const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const inviteId = request.data?.inviteId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof inviteId !== 'string' || inviteId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'inviteId is required.');
    }

    const firestore = admin.firestore();

    return await firestore.runTransaction(async (transaction) => {
      const inviteRef = firestore.collection(FirestorePaths.WORKSPACE_INVITES).doc(inviteId.trim());
      const inviteDoc = await transaction.get(inviteRef);

      if (!inviteDoc.exists) {
        throw new HttpsError('not-found', 'Workspace invite not found.');
      }

      const invite = inviteDoc.data() || {};
      if (invite[FirestorePaths.TO_UID] !== uid) {
        throw new HttpsError('permission-denied', 'Invite is not assigned to current user.');
      }

      if (invite[FirestorePaths.STATUS] !== 'pending') {
        throw new HttpsError('failed-precondition', 'Invite is no longer pending.');
      }

      const { workspaceId } = invite;
      const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId);
      const workspaceDoc = await transaction.get(workspaceRef);
      if (!workspaceDoc.exists) {
        throw new HttpsError('not-found', 'Workspace not found.');
      }

      transaction.set(
        workspaceRef.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid),
        {
          uid,
          role: 'member',
          status: 'active',
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          invitedBy: invite[FirestorePaths.FROM_UID] || null,
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      transaction.set(
        workspaceRef,
        {
          memberCount: admin.firestore.FieldValue.increment(1),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      transaction.delete(inviteRef);

      return { success: true, workspaceId };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('acceptWorkspaceInvite failed', error);
    throw new HttpsError('internal', 'Failed to accept workspace invite.');
  }
};