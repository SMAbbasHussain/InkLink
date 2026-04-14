const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'workspaceId is required.');
    }

    const firestore = admin.firestore();
    const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId.trim());
    const workspaceDoc = await workspaceRef.get();

    if (!workspaceDoc.exists) {
      throw new HttpsError('not-found', 'Workspace not found.');
    }

    const workspace = workspaceDoc.data() || {};
    if (workspace.ownerId === uid) {
      throw new HttpsError('failed-precondition', 'Workspace owner cannot leave. Delete workspace or transfer ownership first.');
    }

    const memberRef = workspaceRef.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid);
    await memberRef.delete();

    await workspaceRef.set(
      {
        memberCount: admin.firestore.FieldValue.increment(-1),
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { success: true, workspaceId: workspaceId.trim() };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('leaveWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to leave workspace.');
  }
};