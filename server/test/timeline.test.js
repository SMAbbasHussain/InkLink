// Unit tests for the per-user scrub timeline builder.
//
// The contract: the timeline returns the user's ops in order, the board state
// just before the first of them, and a board-state delta per op captured in
// one replay pass — so a client replaying base + deltas reproduces the exact
// historical board (including other users' concurrent edits between the
// target's ops), and un-archived ops get plain-English labels.
const test = require('node:test');
const assert = require('node:assert/strict');
const Y = require('yjs');

// ── module stubs ────────────────────────────────────────────────────────────
function stub(modulePath, exports) {
  const resolved = require.resolve(modulePath);
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports,
  };
}

stub('../src/history/r2', {
  listMilestoneVersions: async () => [],
  getBytesGzip: async () => {
    throw new Error('no milestone in unit tests');
  },
  getGzipJson: async () => [],
});

stub('firebase-admin', {
  firestore: () => ({
    collection: () => ({
      doc: () => ({
        collection: () => ({
          orderBy: () => emptyQuery(),
          where: () => emptyQuery(),
          doc: () => ({ get: async () => ({ exists: false }) }),
        }),
      }),
    }),
  }),
});

function emptyQuery() {
  const q = {
    orderBy: () => q,
    where: () => q,
    get: async () => ({ docs: [] }),
  };
  return q;
}

const { buildUserTimeline } = require('../src/history/timeline');

const NOW = new Date().toISOString();

// Real Redis xrange shape — the timeline uses the REAL reconstruct, which
// parses stream fields as a flat key/value array.
function redisWith(entries) {
  return {
    xrange: async () => entries.map((e) => [
      `${String(e.version).padStart(15, '0')}-0`,
      [
        'version', e.version,
        'updateId', e.updateId,
        'payloadBase64', e.payloadBase64,
        'elementId', e.elementId,
        'sourceClientId', e.sourceClientId,
        'timestamp', e.timestamp,
        '_singleUser', e.sourceClientId,
        'userDisplayName', 'User',
        'action', e.action || 'upsert',
      ],
    ]),
  };
}

function captureUpdate(doc, fn) {
  const vector = Y.encodeStateVector(doc);
  fn();
  return Buffer.from(Y.encodeStateAsUpdate(doc, vector)).toString('base64');
}

test('user timeline captures the true board state at every op of the target', async () => {
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const p1 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const p2 = captureUpdate(d, () => m.set('b', { id: 'b', type: 'rect', x: 4 }));
  const p3 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 9 }));
  const p4 = captureUpdate(d, () => m.set('c', { id: 'c', type: 'rect', x: 5 }));
  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', payloadBase64: p1, timestamp: NOW },
    { version: 2, updateId: 'u2', sourceClientId: 'A', elementId: 'b', payloadBase64: p2, timestamp: NOW },
    { version: 3, updateId: 'u3', sourceClientId: 'C', elementId: 'a', payloadBase64: p3, timestamp: NOW },
    { version: 4, updateId: 'u4', sourceClientId: 'A', elementId: 'c', payloadBase64: p4, timestamp: NOW },
  ];

  const timeline = await buildUserTimeline('board-1', 'A', {}, redisWith(entries));
  assert.deepEqual(timeline.ops.map((op) => op.version), [1, 2, 4]);
  assert.deepEqual(timeline.steps.map((s) => s.version), [1, 2, 4]);
  assert.equal(timeline.base.version, 0);
  assert.equal(timeline.hasMore, false);
  // Tail ops are not archived, so the pass must word them itself.
  assert.ok(timeline.ops.every((op) => typeof op.summary === 'string' && op.summary.length > 0));
  assert.ok(timeline.ops.every((op) => Array.isArray(op.changes) && op.changes.length > 0));

  // Replaying base + deltas reproduces the exact historical states.
  const doc = new Y.Doc();
  Y.applyUpdate(doc, Buffer.from(timeline.base.stateUpdate, 'base64'));
  const seen = [Object.keys(doc.getMap('elements').toJSON()).sort()];
  for (const step of timeline.steps) {
    Y.applyUpdate(doc, Buffer.from(step.stateUpdate, 'base64'));
    seen.push(Object.keys(doc.getMap('elements').toJSON()).sort());
  }
  assert.deepEqual(seen[0], [], 'base is the board before the first op');
  assert.deepEqual(seen[1], ['a']);
  assert.deepEqual(seen[2], ['a', 'b']);
  assert.deepEqual(seen[3], ['a', 'b', 'c']);
  const final = doc.getMap('elements').toJSON();
  assert.equal(final.a.x, 9, "C's intervening edit between A's ops is included");
  assert.equal(final.c.x, 5);
});

test('user timeline pages backwards with beforeVersion and a limited page', async () => {
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const p1 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const p2 = captureUpdate(d, () => m.set('b', { id: 'b', type: 'rect', x: 4 }));
  const p3 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 9 }));
  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', payloadBase64: p1, timestamp: NOW },
    { version: 2, updateId: 'u2', sourceClientId: 'A', elementId: 'b', payloadBase64: p2, timestamp: NOW },
    { version: 3, updateId: 'u3', sourceClientId: 'A', elementId: 'a', payloadBase64: p3, timestamp: NOW },
  ];

  const page = await buildUserTimeline('board-1', 'A', { limit: 2 }, redisWith(entries));
  assert.deepEqual(page.ops.map((op) => op.version), [2, 3], 'first page is the most recent ops');
  assert.equal(page.base.version, 1, 'base sits right before the page starts');
  assert.equal(page.hasMore, true);
  assert.equal(page.nextBeforeVersion, 2);

  const older = await buildUserTimeline(
    'board-1',
    'A',
    { limit: 2, beforeVersion: page.nextBeforeVersion },
    redisWith(entries),
  );
  assert.deepEqual(older.ops.map((op) => op.version), [1]);
  assert.equal(older.hasMore, false);
  assert.equal(older.base.version, 0);
});

