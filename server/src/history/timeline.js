// server/src/history/timeline.js
// Builds the owner's per-user replay timeline: the user's ops in order, the
// board state just before the page's first op, and a board-state delta at
// every op of the page so the client can scrub back and forth with no further
// round-trips.
//
// Deltas are captured during ONE replay pass through the version range, so
// step N is the true historical board state — other users' concurrent edits
// between the target's ops are included — never a synthetic "only this
// user's writes" state. Tail ops that have not been archived yet get their
// plain-English labels computed from the same pass (the archiver only words
// ops when it closes a block).
const Y = require('yjs');
const { reconstruct, loadOpsInRange } = require('./reconstruct');
const { collectUserOps } = require('./revert');
const { describeChange, summarizeOperation } = require('./describe');

const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 200;

async function buildUserTimeline(boardId, targetUid, opts = {}, redis) {
  const limit = Math.max(
    1,
    Math.min(MAX_PAGE_SIZE, Number(opts.limit) || DEFAULT_PAGE_SIZE),
  );

  // Undo-request scope (D5): only the ops that touched these elements. The
  // member picks an area or double-taps elements client-side; the resolved
  // element ids are the scope for both the ops and the captured deltas.
  const elementIds = Array.isArray(opts.elementIds)
    ? opts.elementIds.filter(id => typeof id === 'string' && id)
    : null;
  // Evidence window (undo requests): replay only what happened AFTER this
  // version, and anchor the base exactly there so stop 0 is the requested
  // state rather than "just before the user's next op".
  const afterVersion = opts.afterVersion == null
    ? null
    : (Number.isFinite(Number(opts.afterVersion))
        ? Math.trunc(Number(opts.afterVersion))
        : null);

  // Ascending by version (collectUserOps sorts).
  const all = await collectUserOps(
    boardId,
    targetUid,
    {
      fromTime: opts.fromTime,
      toTime: opts.toTime,
      ...(elementIds && elementIds.length ? { elementIds } : {}),
    },
    redis,
  );
  let candidates = all;
  if (afterVersion != null) {
    candidates = candidates.filter(op => op.version > afterVersion);
  }
  if (opts.beforeVersion != null) {
    const before = Number(opts.beforeVersion);
    if (Number.isFinite(before)) {
      candidates = candidates.filter(op => op.version < before);
    }
  }
  // First page = the most recent window of the remaining ops; pages go back
  // in time with beforeVersion cursors.
  const page = candidates.slice(Math.max(0, candidates.length - limit));
  const hasMore = candidates.length > page.length;
  const nextBeforeVersion = page.length ? page[0].version : null;
  if (!page.length) {
    return { ops: [], hasMore, nextBeforeVersion: null, base: null, steps: [] };
  }

  const firstVersion = page[0].version;
  const lastVersion = page[page.length - 1].version;
  const baseVersion = afterVersion != null ? afterVersion : firstVersion - 1;
  const stopVersions = new Set(page.map(op => op.version));
  const pageByVersion = new Map(page.map(op => [op.version, op]));
  const needsLabel = new Set(
    page.filter(op => !op.summary).map(op => op.version),
  );

  // Board state at the scrub's base — "just before the page's first op"
  // (versions are contiguous: INCR per op), or exactly the requested state
  // when an evidence window is anchored at afterVersion. Deltas replay every
  // op in between, so other users' concurrent edits inside the window stay
  // part of the true historical states.
  const base = await reconstruct(boardId, baseVersion, redis);
  const doc = base.doc;
  const elements = doc.getMap('elements');
  const toBase64 = (buf) => Buffer.from(buf).toString('base64');
  const baseStateUpdate = toBase64(Y.encodeStateAsUpdate(doc));

  const rangeOps = await loadOpsInRange(
    boardId,
    baseVersion + 1,
    lastVersion,
    redis,
  );
  const steps = [];
  let vector = Y.encodeStateVector(doc); // state at baseVersion

  for (const op of rangeOps) {
    if (!op.payloadBase64) continue;
    const isStop = stopVersions.has(op.version);
    let before = null;
    if (isStop && needsLabel.has(op.version)) before = elements.toJSON();
    try {
      Y.applyUpdate(doc, Buffer.from(op.payloadBase64, 'base64'));
    } catch (_) {
      continue;
    }
    if (!isStop) continue;

    // Delta relative to the previous stop (or the base): applying base +
    // steps[0..i] reproduces the board exactly as it was at this version.
    steps.push({
      version: op.version,
      stateUpdate: toBase64(Y.encodeStateAsUpdate(doc, vector)),
    });
    vector = Y.encodeStateVector(doc);

    if (needsLabel.has(op.version)) {
      const after = elements.toJSON();
      const changes = [];
      for (const key of Object.keys(after)) {
        if (!(key in before)) {
          changes.push({ elementId: key, kind: 'add', detail: describeChange(undefined, after[key]).detail });
        } else if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
          changes.push({ elementId: key, kind: 'update', detail: describeChange(before[key], after[key]).detail });
        }
      }
      for (const key of Object.keys(before)) {
        if (!(key in after)) {
          changes.push({ elementId: key, kind: 'delete', detail: describeChange(before[key], undefined).detail });
        }
      }
      // Write the wording back onto the PAGE op — the ops replayed here are
      // loadOpsInRange's own copies, not the objects being returned.
      const pageOp = pageByVersion.get(op.version);
      if (pageOp) {
        pageOp.changes = changes;
        pageOp.summary = summarizeOperation(pageOp, changes);
      }
    }
  }

  return {
    ops: page,
    hasMore,
    nextBeforeVersion,
    base: { version: baseVersion, stateUpdate: baseStateUpdate },
    steps,
  };
}

module.exports = { buildUserTimeline, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE };
