const FirestorePaths = require('../utils/firestore_paths');

function makeFriendRequestId(uidA, uidB) {
  return [uidA, uidB].sort().join('_');
}

function makeBlockId(blockerUid, blockedUid) {
  return `${blockerUid}_${blockedUid}`;
}

function getFriendRef(firestore, ownerUid, friendUid) {
  return firestore
    .collection(FirestorePaths.USERS)
    .doc(ownerUid)
    .collection(FirestorePaths.FRIENDS_SUBCOLLECTION)
    .doc(friendUid);
}

function getRequestRef(firestore, uidA, uidB) {
  return firestore.collection(FirestorePaths.FRIEND_REQUESTS).doc(makeFriendRequestId(uidA, uidB));
}

function getBlockRef(firestore, blockerUid, blockedUid) {
  return firestore.collection(FirestorePaths.BLOCKED_USERS).doc(makeBlockId(blockerUid, blockedUid));
}

async function hasBlock(transaction, firestore, blockerUid, blockedUid) {
  const blockDoc = await transaction.get(getBlockRef(firestore, blockerUid, blockedUid));
  return blockDoc.exists;
}

async function hasAnyBlock(transaction, firestore, uidA, uidB) {
  return (
    (await hasBlock(transaction, firestore, uidA, uidB)) ||
    (await hasBlock(transaction, firestore, uidB, uidA))
  );
}

module.exports = {
  makeFriendRequestId,
  makeBlockId,
  getFriendRef,
  getRequestRef,
  getBlockRef,
  hasBlock,
  hasAnyBlock,
};