// server/src/history/revert.js
// ONE revert engine, three authorization modes:
//   undo_own (member, own ops within 15 min) | revert_user (owner) | restore_version (owner)
// Reverts are forward compensating CRDT updates appended to the normal stream.
// Element values are LWW per key, so a revert is an element-level set/delete
// (never a general Yjs inverse, D10).
const Y = require('yjs');
const admin = require('firebase-admin');
const r2 = require('./r2');
const { reconstruct, parseStreamFields } = require('./reconstruct');

const UNDO_WINDOW_MS = 15 * 60 * 1000; // D2

function unionKeys(a, b) {
  return [...new Set([...Object.keys(a || {}), ...Object.keys(b || {})])];
}

function inTimeRange(timestampIso, fromTime, toTime) {
  if (!fromTime && !toTime) return true;
  const t = Date.parse(timestampIso || '');
  if (!Number.isFinite(t)) return true;
  if (fromTime) {
    const f = Date.parse(fromTime);
    if (Number.isFinite(f) && t < f) return false;
  }
  if (toTime) {
    const e = Date.parse(toTime);
    if (Number.isFinite(e) && t > e) return false;
  }
  return true;
}

function opMatches(op, opts) {
  if (opts.elementIds && opts.elementIds.length) {
    const ids = new Set(opts.elementIds);
    const touched = (op.changes || []).map(c => c.elementId);
    if (op.elementId) touched.push(op.elementId);
    if (!touched.some(id => ids.has(id))) return false;
  }
  return inTimeRange(op.timestamp, opts.fromTime, opts.toTime);
}

// Replay every op in version order, recording the per-element touch history
// ({version, uid, before, after}) so conflicts can be detected precisely.
async function replayTouches(boardId, redis) {
  const db = admin.firestore();
  const doc = new Y.Doc();
  const elements = doc.getMap('elements');
  const touches = new Map();

  let milestones = [];
  try {
    milestones = await r2.listMilestoneVersions(boardId);
  } catch (_) {
    milestones = [];
  }
  const base = milestones.length ? milestones[milestones.length - 1] : null;
  if (base != null) {
    try {
      const buf = await r2.getBytesGzip(`${boardId}/milestones/state_v${base}.bin.gz`);
      Y.applyUpdate(doc, buf);
    } catch (_) { /* replay from empty */ }
  }

  const ops = [];
  try {
    const idx = await db.collection('boards').doc(boardId)
      .collection('activity_index').orderBy('fromVersion').get();
    for (const d of idx.docs) {
      const b = d.data() || {};
      if (base != null && b.toVersion <= base) continue;
      let blockOps = [];
      try {
        blockOps = await r2.getGzipJson(b.r2BlockKey);
      } catch (_) {
        continue;
      }
      for (const op of (blockOps || [])) {
        if (base != null && op.version <= base) continue;
        ops.push(op);
      }
    }
  } catch (_) { /* no index — rely on the stream */ }

  if (redis) {
    try {
      const raw = await redis.xrange(`board_updates:${boardId}`, '-', '+');
      for (const [, fields] of (raw || [])) {
        const e = parseStreamFields(fields);
        if (base != null && e.version <= base) continue;
        ops.push({
          version: e.version,
          userId: e.sourceClientId,
          elementId: e.elementId || null,
          action: e.action || null,
          payloadBase64: e.payloadBase64,
          timestamp: e.timestamp,
        });
      }
    } catch (_) { /* stream unavailable */ }
  }

  ops.sort((a, b) => a.version - b.version);

  for (const op of ops) {
    if (!op.payloadBase64) continue;
    const before = elements.toJSON();
    try {
      Y.applyUpdate(doc, Buffer.from(op.payloadBase64, 'base64'));
    } catch (_) {
      continue;
    }
    const after = elements.toJSON();
    const changed = [];
    for (const k of Object.keys(after)) {
      if (!(k in before)) changed.push(k);
      else if (JSON.stringify(before[k]) !== JSON.stringify(after[k])) changed.push(k);
    }
    for (const k of Object.keys(before)) if (!(k in after)) changed.push(k);

    for (const elementId of changed) {
      const list = touches.get(elementId) || [];
      list.push({
        version: op.version,
        uid: op.userId || '',
        before: before[elementId],
        after: after[elementId],
        timestamp: op.timestamp,
      });
      touches.set(elementId, list);
    }
  }

  return touches;
}

function analyzeElementHistory(touches, targetUid, opts) {
  const analysis = {};
  const scopedIds = opts.elementIds && opts.elementIds.length
    ? new Set(opts.elementIds)
    : null;

  for (const [elementId, list] of touches.entries()) {
    if (scopedIds && !scopedIds.has(elementId)) continue;
    const mine = list.filter(t => t.uid === targetUid && inTimeRange(t.timestamp, opts.fromTime, opts.toTime));
    if (!mine.length) continue;
    const first = mine[0];
    const conflict = list.some(t => t.version > first.version && t.uid !== targetUid);
    analysis[elementId] = {
      before: first.before,
      firstTouchVersion: first.version,
      conflict,
      lastEditorUid: list[list.length - 1].uid,
    };
  }
  return analysis;
}

