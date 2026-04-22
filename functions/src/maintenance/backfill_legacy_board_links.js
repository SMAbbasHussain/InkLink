const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

/**
 * Backfill legacy workspace board links with boardSource field.
 * This function should be called once to migrate existing boards to the new schema.
 * Legacy boards without boardSource are assumed to be 'imported'.
 * 
 * Can be called via HTTP request with admin credentials.
 */
module.exports = async (request) => {
  // This function should only be callable by admins or via service-to-service auth
  const uid = request.auth?.uid;
  if (!uid) {
    return {
      success: false,
      message: 'Backfill function requires authentication.',
      count: 0,
    };
  }

  try {
    const firestore = admin.firestore();
    let totalUpdated = 0;

    // Get all workspaces
    const workspacesSnapshot = await firestore
      .collection(FirestorePaths.WORKSPACES)
      .get();

    for (const workspaceDoc of workspacesSnapshot.docs) {
      const workspaceId = workspaceDoc.id;

      // Get all board links in this workspace that don't have boardSource
      const boardLinksSnapshot = await firestore
        .collection(FirestorePaths.WORKSPACES)
        .doc(workspaceId)
        .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
        .where(FirestorePaths.BOARD_SOURCE, '==', null)
        .get();

      // Also check for docs where the field doesn't exist at all
      const allBoardLinksSnapshot = await firestore
        .collection(FirestorePaths.WORKSPACES)
        .doc(workspaceId)
        .collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION)
        .get();

      for (const boardLinkDoc of allBoardLinksSnapshot.docs) {
        const linkData = boardLinkDoc.data() || {};

        // If boardSource field is missing or null, tag it as 'imported'
        if (!linkData[FirestorePaths.BOARD_SOURCE]) {
          await boardLinkDoc.ref.update({
            [FirestorePaths.BOARD_SOURCE]: 'imported',
            'backfilledAt': admin.firestore.FieldValue.serverTimestamp(),
          });
          totalUpdated++;
        }
      }
    }

    logger.info('Backfill legacy board links completed', {
      totalUpdated,
      workspacesProcessed: workspacesSnapshot.size,
    });

    return {
      success: true,
      message: `Backfill completed: ${totalUpdated} board links updated.`,
      count: totalUpdated,
      workspacesProcessed: workspacesSnapshot.size,
    };
  } catch (error) {
    logger.error('Backfill legacy board links failed', error);
    return {
      success: false,
      message: `Backfill failed: ${error.message}`,
      count: 0,
    };
  }
};
