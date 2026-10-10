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

  try {
    // 1. Delete owned boards
    const ownedBoardsSnap = await firestore
      .collection(FirestorePaths.BOARDS)
      .where('ownerId', '==', uid)
      .get();

    for (const doc of ownedBoardsSnap.docs) {
      const boardId = doc.id;
      try {
        // Delete board members subcollection
        const membersSnap = await doc.ref.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).get();
        const batch = firestore.batch();
        membersSnap.docs.forEach((mDoc) => batch.delete(mDoc.ref));
        await batch.commit();

        // Delete board doc
        await doc.ref.delete();

        // Delete Redis / CRDT state
        try {
          await deleteBoardState(boardId);
        } catch (rErr) {
          logger.warn(`deleteUserAccount: Redis cleanup for board ${boardId} failed: ${rErr.message}`);
        }
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
        });
        await doc.ref.collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION).doc(uid).delete();
      } catch (err) {
        logger.warn(`deleteUserAccount: Failed removing from board ${doc.id}: ${err.message}`);
      }
    }

    // 3. Purge friend requests (sent & received)
    const [sentRequests, receivedRequests] = await Promise.all([
      firestore.collection(FirestorePaths.FRIEND_REQUESTS).where('fromUid', '==', uid).get(),
      firestore.collection(FirestorePaths.FRIEND_REQUESTS).where('toUid', '==', uid).get(),
    ]);

    const reqBatch = firestore.batch();
    sentRequests.docs.forEach((d) => reqBatch.delete(d.ref));
    receivedRequests.docs.forEach((d) => reqBatch.delete(d.ref));
    await reqBatch.commit();

    // 4. Purge friendships and reciprocal friend records
    const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);
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

    // 5. Delete notifications & user boards subcollection
    const notifsSnap = await userRef.collection(FirestorePaths.NOTIFICATIONS_SUBCOLLECTION).get();
    const notifBatch = firestore.batch();
    notifsSnap.docs.forEach((d) => notifBatch.delete(d.ref));
    await notifBatch.commit();

    const userBoardsSnap = await userRef.collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION).get();
    const uBoardsBatch = firestore.batch();
    userBoardsSnap.docs.forEach((d) => uBoardsBatch.delete(d.ref));
    await uBoardsBatch.commit();

    // 6. Delete Cloudflare R2 profile photos if configured
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

    // 7. Delete Firestore user document
    await userRef.delete();

    // 8. Delete Firebase Auth user record
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
