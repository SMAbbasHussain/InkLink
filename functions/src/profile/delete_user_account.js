const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { S3Client, ListObjectsV2Command, DeleteObjectsCommand } = require('@aws-sdk/client-s3');
const { deleteBoardState } = require('../utils/redis');

/**
 * Cloud Function: deleteUserAccount
 * Cascade-deletes a user's entire account and associated data:
 * - Boards owned by user (including CRDT state & members)
 * - Membership in other boards
 * - Workspace memberships
 * - Friends subcollections (reciprocal) and friend requests
 * - Notifications
 * - Cloudflare R2 uploaded assets (profile photos)
 * - Firestore user document
 * - Firebase Auth user record
 */
module.exports = async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    logger.warn('deleteUserAccount: Unauthenticated call');
    throw new HttpsError('unauthenticated', 'User must be authenticated to delete their account.');
  }

  logger.info(`deleteUserAccount: Starting account purge for user ${uid}`);

  const firestore = admin.firestore();
  const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);

  try {
    // 1. Delete owned boards (recursively deleting operations, snapshots, members, etc.)
    const ownedBoardsSnap = await firestore
      .collection(FirestorePaths.BOARDS)
      .where('ownerId', '==', uid)
      .get();

    for (const doc of ownedBoardsSnap.docs) {
      const boardId = doc.id;
      try {
        // Delete Redis / CRDT state
        try {
          await deleteBoardState(boardId);
        } catch (rErr) {
          logger.warn(`deleteUserAccount: Redis cleanup for board ${boardId} failed: ${rErr.message}`);
        }

        // Recursively delete board doc and all subcollections
        await firestore.recursiveDelete(doc.ref);
      } catch (err) {
        logger.warn(`deleteUserAccount: Error deleting owned board ${boardId}: ${err.message}`);
      }
    }

    // 2. Remove user from boards where they were a collaborator
    const memberBoardsSnap = await firestore
      .collection(FirestorePaths.BOARDS)
      .where('members', 'array-contains', uid)
      .get();

    for (const doc of memberBoardsSnap.docs) {
      try {
        await doc.ref.update({
          members: admin.firestore.FieldValue.arrayRemove(uid),
          [FirestorePaths.MEMBER_COUNT]: admin.firestore.FieldValue.increment(-1),
          membersCount: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await doc.ref.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid).delete();
      } catch (err) {
        logger.warn(`deleteUserAccount: Failed removing from board ${doc.id}: ${err.message}`);
      }
    }

    // 3. Purge workspace ownership and memberships
    // 3a. Delete workspaces owned by user
    const ownedWorkspacesSnap = await firestore
      .collection(FirestorePaths.WORKSPACES)
      .where('ownerId', '==', uid)
      .get();

    for (const wsDoc of ownedWorkspacesSnap.docs) {
      try {
        await firestore.recursiveDelete(wsDoc.ref);
      } catch (wsErr) {
        logger.warn(`deleteUserAccount: Error deleting owned workspace ${wsDoc.id}: ${wsErr.message}`);
      }
    }

    // 3b. Remove user from non-owned workspaces where they are a member
    const userDocSnap = await userRef.get();
    const userData = userDocSnap.data() || {};
    const joinedWorkspaceIds = new Set(
      Array.isArray(userData[FirestorePaths.WORKSPACE_IDS])
        ? userData[FirestorePaths.WORKSPACE_IDS]
        : [],
    );

    try {
      const memberQuerySnap = await firestore
        .collectionGroup(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .where('uid', '==', uid)
        .get();

      for (const mDoc of memberQuerySnap.docs) {
        const parentCol = mDoc.ref.parent;
        const wsRef = parentCol.parent;
        if (wsRef && parentCol.id === FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION) {
          joinedWorkspaceIds.add(wsRef.id);
        }
      }
    } catch (cgErr) {
      logger.warn(`deleteUserAccount: collectionGroup query for workspace members failed: ${cgErr.message}`);
    }

    for (const wsId of joinedWorkspaceIds) {
      try {
        const wsRef = firestore.collection(FirestorePaths.WORKSPACES).doc(wsId);
        const wsSnap = await wsRef.get();
        if (!wsSnap.exists || wsSnap.data()?.ownerId === uid) {
          continue;
        }
        const mRef = wsRef.collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION).doc(uid);
        const mDoc = await mRef.get();
        if (mDoc.exists) {
          await mRef.delete();
          await wsRef.update({
            memberCount: admin.firestore.FieldValue.increment(-1),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } catch (err) {
        logger.warn(`deleteUserAccount: Failed removing from workspace ${wsId}: ${err.message}`);
      }
    }

    // 3c. Purge workspace invites
    try {
      const [sentWsInvites, receivedWsInvites] = await Promise.all([
        firestore.collection(FirestorePaths.WORKSPACE_INVITES).where('fromUid', '==', uid).get(),
        firestore.collection(FirestorePaths.WORKSPACE_INVITES).where('toUid', '==', uid).get(),
      ]);
      const wsInvBatch = firestore.batch();
      sentWsInvites.docs.forEach((d) => wsInvBatch.delete(d.ref));
      receivedWsInvites.docs.forEach((d) => wsInvBatch.delete(d.ref));
      await wsInvBatch.commit();
    } catch (invErr) {
      logger.warn(`deleteUserAccount: Failed cleaning workspace invites: ${invErr.message}`);
    }

    // 4. Purge friend requests (sent & received)
    const [sentRequests, receivedRequests] = await Promise.all([
      firestore.collection(FirestorePaths.FRIEND_REQUESTS).where('fromUid', '==', uid).get(),
      firestore.collection(FirestorePaths.FRIEND_REQUESTS).where('toUid', '==', uid).get(),
    ]);

    const reqBatch = firestore.batch();
    sentRequests.docs.forEach((d) => reqBatch.delete(d.ref));
    receivedRequests.docs.forEach((d) => reqBatch.delete(d.ref));
    await reqBatch.commit();

    // 5. Purge friendships and reciprocal friend records
    const friendsSnap = await userRef.collection(FirestorePaths.FRIENDS_SUBCOLLECTION).get();

    for (const fDoc of friendsSnap.docs) {
      const friendUid = fDoc.id;
      // Remove reciprocal friendship
      try {
        await firestore
          .collection(FirestorePaths.USERS)
          .doc(friendUid)
          .collection(FirestorePaths.FRIENDS_SUBCOLLECTION)
          .doc(uid)
          .delete();

        await firestore
          .collection(FirestorePaths.USERS)
          .doc(friendUid)
          .update({
            [FirestorePaths.FRIEND_COUNT]: admin.firestore.FieldValue.increment(-1),
          });
      } catch (_) {}
      await fDoc.ref.delete();
    }

    // 6. Delete notifications & user boards subcollection
    const notifsSnap = await userRef.collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION).get();
    const notifBatch = firestore.batch();
    notifsSnap.docs.forEach((d) => notifBatch.delete(d.ref));
    await notifBatch.commit();

    const userBoardsSnap = await userRef.collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION).get();
    const uBoardsBatch = firestore.batch();
    userBoardsSnap.docs.forEach((d) => uBoardsBatch.delete(d.ref));
    await uBoardsBatch.commit();

    // 7. Delete Cloudflare R2 profile photos if configured
    if (
      process.env.CLOUDFLARE_R2_ACCESS_KEY &&
      process.env.CLOUDFLARE_R2_SECRET_KEY &&
      process.env.CLOUDFLARE_ACCOUNT_ID &&
      process.env.CLOUDFLARE_R2_BUCKET
    ) {
      try {
        const s3Client = new S3Client({
          region: 'auto',
          credentials: {
            accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY,
            secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_KEY,
          },
          endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        });

        const listCommand = new ListObjectsV2Command({
          Bucket: process.env.CLOUDFLARE_R2_BUCKET,
          Prefix: `profiles/${uid}/`,
        });

        const listed = await s3Client.send(listCommand);
        if (listed.Contents && listed.Contents.length > 0) {
          const deleteCommand = new DeleteObjectsCommand({
            Bucket: process.env.CLOUDFLARE_R2_BUCKET,
            Delete: {
              Objects: listed.Contents.map((item) => ({ Key: item.Key })),
            },
          });
          await s3Client.send(deleteCommand);
          logger.info(`deleteUserAccount: Deleted ${listed.Contents.length} R2 assets for user ${uid}`);
        }
      } catch (s3Err) {
        logger.warn(`deleteUserAccount: Failed R2 cleanup for user ${uid}: ${s3Err.message}`);
      }
    }

    // 8. Delete Firestore user document
    await userRef.delete();

    // 9. Delete Firebase Auth user record
    try {
      await admin.auth().deleteUser(uid);
      logger.info(`deleteUserAccount: Firebase Auth record deleted for ${uid}`);
    } catch (authErr) {
      logger.warn(`deleteUserAccount: Admin auth delete failed (user might be deleting self directly): ${authErr.message}`);
    }

    logger.info(`deleteUserAccount: Successfully purged user ${uid}`);
    return { success: true, message: 'User account and associated data successfully deleted.' };
  } catch (error) {
    logger.error(`deleteUserAccount: Unexpected error purging user ${uid}`, error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', 'Failed to delete user account data. Please try again.');
  }
};
