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

    if (typeof inviteId !== 'string' || inviteId.trim().length === 0) {
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

      const workspaceId = (invite.workspaceId || '').toString().trim();
      if (!workspaceId) {
        throw new HttpsError('failed-precondition', 'Invite does not include a valid workspaceId.');
      }

      const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(workspaceId);
      const workspaceDoc = await transaction.get(workspaceRef);
      if (!workspaceDoc.exists) {
        throw new HttpsError('not-found', 'Workspace not found.');
      }

      const workspaceBoardsSnapshot = await transaction.get(
        workspaceRef.collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION),
      );

      const memberRef = workspaceRef
        .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .doc(uid);
      const memberDoc = await transaction.get(memberRef);

      const boardMembershipTargets = [];
      for (const boardLinkDoc of workspaceBoardsSnapshot.docs) {
        const boardLink = boardLinkDoc.data() || {};
        const boardId = (boardLink[FirestorePaths.BOARD_ID] || boardLinkDoc.id)
          .toString()
          .trim();

        if (!boardId) {
          continue;
        }

        const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
        const boardDoc = await transaction.get(boardRef);
        if (!boardDoc.exists) {
          continue;
        }

        const boardMemberRef = boardRef
          .collection(FirestorePaths.BOARD_MEMBERS_SUBCOLLECTION)
          .doc(uid);
        const boardMemberDoc = await transaction.get(boardMemberRef);

        boardMembershipTargets.push({
          boardId,
          boardRef,
          boardDoc,
          boardMemberRef,
          boardMemberDoc,
        });
      }

      transaction.set(
        memberRef,
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

      if (!memberDoc.exists) {
        transaction.set(
          workspaceRef,
          {
            memberCount: admin.firestore.FieldValue.increment(1),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      transaction.set(
        firestore.collection(FirestorePaths.USERS).doc(uid),
        {
          [FirestorePaths.WORKSPACE_IDS]: admin.firestore.FieldValue.arrayUnion(workspaceId),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      for (const target of boardMembershipTargets) {
        const boardData = target.boardDoc.data() || {};
        const boardOwnerId = boardData[FirestorePaths.OWNER_ID];

        if (!target.boardMemberDoc.exists) {
          transaction.set(
            target.boardMemberRef,
            {
              uid,
              role: boardOwnerId === uid ? 'owner' : 'viewer',
              status: 'active',
              joinedAt: admin.firestore.FieldValue.serverTimestamp(),
              invitedBy: invite[FirestorePaths.FROM_UID] || null,
              [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        } else {
          transaction.set(
            target.boardMemberRef,
            {
              status: 'active',
              [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        transaction.update(target.boardRef, {
          members: admin.firestore.FieldValue.arrayUnion(uid),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.set(
          firestore.collection(FirestorePaths.USERS).doc(uid),
          boardOwnerId === uid
            ? {
                [FirestorePaths.OWNED_BOARDS]: admin.firestore.FieldValue.arrayUnion(target.boardId),
                [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
              }
            : {
                [FirestorePaths.JOINED_BOARDS]: admin.firestore.FieldValue.arrayUnion(target.boardId),
                [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
              },
          { merge: true },
        );
      }

      transaction.delete(inviteRef);

      return { success: true, workspaceId };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('acceptWorkspaceInvite failed', error);
    throw new HttpsError('internal', 'Failed to accept workspace invite.');
  }
};