// Read one user's ops from archived blocks (whose contributorUids include the
// target) plus the un-archived Redis tail. Ascending by version.
async function collectUserOps(boardId, targetUid, opts = {}, redis) {
  const db = admin.firestore();
  const ops = [];

  try {
    const idx = await db.collection('boards').doc(boardId)
      .collection('activity_index')
      .where('contributorUids', 'array-contains', targetUid)
      .get();
    for (const d of idx.docs) {
      const b = d.data() || {};
      if (!b.r2BlockKey) continue;
      if (opts.fromVersion != null && b.toVersion < opts.fromVersion) continue;
      if (opts.toVersion != null && b.fromVersion > opts.toVersion) continue;
      let blockOps = [];
      try {
        blockOps = await r2.getGzipJson(b.r2BlockKey);
      } catch (_) {
        continue;
      }
      for (const op of (blockOps || [])) {
        if (op.userId !== targetUid) continue;
        if (opts.fromVersion != null && op.version < opts.fromVersion) continue;
        if (opts.toVersion != null && op.version > opts.toVersion) continue;
        if (!opMatches(op, opts)) continue;
        ops.push(op);
      }
    }
  } catch (_) { /* index read failed — stream tail may still answer */ }

  if (redis) {
    try {
      const raw = await redis.xrange(`board_updates:${boardId}`, '-', '+');
      for (const [, fields] of (raw || [])) {
        const e = parseStreamFields(fields);
        if (e.sourceClientId !== targetUid) continue;
        const op = {
          version: e.version,
          updateId: e.updateId,
          userId: e.sourceClientId,
          elementId: e.elementId || null,
          action: e.action || 'upsert',
          payloadBase64: e.payloadBase64,
          timestamp: e.timestamp,
        };
        if (opts.fromVersion != null && op.version < opts.fromVersion) continue;
        if (opts.toVersion != null && op.version > opts.toVersion) continue;
        if (!opMatches(op, opts)) continue;
        ops.push(op);
      }
    } catch (_) { /* stream unavailable */ }
  }

  ops.sort((a, b) => a.version - b.version);
  return ops;
}

// mode: 'restore' (targetVersion) | 'user' (targetUid + optional window/elementIds)
async function buildPlan(boardId, opts, redis, actingUid) {
  const { elementMap: current, version: baseVersion } = await reconstruct(boardId, null, redis);

  let target;
  let scope;
  let analysis = null;

  if (opts.mode === 'restore') {
    const r = await reconstruct(boardId, opts.targetVersion, redis);
    target = r.elementMap;
    scope = unionKeys(current, target);
  } else {
    const touches = await replayTouches(boardId, redis);
    analysis = analyzeElementHistory(touches, opts.targetUid, opts);
    target = { ...current };
    scope = Object.keys(analysis);
    // Conflicted elements are ALSO given a target value (the state before the
    // user's first in-scope op) so the owner can review them per element (D4).
    // They simply default to "keep", so a member's auto-apply skips them.
    for (const [elementId, a] of Object.entries(analysis)) {
      if (a.before === undefined) delete target[elementId];
      else target[elementId] = a.before;
    }
  }

  const items = scope.map((elementId) => {
    const inCur = elementId in current;
    const inTgt = elementId in target;
    const kind = !inTgt ? 'delete' : (!inCur ? 'add' : 'update');
    const conflict = opts.mode === 'user' ? !!(analysis && analysis[elementId]?.conflict) : false;
    const same = JSON.stringify(current[elementId] ?? null) === JSON.stringify(target[elementId] ?? null);
    return {
      elementId,
      kind,
      conflict,
      noop: same,
      before: current[elementId] ?? null,
      after: target[elementId] ?? null,
      lastEditorUid: analysis?.[elementId]?.lastEditorUid ?? null,
    };
  }).filter(item => !item.noop);

  return {
    planId: `plan_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    mode: opts.mode,
    baseVersion,
    actingUid: actingUid || null,
    items,
    _target: target,
    _opts: opts,
  };
}

// decisions: { [elementId]: 'revert' | 'keep' }. Clean items default to revert.
async function applyPlan(boardId, plan, decisions, redis, actingUid) {
  const { doc: curDoc, elementMap: current } = await reconstruct(boardId, null, redis);
  const elements = curDoc.getMap('elements');
  const beforeVector = Y.encodeStateVector(curDoc);
  const applied = [];
  const skipped = [];

  curDoc.transact(() => {
    for (const item of plan.items) {
      const decision = decisions?.[item.elementId] || (item.conflict ? 'keep' : 'revert');
      if (decision !== 'revert') {
        if (item.conflict) skipped.push(item.elementId);
        continue;
      }
      if (item.after === null || item.after === undefined) elements.delete(item.elementId);
      else elements.set(item.elementId, item.after);
      applied.push(item.elementId);
    }
  }, 'server-revert');

  const update = Y.encodeStateAsUpdate(curDoc, beforeVector);
  // `current` is the state AFTER the revert (callers report on the result),
  // not the snapshot that was read before applying it.
  return {
    update,
    baseVersion: plan.baseVersion,
    applied,
    skipped,
    current: elements.toJSON(),
  };
}

module.exports = {
  buildPlan,
  applyPlan,
  collectUserOps,
  analyzeElementHistory,
  replayTouches,
  UNDO_WINDOW_MS,
};
