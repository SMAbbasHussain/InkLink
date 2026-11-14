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
const { describeChange, summarizeOperation, elementNoun } = require('./describe');

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

// Replay ops in version order, recording the per-element touch history
// ({version, uid, before, after}) so conflicts can be detected precisely.
//
// The replay may start from a milestone snapshot (`base`), but that milestone
// must sit BEFORE the earliest op that still matters. D8 puts a milestone at
// the end of every archived block, so "just start from the latest milestone"
// used to skip every archived block and `replayTouches` only ever saw the
// un-archived stream tail — conflict analysis for anything already archived
// came back empty and both undo_own and owner reverts silently found nothing.
//
// When opts.fromTime is given (undo_own always provides it), blocks whose ops
// all predate the window are skippable: conflict detection only needs touches
// from the target's first in-window op onwards, plus the board state right
// before it, which a milestone below the first relevant block supplies. Without
// a fromTime the whole retained history must be replayed.
async function replayTouches(boardId, redis, opts = {}) {
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

  const blocks = [];
  try {
    const idx = await db.collection('boards').doc(boardId)
      .collection('activity_index').orderBy('fromVersion').get();
    for (const d of idx.docs) {
      const b = d.data() || {};
      if (!b.r2BlockKey) continue;
      blocks.push(b);
    }
  } catch (_) { /* no index — rely on the stream */ }

  let base = null;
  {
    // Window start: an absolute version and/or a timestamp. Blocks whose ops
    // all predate the window are skippable: conflict detection only needs
    // touches from the target's first in-window op onwards, plus the board
    // state right before it, which a milestone below the first relevant block
    // supplies. Without a window the whole retained history must be replayed.
    const from = opts.fromTime ? Date.parse(opts.fromTime) : NaN;
    const hasTime = Number.isFinite(from);
    const fromVersion = opts.fromVersion == null
      ? null
      : (Number.isFinite(Number(opts.fromVersion)) ? Number(opts.fromVersion) : null);
    if (hasTime || fromVersion != null) {
      // First block that may contain an in-window op (an unparseable
      // lastOpAt is treated as relevant — never skip what we cannot date).
      let firstRelevant = null;
      for (const b of blocks) {
        const lastAt = Date.parse(b.lastOpAt || '');
        const timeOk = !hasTime || !Number.isFinite(lastAt) || lastAt >= from;
        const versionOk =
          fromVersion == null ||
          (parseInt(b.toVersion, 10) || 0) >= fromVersion;
        if (timeOk && versionOk) {
          firstRelevant = b;
          break;
        }
      }
      if (firstRelevant != null) {
        const candidates = milestones.filter(
          v => v < (parseInt(firstRelevant.fromVersion, 10) || 0),
        );
        base = candidates.length ? candidates[candidates.length - 1] : null;
      } else {
        // Everything archived is older than the window; the latest milestone
        // still seeds a correct base state for the stream tail.
        base = milestones.length ? milestones[milestones.length - 1] : null;
      }
    }
  }

  if (base != null) {
    try {
      const buf = await r2.getBytesGzip(`${boardId}/milestones/state_v${base}.bin.gz`);
      Y.applyUpdate(doc, buf);
    } catch (_) {
      // Without the snapshot we must replay the covered blocks ourselves.
      base = null;
    }
  }

  const ops = [];
  for (const b of blocks) {
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

// Mode 'ops': undo a specific set of logged ops identified by their stream
// versions (per-op revert, multi-select, or the tail of a user's replay).
// Each touched element targets its value right before the EARLIEST selected op
// that touched it, so a selection collapses to one LWW set/delete per element
// (D10). Later edits by a DIFFERENT user that are not themselves selected are
// conflicts — the owner reviews them per element and they default to keep
// (D4). Later edits by the same user are subsumed, exactly like user mode.
function analyzeOpsHistory(touches, selectedVersions) {
  const analysis = {};
  const selected = Array.isArray(selectedVersions) && selectedVersions.length
    ? new Set(selectedVersions.map(Number))
    : null;
  if (!selected || !selected.size) return analysis;

  for (const [elementId, list] of touches.entries()) {
    let first = null;
    for (const t of list) {
      if (selected.has(t.version)) {
        first = t;
        break;
      }
    }
    if (!first) continue;
    const conflict = list.some(
      t => t.version > first.version && t.uid !== first.uid && !selected.has(t.version),
    );
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

// Attach plain-English `detail` per change and a one-line `summary` per op.
//
// Blocks archived before describe.js existed carry no wording, and the Redis
// tail never went through the archiver at all, so both are described here on
// demand. Only the resulting strings are cached (never the element snapshots,
// which can carry base64 image payloads), and the replay is bounded by the
// oldest op that still needs wording: replayTouches seeds from the milestone
// below that point instead of replaying the board's whole life.
const descriptionCache = new Map(); // boardId -> { descriptions: Map, expiresAt }
const DESCRIPTION_TTL_MS = 10 * 60 * 1000;
const DESCRIPTION_CACHE_MAX = 20;

async function describeOps(boardId, ops, redis) {
  const list = ops || [];
  if (!list.some(op => !op.summary)) return list;

  const now = Date.now();
  for (const [key, entry] of descriptionCache.entries()) {
    if (entry.expiresAt <= now) descriptionCache.delete(key);
  }
  let cached = descriptionCache.get(boardId);
  if (!cached) {
    cached = { descriptions: new Map(), expiresAt: now + DESCRIPTION_TTL_MS };
  }

  const missing = list.filter(op => !op.summary && !cached.descriptions.has(op.version));
  if (missing.length) {
    let fromTime = null;
    for (const op of missing) {
      const t = Date.parse(op.timestamp || '');
      if (!Number.isFinite(t)) continue;
      const iso = new Date(t).toISOString();
      if (fromTime == null || iso < fromTime) fromTime = iso;
    }

    const byVersion = new Map();
    try {
      const touches = await replayTouches(boardId, redis, fromTime ? { fromTime } : {});
      for (const [elementId, touchList] of touches.entries()) {
        for (const touch of touchList) {
          let perElement = byVersion.get(touch.version);
          if (!perElement) {
            perElement = new Map();
            byVersion.set(touch.version, perElement);
          }
          perElement.set(elementId, { before: touch.before, after: touch.after });
        }
      }
    } catch (_) {
      // Without a replay we can still label ops from their recorded kinds.
    }

    for (const op of missing) {
      const snapshots = byVersion.get(op.version) || new Map();
      const recorded = Array.isArray(op.changes) ? op.changes : [];
      const ids = recorded.length ? recorded.map(c => c.elementId) : [...snapshots.keys()];

      const changes = ids.map((elementId) => {
        const snap = snapshots.get(elementId);
        const recordedKind = recorded.find(c => c.elementId === elementId)?.kind;
        if (!snap) {
          const kind = recordedKind || 'update';
          const verb = kind === 'add' ? 'Added' : (kind === 'delete' ? 'Removed' : 'Updated');
          return { elementId, kind, detail: `${verb} an element` };
        }
        const described = describeChange(snap.before, snap.after);
        return { elementId, kind: recordedKind || described.kind, detail: described.detail };
      });

      cached.descriptions.set(op.version, {
        changes,
        summary: summarizeOperation(op, changes),
      });
    }
  }

  for (const op of list) {
    if (op.summary) continue;
    const described = cached.descriptions.get(op.version);
    if (!described) continue;
    op.changes = described.changes;
    op.summary = described.summary;
  }

  cached.expiresAt = now + DESCRIPTION_TTL_MS;
  descriptionCache.delete(boardId);
  descriptionCache.set(boardId, cached);
  while (descriptionCache.size > DESCRIPTION_CACHE_MAX) {
    descriptionCache.delete(descriptionCache.keys().next().value);
  }
  return list;
}

// mode: 'restore' (targetVersion) | 'user' (targetUid + optional window/elementIds)
//    | 'ops' (opVersions — undo specific logged ops, or targetUid +
//      afterVersion + elementIds — undo that user's in-scope ops after a
//      version, the owner's "restore partway between a request's requested
//      state and the current state")
async function buildPlan(boardId, opts, redis, actingUid) {
  const { elementMap: current, version: baseVersion } = await reconstruct(boardId, null, redis);

  let target;
  let scope;
  let analysis = null;

  if (opts.mode === 'restore') {
    const r = await reconstruct(boardId, opts.targetVersion, redis);
    target = r.elementMap;
    scope = unionKeys(current, target);
  } else if (opts.mode === 'ops') {
    // Selected ops: either an explicit list of stream versions, or (ops-scope
    // mode) everything the target user did to the scope elements after
    // afterVersion — collected here so the client only names the window.
    let selectedVersions = Array.isArray(opts.opVersions)
      ? opts.opVersions.map(Number).filter(Number.isFinite)
      : [];
    if (!selectedVersions.length && opts.targetUid) {
      const after = opts.afterVersion == null
        ? null
        : (Number.isFinite(Number(opts.afterVersion))
            ? Math.trunc(Number(opts.afterVersion))
            : null);
      if (after == null) {
        throw new Error('ops plan needs opVersions or afterVersion');
      }
      const userOps = await collectUserOps(
        boardId,
        opts.targetUid,
        {
          fromVersion: after + 1,
          ...(Array.isArray(opts.elementIds) && opts.elementIds.length
            ? { elementIds: opts.elementIds }
            : {}),
        },
        redis,
      );
      selectedVersions = userOps.map(op => op.version);
    }
    // The replay only needs the board from just before the earliest selected
    // op: a milestone below it seeds the base state (fromVersion semantics).
    const touches = await replayTouches(boardId, redis, {
      ...opts,
      ...(selectedVersions.length
        ? { fromVersion: Math.min(...selectedVersions) }
        : {}),
    });
    analysis = analyzeOpsHistory(touches, selectedVersions);
    target = { ...current };
    scope = Object.keys(analysis);
    for (const [elementId, a] of Object.entries(analysis)) {
      if (a.before === undefined) delete target[elementId];
      else target[elementId] = a.before;
    }
  } else {
    const touches = await replayTouches(boardId, redis, opts);
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
    const conflicted =
      (opts.mode === 'user' || opts.mode === 'ops') &&
      !!(analysis && analysis[elementId]?.conflict);
    const same = JSON.stringify(current[elementId] ?? null) === JSON.stringify(target[elementId] ?? null);
    // `before` is the live board, `after` is what applying the revert produces,
    // so this reads as the change the owner is about to approve.
    const described = describeChange(current[elementId] ?? null, target[elementId] ?? null);
    return {
      elementId,
      kind,
      conflict: conflicted,
      noop: same,
      before: current[elementId] ?? null,
      after: target[elementId] ?? null,
      lastEditorUid: analysis?.[elementId]?.lastEditorUid ?? null,
      label: elementNoun(target[elementId] ?? current[elementId]),
      summary: described.detail,
      fields: described.fields,
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
  describeOps,
  analyzeElementHistory,
  analyzeOpsHistory,
  replayTouches,
  UNDO_WINDOW_MS,
};
