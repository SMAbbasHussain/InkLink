const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createInviteToWorkspaceHandler,
} = require('../../src/workspaces/invite_to_workspace');

function createTestFirestore(initial = {}) {
  const docs = new Map(Object.entries(initial));
  let txQueue = Promise.resolve();

  function snapshot(path) {
    const data = docs.get(path);
    const id = path.split('/').pop();
    return {
      id,
      exists: data !== undefined,
      data: () => (data ? { ...data } : undefined),
    };
  }

  function docRef(path) {
    const id = path.split('/').pop();
    return {
      id,
      path,
      async get() {
        return snapshot(path);
      },
      async set(value, options) {
        const merged = options?.merge
          ? { ...(docs.get(path) || {}), ...value }
          : { ...value };
        docs.set(path, merged);
      },
      collection: (name) => collectionRef(`${path}/${name}`),
    };
  }

  function collectionRef(path) {
    return {
      doc: (id) => docRef(`${path}/${id}`),
      where(field, op, value) {
        return {
          limit(n) {
            return {
              async get() {
                const matched = [];
                for (const [docPath, data] of docs.entries()) {
                  if (!docPath.startsWith(`${path}/`)) continue;
                  const rest = docPath.slice(path.length + 1);
                  if (rest.includes('/')) continue;
                  if (op === '==' && data?.[field] === value) {
                    matched.push(snapshot(docPath));
                    if (matched.length >= n) break;
                  }
                }
                return { docs: matched };
              },
            };
          },
        };
      },
    };
  }

  return {
    docs,
    collection: collectionRef,
    runTransaction(fn) {
      const next = txQueue.then(() => {
        const pendingWrites = [];
        const transaction = {
          get: (ref) => ref.get(),
          set: (ref, value, options) => {
            pendingWrites.push({ ref, value, options });
          },
        };
        return fn(transaction).then(async (result) => {
          for (const write of pendingWrites) {
            await write.ref.set(write.value, write.options);
          }
          return result;
        });
      });
      txQueue = next.catch(() => {});
      return next;
    },
  };
}

function makeDeps(initialDocs = {}) {
  const notifications = [];
  const firestore = createTestFirestore({
    'users/owner-1': { displayName: 'Owner', photoURL: null, email: 'owner@test.com' },
    'users/friend-1': { displayName: 'Friend One', email: 'friend1@test.com' },
    'users/friend-2': { displayName: 'Friend Two', email: 'friend2@test.com' },
    'workspaces/ws-1': { ownerId: 'owner-1', name: 'Design Team' },
    ...initialDocs,
  });
  const handler = createInviteToWorkspaceHandler({
    getFirestore: () => firestore,
    sendUserNotification: async (payload) => {
      notifications.push(payload);
      return { notificationId: `notif-${notifications.length}` };
    },
    serverTimestamp: () => 'SERVER_TIMESTAMP',
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  return { handler, firestore, notifications };
}

test('inviteToWorkspace is idempotent across repeated and concurrent sends', async () => {
  const { handler, firestore, notifications } = makeDeps();

  const [first, second] = await Promise.all([
    handler({
      auth: { uid: 'owner-1' },
      data: { workspaceId: 'ws-1', invitedUserIds: ['friend-1'] },
    }),
    handler({
      auth: { uid: 'owner-1' },
      data: { workspaceId: 'ws-1', invitedUserIds: ['friend-1'] },
    }),
  ]);

  assert.equal(notifications.length, 1);
  assert.equal(first.invitedCount + second.invitedCount, 1);
  assert.equal(first.alreadyInvitedCount + second.alreadyInvitedCount, 1);
  assert.equal(firestore.docs.get('workspace_invites/ws-1_friend-1').status, 'pending');

  const third = await handler({
    auth: { uid: 'owner-1' },
    data: { workspaceId: 'ws-1', invitedUserIds: ['friend-1'] },
  });
  assert.equal(third.invitedCount, 0);
  assert.equal(third.alreadyInvitedCount, 1);
  assert.deepEqual(third.alreadyInvited, ['friend-1']);
  assert.equal(notifications.length, 1);
});

test('inviteToWorkspace skips existing members and allows re-invite after rejection', async () => {
  const { handler, firestore, notifications } = makeDeps({
    'workspaces/ws-1/members/friend-1': { role: 'editor' },
    'workspace_invites/ws-1_friend-2': {
      workspaceId: 'ws-1',
      fromUid: 'owner-1',
      toUid: 'friend-2',
      status: 'rejected',
    },
  });

  const res = await handler({
    auth: { uid: 'owner-1' },
    data: { workspaceId: 'ws-1', invitedUserIds: ['friend-1', 'friend-2'] },
  });

  assert.equal(res.alreadyMemberCount, 1);
  assert.deepEqual(res.alreadyMembers, ['friend-1']);
  assert.equal(res.invitedCount, 1);
  assert.equal(notifications.length, 1);
  assert.equal(notifications[0].recipientUid, 'friend-2');
  assert.equal(firestore.docs.get('workspace_invites/ws-1_friend-2').status, 'pending');
});
