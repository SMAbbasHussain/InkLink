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

    if (typeof workspaceId !== 'string' || workspaceId.trim().length === 0) {
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

    await firestore.runTransaction(async (transaction) => {
      const memberRef = workspaceRef
        .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .doc(uid);
      const memberDoc = await transaction.get(memberRef);

      if (memberDoc.exists) {
        transaction.delete(memberRef);
        transaction.set(
          workspaceRef,
          {
            memberCount: admin.firestore.FieldValue.increment(-1),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      transaction.set(
        firestore.collection(FirestorePaths.USERS).doc(uid),
        {
          [FirestorePaths.WORKSPACE_IDS]: admin.firestore.FieldValue.arrayRemove(workspaceId.trim()),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { success: true, workspaceId: workspaceId.trim() };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('leaveWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to leave workspace.');
  }
};