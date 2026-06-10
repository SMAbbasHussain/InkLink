const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const { sendUserNotification } = require('../utils/notification_sender');
const logger = require('../utils/logger');

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const workspaceId = request.data?.workspaceId;
  const invitedUserIds = request.data?.invitedUserIds;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof workspaceId !== 'string' || workspaceId.trim().length === 0) {
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

    const senderDoc = await firestore.collection(FirestorePaths.USERS).doc(uid).get();
    const senderData = senderDoc.data() || {};
    const senderName = senderData.displayName || 'InkLink User';
    const senderPhotoUrl = senderData.photoURL || null;
    const workspaceName = (workspaceData[FirestorePaths.NAME] || '').toString().trim() || 'workspace';

    const inviteIdentifiers = [...new Set(invitedUserIds)]
      .filter((value) => typeof value === 'string' && value.trim().length > 0)
      .map((value) => value.trim())
      .filter((value) => value !== uid);

    const resolvedRecipientUids = [];
    const unresolvedEmails = [];
    const unresolvedUids = [];

    for (const identifier of inviteIdentifiers) {
      if (identifier.includes('@')) {
        const normalizedEmail = identifier.toLowerCase();

        const userByEmail = await firestore
          .collection(FirestorePaths.USERS)
          .where(FirestorePaths.EMAIL, '==', normalizedEmail)
          .limit(1)
          .get();

        if (userByEmail.docs.length === 0) {
          // If migration has not yet run, record unresolved email for operator review.
          unresolvedEmails.push(identifier);
          continue;
        }

        resolvedRecipientUids.push(userByEmail.docs[0].id);
        continue;
      }

      const targetUserDoc = await firestore
        .collection(FirestorePaths.USERS)
        .doc(identifier)
        .get();

      if (!targetUserDoc.exists) {
        unresolvedUids.push(identifier);
        continue;
      }

      resolvedRecipientUids.push(identifier);
    }

    const results = [];
    const failedRecipients = [];
    const uniqueTargetUids = [...new Set(resolvedRecipientUids)]
      .filter((id) => id && id !== uid);

    // Phase 1: Batch write all invite docs
    const batch = firestore.batch();
    const inviteRefs = {};
    for (const targetUid of uniqueTargetUids) {
      const inviteRef = firestore
        .collection(FirestorePaths.WORKSPACE_INVITES)
        .doc(`${workspaceId.trim()}_${targetUid}`);
      inviteRefs[targetUid] = inviteRef;
      batch.set(inviteRef, {
        workspaceId: workspaceId.trim(),
        [FirestorePaths.FROM_UID]: uid,
        [FirestorePaths.TO_UID]: targetUid,
        [FirestorePaths.SENDER_NAME]: senderName,
        [FirestorePaths.SENDER_PIC]: senderPhotoUrl,
        [FirestorePaths.NAME]: workspaceName,
        [FirestorePaths.STATUS]: 'pending',
        [FirestorePaths.TIMESTAMP]: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    try {
      await batch.commit();
    } catch (batchError) {
      logger.error('inviteToWorkspace batch commit failed', batchError);
      throw new HttpsError('internal', 'Failed to create workspace invites.');
    }

    // Phase 2: Send notifications in parallel
    const notificationPromises = uniqueTargetUids.map(async (targetUid) => {
      try {
        await sendUserNotification({
          recipientUid: targetUid,
          title: `${senderName} invited you to a workspace`,
          body: `Invitation to join "${workspaceName}"`,
          type: 'workspace_invite',
          action: 'open_workspace_invites',
          targetId: inviteRefs[targetUid].id,
          senderUid: uid,
          senderName,
          senderPhotoUrl,
          groupingKey: `workspace_invite:${uid}:${targetUid}`,
          extraData: {
            workspaceId: workspaceId.trim(),
            workspaceName,
            inviteId: inviteRefs[targetUid].id,
          },
        });
        results.push({ targetUid, inviteId: inviteRefs[targetUid].id });
      } catch (notifError) {
        logger.warn('inviteToWorkspace notification failed', {
          workspaceId: workspaceId.trim(),
          senderUid: uid,
          targetUid,
          errorMessage: notifError instanceof Error ? notifError.message : String(notifError),
        });
        failedRecipients.push(targetUid);
      }
    });

    await Promise.all(notificationPromises);

    return {
      success: true,
      workspaceId: workspaceId.trim(),
      invitedCount: results.length,
      results,
      unresolvedEmails,
      unresolvedUids,
      failedRecipients,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('inviteToWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to invite users to workspace.');
  }
};