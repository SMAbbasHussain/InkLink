const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');
const { addBoardMember } = require('../utils/redis');

const VISIBILITY_PUBLIC = 'public';

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

    const requestedId = workspaceId.trim();
    const firestore = admin.firestore();

    const result = await firestore.runTransaction(async (transaction) => {
      // 1. Locate workspace by exact document ID only (no prefix matching —
      // partial IDs would let callers enumerate workspaces).
      const workspaceRef = firestore.collection(FirestorePaths.WORKSPACES).doc(requestedId);
      const workspaceDoc = await transaction.get(workspaceRef);

      if (!workspaceDoc.exists) {
        throw new HttpsError('not-found', 'Workspace not found.');
      }

      const workspaceId = workspaceDoc.id;
      const workspaceData = workspaceDoc.data() || {};

      const memberRef = workspaceRef
        .collection(FirestorePaths.WORKSPACE_MEMBERS_SUBCOLLECTION)
        .doc(uid);
      const memberDoc = await transaction.get(memberRef);

      if (memberDoc.exists && memberDoc.data()?.status === 'active') {
        return { success: true, workspaceId, alreadyMember: true };
      }

      // 2. Access gate: only the owner, a user with a pending invite, or a
      // public workspace can be joined.
      const isOwner = workspaceData.ownerId === uid;
      const inviteRef = firestore
        .collection(FirestorePaths.WORKSPACE_INVITES)
        .doc(`${workspaceId}_${uid}`);
      const inviteDoc = await transaction.get(inviteRef);
      const hasPendingInvite =
        inviteDoc.exists &&
        (inviteDoc.data()?.[FirestorePaths.STATUS] ?? 'pending') === 'pending';
      const visibility = String(workspaceData[FirestorePaths.VISIBILITY] || 'private');

      if (!isOwner && !hasPendingInvite && visibility !== VISIBILITY_PUBLIC) {
        throw new HttpsError(
          'permission-denied',
          'This workspace is private. You need an invite from the owner to join.',
        );
      }

      const workspaceBoardsSnapshot = await transaction.get(
        workspaceRef.collection(FirestorePaths.WORKSPACE_BOARDS_SUBCOLLECTION),
      );

      const boardMembershipTargets = [];
      for (const boardLinkDoc of workspaceBoardsSnapshot.docs) {
        const boardLink = boardLinkDoc.data() || {};
        const boardId = (boardLink[FirestorePaths.BOARD_ID] || boardLinkDoc.id)
          .toString()
          .trim();

        if (!boardId) continue;

        const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId);
        const boardDoc = await transaction.get(boardRef);
        if (!boardDoc.exists) continue;

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

      // Add to workspace members
      transaction.set(
        memberRef,
        {
          uid,
          role: workspaceData.ownerId === uid ? 'owner' : 'member',
          status: 'active',
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Update workspace doc: memberCount & members array
      transaction.set(
        workspaceRef,
        {
          members: admin.firestore.FieldValue.arrayUnion(uid),
          memberCount: admin.firestore.FieldValue.increment(memberDoc.exists ? 0 : 1),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Add workspace to user's workspaceIds array
      transaction.set(
        firestore.collection(FirestorePaths.USERS).doc(uid),
        {
          [FirestorePaths.WORKSPACE_IDS]: admin.firestore.FieldValue.arrayUnion(workspaceId),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Add member to all boards inside this workspace
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
          [FirestorePaths.MEMBER_COUNT]: admin.firestore.FieldValue.increment(
            target.boardMemberDoc.exists ? 0 : 1,
          ),
          [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
        });

        const userRef = firestore.collection(FirestorePaths.USERS).doc(uid);
        transaction.set(
          userRef,
          {
            [FirestorePaths.BOARD_COUNT]: admin.firestore.FieldValue.increment(
              target.boardMemberDoc.exists ? 0 : 1,
            ),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        transaction.set(
          userRef.collection(FirestorePaths.USER_BOARDS_SUBCOLLECTION).doc(target.boardId),
          {
            boardId: target.boardId,
            relation: boardOwnerId === uid ? 'owned' : 'joined',
            addedAt: admin.firestore.FieldValue.serverTimestamp(),
            [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      // Cleanup any pending invite (inviteRef declared earlier in this
      // transaction callback)
      transaction.delete(inviteRef);

      return {
        success: true,
        workspaceId,
        boardIds: boardMembershipTargets.map((t) => t.boardId),
      };
    });

    if (result.success && result.boardIds) {
      for (const boardId of result.boardIds) {
        await addBoardMember(boardId, uid);
      }
    }

    return result;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('joinWorkspace failed', error);
    throw new HttpsError('internal', 'Failed to join workspace.');
  }
};