test('user timeline with no ops returns an empty page without a base', async () => {
  const timeline = await buildUserTimeline('board-1', 'A', {}, redisWith([]));
  assert.deepEqual(timeline.ops, []);
  assert.equal(timeline.hasMore, false);
  assert.equal(timeline.base, null);
  assert.deepEqual(timeline.steps, []);
});

test('user timeline honours an element scope for the stops but keeps true states', async () => {
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const p1 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const p2 = captureUpdate(d, () => m.set('b', { id: 'b', type: 'rect', x: 4 }));
  const p3 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 9 }));
  const p4 = captureUpdate(d, () => m.set('b', { id: 'b', type: 'rect', x: 6 }));
  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', payloadBase64: p1, timestamp: NOW },
    { version: 2, updateId: 'u2', sourceClientId: 'A', elementId: 'b', payloadBase64: p2, timestamp: NOW },
    { version: 3, updateId: 'u3', sourceClientId: 'A', elementId: 'a', payloadBase64: p3, timestamp: NOW },
    { version: 4, updateId: 'u4', sourceClientId: 'A', elementId: 'b', payloadBase64: p4, timestamp: NOW },
  ];

  // Scope = element b: only A's ops that touched b are stops.
  const timeline = await buildUserTimeline(
    'board-1',
    'A',
    { elementIds: ['b'] },
    redisWith(entries),
  );
  assert.deepEqual(timeline.ops.map((op) => op.version), [2, 4]);
  assert.deepEqual(timeline.steps.map((s) => s.version), [2, 4]);
  assert.equal(timeline.base.version, 1, 'base sits right before the first scoped stop');

  // The base still holds A's earlier out-of-scope edit (v1, element a); the
  // scope filters the STOPS, not reality.
  const baseDoc = new Y.Doc();
  Y.applyUpdate(baseDoc, Buffer.from(timeline.base.stateUpdate, 'base64'));
  assert.deepEqual(
    Object.keys(baseDoc.getMap('elements').toJSON()).sort(),
    ['a'],
  );

  // The state at stop v2 is still the TRUE board (element a exists too, from
  // the unfiltered op in between) — the scope filters stops, not reality.
  const doc = new Y.Doc();
  Y.applyUpdate(doc, Buffer.from(timeline.base.stateUpdate, 'base64'));
  Y.applyUpdate(doc, Buffer.from(timeline.steps[0].stateUpdate, 'base64'));
  assert.deepEqual(
    Object.keys(doc.getMap('elements').toJSON()).sort(),
    ['a', 'b'],
    'replay between stops includes every op in the window',
  );
  assert.equal(doc.getMap('elements').toJSON().b.x, 4);
});

test('user timeline anchors afterVersion: base is the requested state', async () => {
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const p1 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const p2 = captureUpdate(d, () => m.set('b', { id: 'b', type: 'rect', x: 4 }));
  const p3 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 9 }));
  const p4 = captureUpdate(d, () => m.set('c', { id: 'c', type: 'rect', x: 5 }));
  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', payloadBase64: p1, timestamp: NOW },
    { version: 2, updateId: 'u2', sourceClientId: 'A', elementId: 'b', payloadBase64: p2, timestamp: NOW },
    { version: 3, updateId: 'u3', sourceClientId: 'A', elementId: 'a', payloadBase64: p3, timestamp: NOW },
    { version: 4, updateId: 'u4', sourceClientId: 'A', elementId: 'c', payloadBase64: p4, timestamp: NOW },
  ];

  // Evidence window: everything after v2, base = the state at v2.
  const timeline = await buildUserTimeline(
    'board-1',
    'A',
    { afterVersion: 2 },
    redisWith(entries),
  );
  assert.deepEqual(timeline.ops.map((op) => op.version), [3, 4]);
  assert.deepEqual(timeline.steps.map((s) => s.version), [3, 4]);
  assert.equal(timeline.base.version, 2, 'base sits exactly at the anchor');

  const doc = new Y.Doc();
  Y.applyUpdate(doc, Buffer.from(timeline.base.stateUpdate, 'base64'));
  const baseState = doc.getMap('elements').toJSON();
  assert.deepEqual(Object.keys(baseState).sort(), ['a', 'b']);
  assert.equal(baseState.a.x, 1, 'base is v2, not "just before v3"');
});

test('user timeline scoped + anchored returns an empty page past the anchor', async () => {
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const p1 = captureUpdate(d, () => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', payloadBase64: p1, timestamp: NOW },
  ];
  const timeline = await buildUserTimeline(
    'board-1',
    'A',
    { afterVersion: 1 },
    redisWith(entries),
  );
  assert.deepEqual(timeline.ops, []);
  assert.equal(timeline.hasMore, false);
  assert.equal(timeline.base, null);
});
