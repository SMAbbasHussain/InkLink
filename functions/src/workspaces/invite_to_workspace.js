const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const { sendUserNotification } = require('../utils/notification_sender');
const logger = require('../utils/logger');

function createInviteToWorkspaceHandler(deps = {}) {
  const getFirestore = deps.getFirestore || (() => admin.firestore());
  const notifyUser = deps.sendUserNotification || sendUserNotification;
  const serverTimestamp =
    deps.serverTimestamp || (() => admin.firestore.FieldValue.serverTimestamp());
  const log = deps.logger || logger;

  return async (request) => {
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
        throw new HttpsError(
          'invalid-argument',
          'invitedUserIds must be a non-empty array.',
        );
      }

      const trimmedWorkspaceId = workspaceId.trim();
      const firestore = getFirestore();
      const workspaceRef = firestore
        .collection(FirestorePaths.WORKSPACES)
        .doc(trimmedWorkspaceId);
      const workspaceDoc = await workspaceRef.get();

      if (!workspaceDoc.exists) {
        throw new HttpsError('not-found', 'Workspace not found.');
      }

      const workspaceData = workspaceDoc.data() || {};
      if (workspaceData.ownerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Only workspace owner can invite users.',
        );
      }

      const senderDoc = await firestore
        .collection(FirestorePaths.USERS)
        .doc(uid)
        .get();
      const senderData = senderDoc.data() || {};
      const senderName = senderData.displayName || 'InkLink User';
      const senderPhotoUrl = senderData.photoURL || null;
      const workspaceName =
        (workspaceData[FirestorePaths.NAME] || '').toString().trim() ||
        'workspace';

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

          let userByEmail = await firestore
            .collection(FirestorePaths.USERS)
            .where(FirestorePaths.EMAIL, '==', normalizedEmail)
            .limit(1)
            .get();

          if (userByEmail.docs.length === 0 && identifier !== normalizedEmail) {
            userByEmail = await firestore
              .collection(FirestorePaths.USERS)
              .where(FirestorePaths.EMAIL, '==', identifier)
              .limit(1)
              .get();
          }

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

      const uniqueTargetUids = [...new Set(resolvedRecipientUids)].filter(
        (id) => id && id !== uid,
      );

      const existingMemberIds = new Set(
        Array.isArray(workspaceData.memberIds) ? workspaceData.memberIds : [],
      );

      // Phase 1: Atomically inspect membership/existing invites and write only
      // new invites so concurrent or repeated calls remain strictly idempotent.
      let newlyInvitedTargets = [];
      let alreadyInvitedUids = [];
      let alreadyMemberUids = [];

      try {
        const txResult = await firestore.runTransaction(async (transaction) => {
          const pendingReads = [];
          for (const targetUid of uniqueTargetUids) {
            const memberRef = workspaceRef
              .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
              .doc(targetUid);
            const inviteRef = firestore
              .collection(FirestorePaths.WORKSPACE_INVITES)
              .doc(`${trimmedWorkspaceId}_${targetUid}`);
            pendingReads.push({
              targetUid,
              memberRef,
              inviteRef,
              memberPromise: transaction.get(memberRef),
              invitePromise: transaction.get(inviteRef),
            });
          }

          const readResults = await Promise.all(
            pendingReads.map(async (entry) => ({
              targetUid: entry.targetUid,
              inviteRef: entry.inviteRef,
              memberDoc: await entry.memberPromise,
              inviteDoc: await entry.invitePromise,
            })),
          );

          const toCreate = [];
          const skippedPending = [];
          const skippedMembers = [];

          for (const entry of readResults) {
            const { targetUid, inviteRef, memberDoc, inviteDoc } = entry;
            if (memberDoc.exists || existingMemberIds.has(targetUid)) {
              skippedMembers.push(targetUid);
              continue;
            }

            const existingInvite = inviteDoc.exists ? inviteDoc.data() || {} : null;
            const existingStatus = existingInvite
              ? (existingInvite[FirestorePaths.STATUS] || 'pending')
                  .toString()
                  .trim()
                  .toLowerCase()
              : null;

            if (inviteDoc.exists && existingStatus === 'pending') {
              skippedPending.push(targetUid);
              continue;
            }

            transaction.set(
              inviteRef,
              {
                workspaceId: trimmedWorkspaceId,
                [FirestorePaths.FROM_UID]: uid,
                [FirestorePaths.TO_UID]: targetUid,
                [FirestorePaths.SENDER_NAME]: senderName,
                [FirestorePaths.SENDER_PIC]: senderPhotoUrl,
                [FirestorePaths.NAME]: workspaceName,
                [FirestorePaths.STATUS]: 'pending',
                [FirestorePaths.TIMESTAMP]: serverTimestamp(),
              },
              { merge: true },
            );

            toCreate.push({ targetUid, inviteId: inviteRef.id });
          }

          return { toCreate, skippedPending, skippedMembers };
        });

        newlyInvitedTargets = txResult.toCreate;
        alreadyInvitedUids = txResult.skippedPending;
        alreadyMemberUids = txResult.skippedMembers;
      } catch (txError) {
        log.error('inviteToWorkspace transaction failed', txError);
        throw new HttpsError('internal', 'Failed to create workspace invites.');
      }

      // Phase 2: Send notifications ONLY for newly created invites.
      const results = [];
      const failedRecipients = [];
      const notificationPromises = newlyInvitedTargets.map(
        async ({ targetUid, inviteId }) => {
          try {
            await notifyUser({
              recipientUid: targetUid,
              title: `${senderName} invited you to a workspace`,
              body: `Invitation to join "${workspaceName}"`,
              type: 'workspace_invite',
              action: 'open_workspace_invites',
              targetId: inviteId,
              senderUid: uid,
              senderName,
              senderPhotoUrl,
              groupingKey: `workspace_invite:${uid}:${targetUid}`,
              extraData: {
                workspaceId: trimmedWorkspaceId,
                workspaceName,
                inviteId,
              },
            });
            results.push({ targetUid, inviteId });
          } catch (notifError) {
            log.warn('inviteToWorkspace notification failed', {
              workspaceId: trimmedWorkspaceId,
              senderUid: uid,
              targetUid,
              errorMessage:
                notifError instanceof Error
                  ? notifError.message
                  : String(notifError),
            });
            failedRecipients.push(targetUid);
          }
        },
      );

      await Promise.all(notificationPromises);

      return {
        success: true,
        workspaceId: trimmedWorkspaceId,
        invitedCount: results.length,
        alreadyInvitedCount: alreadyInvitedUids.length,
        alreadyMemberCount: alreadyMemberUids.length,
        results,
        alreadyInvited: alreadyInvitedUids,
        alreadyMembers: alreadyMemberUids,
        unresolvedEmails,
        unresolvedUids,
        failedRecipients,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      log.error('inviteToWorkspace failed', error);
      throw new HttpsError('internal', 'Failed to invite users to workspace.');
    }
  };
}

const inviteToWorkspace = createInviteToWorkspaceHandler();
inviteToWorkspace.createInviteToWorkspaceHandler = createInviteToWorkspaceHandler;

module.exports = inviteToWorkspace;
