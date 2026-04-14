const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;
  const invitedUserIds = request.data?.invitedUserIds;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'workspaceId is required.');
    }

    if (!Array.isArray(invitedUserIds) || invitedUserIds.length === 0) {
      throw new HttpsError('invalid-argument', 'invitedUserIds must be a non-empty array.');
    }

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    const workspaceData = workspaceDoc.data() || {};
    if (workspaceData.ownerId !== uid) {
      throw new HttpsError('permission-denied', 'Only workspace owner can invite users.');
    }

    const results = [];
    for (const targetUidRaw of invitedUserIds) {
      if (typeof targetUidRaw !== 'string') continue;
      const targetUid = targetUidRaw.trim();
      if (!targetUid || targetUid === uid) continue;

      const inviteRef = firestore
        .collection(FirestorePaths.WORKSPACE_INVITES)
        .doc(`${workspaceId.trim()}_${targetUid}`);

      await inviteRef.set(
        {
          workspaceId: workspaceId.trim(),
          [FirestorePaths.FROM_UID]: uid,
          [FirestorePaths.TO_UID]: targetUid,
          [FirestorePaths.STATUS]: 'pending',
          [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      results.push({ targetUid, inviteId: inviteRef.id });
    }

    return { success: true, workspaceId: workspaceId.trim(), invitedCount: results.length, results };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('inviteToWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to invite users to workspace.');
  }
};