const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('../../server/firebase-admin');
const FirestorePaths = require('../utils/firestore_paths');
const logger = require('../utils/logger');

const VISIBILITY_PUBLIC = 'public';
const VISIBILITY_PRIVATE = 'private';
const POLICY_OWNER_ONLY_INVITE = 'owner_only_invite';
const POLICY_LINK_CAN_JOIN = 'link_can_join';
const INVITE_OWNER_ONLY = 'owner_only';
const INVITE_OWNER_EDITOR = 'owner_editor';
const INVITE_ALL_MEMBERS = 'all_members';
const ROLE_EDITOR = 'editor';
const ROLE_VIEWER = 'viewer';

function normalizeVisibility(value) {
  if (value === VISIBILITY_PUBLIC) return VISIBILITY_PUBLIC;
  return VISIBILITY_PRIVATE;
}

function normalizePrivateJoinPolicy(value) {
  if (value === POLICY_LINK_CAN_JOIN) return POLICY_LINK_CAN_JOIN;
  return POLICY_OWNER_ONLY_INVITE;
}

function normalizeWhoCanInvite(value) {
  if (value === INVITE_OWNER_EDITOR) return INVITE_OWNER_EDITOR;
  if (value === INVITE_ALL_MEMBERS) return INVITE_ALL_MEMBERS;
  return INVITE_OWNER_ONLY;
}

function normalizeDefaultLinkJoinRole(value) {
  if (value === ROLE_EDITOR) return ROLE_EDITOR;
  return ROLE_VIEWER;
}

module.exports = async (request) => {
  const uid = request.auth?.uid;
  const boardId = request.data?.boardId;

  try {
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (typeof boardId !== 'string' || boardId.trim().isEmpty) {
      throw new HttpsError('invalid-argument', 'boardId is required.');
    }

    const firestore = admin.firestore();
    const boardRef = firestore.collection(FirestorePaths.BOARDS).doc(boardId.trim());
    const boardDoc = await boardRef.get();

    if (!boardDoc.exists) {
      throw new HttpsError('not-found', 'Board not found.');
    }

    const boardData = boardDoc.data() || {};
    if (boardData.ownerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the board owner can update board settings.');
    }

    const visibility = normalizeVisibility(request.data?.visibility);
    const privateJoinPolicy = normalizePrivateJoinPolicy(request.data?.privateJoinPolicy);
    const whoCanInvite = normalizeWhoCanInvite(request.data?.whoCanInvite);
    const defaultLinkJoinRole = normalizeDefaultLinkJoinRole(
      request.data?.defaultLinkJoinRole,
    );

    const joinViaCodeEnabled =
      visibility === VISIBILITY_PUBLIC || privateJoinPolicy === POLICY_LINK_CAN_JOIN;

    await boardRef.set(
      {
        [FirestorePaths.VISIBILITY]: visibility,
        [FirestorePaths.PRIVATE_JOIN_POLICY]: privateJoinPolicy,
        [FirestorePaths.JOIN_VIA_CODE_ENABLED]: joinViaCodeEnabled,
        [FirestorePaths.INVITE_POLICY]: {
          [FirestorePaths.WHO_CAN_INVITE]: whoCanInvite,
          [FirestorePaths.DEFAULT_LINK_JOIN_ROLE]: defaultLinkJoinRole,
        },
        [FirestorePaths.UPDATED_AT]: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      success: true,
      boardId: boardId.trim(),
      visibility,
      privateJoinPolicy,
      invitePolicy: {
        whoCanInvite,
        defaultLinkJoinRole,
      },
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error('updateBoardSettings failed', error);
    throw new HttpsError('internal', 'Failed to update board settings.');
  }
};