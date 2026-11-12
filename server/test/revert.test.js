// Unit tests for the board history revert engine.
//
// These encode the contract from BOARD_VERSION_HISTORY_AND_AUDIT_LOG_PLAN.md:
//   §4.7  one engine, three authorization modes
//   D4    conflicted elements are surfaced for per-element review
//   D10   reverts are element-level set/delete, never Yjs inverses
// The module's I/O (R2, Firestore, Redis) is stubbed so the engine itself is
// what gets exercised.
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

const state = {
  elementMap: {},
  version: 0,
  versioned: {}, // version -> elementMap
  streamEntries: [],
  blocks: [],
};

stub('../src/history/reconstruct', {
  reconstruct: async (_boardId, targetVersion) => {
    if (targetVersion == null) {
      return {
        doc: makeDoc(state.elementMap),
        elementMap: clone(state.elementMap),
        version: state.version,
      };
    }
    const map = state.versioned[targetVersion] || {};
    return {
      doc: makeDoc(map),
      elementMap: clone(map),
      version: targetVersion,
    };
  },
  parseStreamFields: (fields) => fields,
});

stub('../src/history/r2', {
  listMilestoneVersions: async () => [],
  getBytesGzip: async () => {
    throw new Error('no milestone in unit tests');
  },
  getGzipJson: async () => state.blocks,
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

function clone(value) {
  return JSON.parse(JSON.stringify(value ?? null));
}

function makeDoc(elementMap) {
  const doc = new Y.Doc();
  const map = doc.getMap('elements');
  for (const [id, value] of Object.entries(elementMap || {})) map.set(id, value);
  return doc;
}

const revert = require('../src/history/revert');
const { analyzeElementHistory, buildPlan, applyPlan, UNDO_WINDOW_MS } = revert;

const NOW = new Date().toISOString();
const OLD = new Date(Date.now() - UNDO_WINDOW_MS - 60_000).toISOString();

function reset() {
  state.elementMap = {};
  state.version = 0;
  state.versioned = {};
  state.streamEntries = [];
  state.blocks = [];
}

function redisWith(entries) {
  return { xrange: async () => entries.map((e) => [String(e.version), e]) };
}

// ── analyzeElementHistory ───────────────────────────────────────────────────
test('analyzeElementHistory records the pre-edit value and detects conflicts', () => {
  const touches = new Map([
    [
      'a',
      [
        { version: 1, uid: 'A', before: undefined, after: { x: 1 }, timestamp: NOW },
        { version: 4, uid: 'B', before: { x: 1 }, after: { x: 2 }, timestamp: NOW },
      ],
    ],
    [
      'b',
      [{ version: 2, uid: 'A', before: { x: 0 }, after: { x: 9 }, timestamp: NOW }],
    ],
    [
      'c',
      [{ version: 1, uid: 'B', before: undefined, after: { x: 1 }, timestamp: NOW }],
    ],
  ]);

  const analysis = analyzeElementHistory(touches, 'A', {});
  assert.deepEqual(Object.keys(analysis).sort(), ['a', 'b']);
  assert.equal(analysis.a.conflict, true, 'later edit by another user is a conflict');
  assert.equal(analysis.b.conflict, false);
  assert.equal(analysis.b.before.x, 0);
  assert.equal(analysis.a.lastEditorUid, 'B');
});

test('analyzeElementHistory honours the 15-minute window and element scope', () => {
  const touches = new Map([
    [
      'stale',
      [{ version: 1, uid: 'A', before: {}, after: { x: 1 }, timestamp: OLD }],
    ],
    [
      'fresh',
      [{ version: 2, uid: 'A', before: {}, after: { x: 1 }, timestamp: NOW }],
    ],
    [
      'other',
      [{ version: 3, uid: 'A', before: {}, after: { x: 1 }, timestamp: NOW }],
    ],
  ]);

  const windowed = analyzeElementHistory(touches, 'A', { fromTime: NOW });
  assert.deepEqual(Object.keys(windowed).sort(), ['fresh', 'other']);

  const scoped = analyzeElementHistory(touches, 'A', { elementIds: ['fresh'] });
  assert.deepEqual(Object.keys(scoped), ['fresh']);
});

test('analyzeElementHistory ignores elements the user never touched', () => {
  const touches = new Map([
    ['x', [{ version: 1, uid: 'B', before: {}, after: {}, timestamp: NOW }]],
  ]);
  assert.deepEqual(analyzeElementHistory(touches, 'A', {}), {});
});

// ── buildPlan / applyPlan: user mode ────────────────────────────────────────
test('member undo offers conflicts for review but only applies clean items', async () => {
  reset();
  const d = new Y.Doc();
  const m = d.getMap('elements');
  const capture = (fn) => {
    const vector = Y.encodeStateVector(d);
    fn();
    return Buffer.from(Y.encodeStateAsUpdate(d, vector)).toString('base64');
  };

  // A creates a + b; B then changes b.
  const p1 = capture(() => m.set('a', { id: 'a', type: 'rect', x: 1 }));
  const p2 = capture(() => m.set('b', { id: 'b', type: 'rect', x: 1 }));
  const p3 = capture(() => m.set('b', { id: 'b', type: 'rect', x: 2 }));
  m.set('c', { id: 'c', type: 'rect', x: 5 });
  // The committed board (what `reconstruct` would return) after those ops.
  state.elementMap = {
    a: { id: 'a', type: 'rect', x: 1 },
    b: { id: 'b', type: 'rect', x: 2 },
    c: { id: 'c', type: 'rect', x: 5 },
  };

  const entries = [
    { version: 1, updateId: 'u1', sourceClientId: 'A', elementId: 'a', action: 'upsert', payloadBase64: p1, timestamp: NOW },
    { version: 2, updateId: 'u2', sourceClientId: 'A', elementId: 'b', action: 'upsert', payloadBase64: p2, timestamp: NOW },
    { version: 3, updateId: 'u3', sourceClientId: 'B', elementId: 'b', action: 'upsert', payloadBase64: p3, timestamp: NOW },
  ];

  const plan = await buildPlan(
    'board-1',
    { mode: 'user', targetUid: 'A', fromTime: NOW },
    redisWith(entries),
    'A',
  );

  const byId = Object.fromEntries(plan.items.map((i) => [i.elementId, i]));
  assert.ok(byId.a, 'clean element is in the plan');
  assert.equal(byId.a.conflict, false);
  assert.ok(byId.b, 'conflicted element must still be offered (D4)');
  assert.equal(byId.b.conflict, true);
  assert.equal(byId.b.after, null, 'target is the value before A touched it');
  assert.equal(byId.c, undefined, 'untouched elements stay out of the plan');

  const { applied, skipped } = await applyPlan('board-1', plan, undefined, redisWith(entries), 'A');
  assert.deepEqual(applied, ['a'], 'auto-apply only touches clean items');
  assert.deepEqual(skipped, ['b']);
});

test('owner decisions override the defaults (keep a clean item, revert a conflict)', async () => {
  reset();
  state.elementMap = {
    a: { id: 'a', type: 'rect', x: 2 },
    b: { id: 'b', type: 'rect', x: 2 },
  };
  const plan = {
    planId: 'p',
    mode: 'user',
    baseVersion: 9,
    items: [
      { elementId: 'a', kind: 'update', conflict: false, before: { x: 2 }, after: { x: 1 } },
      { elementId: 'b', kind: 'update', conflict: true, before: { x: 2 }, after: { x: 1 } },
    ],
  };

  const { applied, skipped } = await applyPlan(
    'board-1',
    plan,
    { a: 'keep', b: 'revert' },
    redisWith([]),
    'owner',
  );
  assert.deepEqual(applied, ['b']);
  // `skipped` reports elements kept *because someone else changed them* — a
  // clean element the owner deliberately keeps is simply not applied.
  assert.deepEqual(skipped, []);
});

test('applyPlan deletes an element whose target value is null', async () => {
  reset();
  state.elementMap = { a: { id: 'a', type: 'rect', x: 2 } };
  const plan = {
    planId: 'p',
    mode: 'user',
    baseVersion: 1,
    items: [{ elementId: 'a', kind: 'delete', conflict: false, before: { x: 2 }, after: null }],
  };

  const result = await applyPlan('board-1', plan, { a: 'revert' }, redisWith([]), 'owner');
  assert.deepEqual(result.applied, ['a']);
  assert.equal(result.current.a, undefined, 'null target removes the element');
});

// ── buildPlan / applyPlan: restore mode ────────────────────────────────────
test('restore plan diffs the current board against the requested version', async () => {
  reset();
  state.elementMap = {
    a: { id: 'a', type: 'rect', x: 2 },
    b: { id: 'b', type: 'rect', x: 9 },
    c: { id: 'c', type: 'rect', x: 7 },
  };
  state.version = 10;
  state.versioned[3] = {
    a: { id: 'a', type: 'rect', x: 1 },
    c: { id: 'c', type: 'rect', x: 7 },
    d: { id: 'd', type: 'rect', x: 4 },
  };

  const plan = await buildPlan('board-1', { mode: 'restore', targetVersion: 3 }, redisWith([]), 'owner');
  const byId = Object.fromEntries(plan.items.map((i) => [i.elementId, i]));

  assert.equal(plan.baseVersion, 10);
  assert.equal(byId.a.kind, 'update');
  assert.equal(byId.b.kind, 'delete', 'element missing from the old version is removed');
  assert.equal(byId.d.kind, 'add', 'element present only in the old version comes back');
  assert.equal(byId.c, undefined, 'identical elements are not part of the plan');
  assert.equal(plan.items.every((i) => i.conflict === false), true);

  const result = await applyPlan('board-1', plan, undefined, redisWith([]), 'owner');
  assert.deepEqual(result.applied.sort(), ['a', 'b', 'd']);
});

test('a plan with nothing to change yields no items', async () => {
  reset();
  state.elementMap = { a: { id: 'a', type: 'rect', x: 1 } };
  state.version = 4;
  state.versioned[2] = { a: { id: 'a', type: 'rect', x: 1 } };

  const plan = await buildPlan('board-1', { mode: 'restore', targetVersion: 2 }, redisWith([]), 'owner');
  assert.deepEqual(plan.items, []);
});
