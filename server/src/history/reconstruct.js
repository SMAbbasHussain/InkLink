// server/src/history/reconstruct.js
// Rebuild the element map (and Y.Doc) at a target version from the nearest
// milestone checkpoint + at most one block of archived ops + the un-archived
// Redis stream tail. Re-applying a CRDT update is idempotent, so overlapping
// block/stream ranges are safe (do NOT add dedup that could drop an op).
const Y = require('yjs');
const admin = require('firebase-admin');
const r2 = require('./r2');

function parseStreamFields(fields) {
  const obj = {};
  for (let i = 0; i < fields.length; i += 2) obj[fields[i]] = fields[i + 1];
  if (obj.version) obj.version = parseInt(obj.version, 10);
  return obj;
}

async function readStream(redis, boardId) {
  if (!redis) return [];
  try {
    const raw = await redis.xrange(`board_updates:${boardId}`, '-', '+');
    return (raw || []).map(([, fields]) => parseStreamFields(fields));
  } catch (_) {
    return [];
  }
}

function applyBase64(doc, payloadBase64) {
  if (!payloadBase64) return;
  try {
    Y.applyUpdate(doc, Buffer.from(payloadBase64, 'base64'));
  } catch (_) {
    /* corrupt/partial update — skip, the rest still replays */
  }
}

// Fast path used for "current state": snapshot/latest + the stream tail.
async function reconstructCurrentFromSnapshot(boardId, redis) {
  const db = admin.firestore();
  let snapshotVersion = 0;
  let found = false;
  try {
    const snap = await db.collection('boards').doc(boardId)
      .collection('snapshot').doc('latest').get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (data.stateUpdate) {
        const doc = new Y.Doc();
        Y.applyUpdate(doc, Buffer.from(data.stateUpdate, 'base64'));
        snapshotVersion = parseInt(data.lastAppliedVersion || 0, 10);
        const tail = await readStream(redis, boardId);
        let maxVersion = snapshotVersion;
        for (const entry of tail) {
          if (entry.version > snapshotVersion) {
            applyBase64(doc, entry.payloadBase64);
            if (entry.version > maxVersion) maxVersion = entry.version;
          }
        }
        let currentVersion = maxVersion;
        if (redis) {
          const v = parseInt(await redis.get(`board:${boardId}:version`) || '0', 10);
          if (Number.isFinite(v) && v > currentVersion) currentVersion = v;
        }
        return { doc, elementMap: doc.getMap('elements').toJSON(), version: currentVersion };
      }
      found = true;
    }
  } catch (_) {
    /* fall through to a full R2 replay */
  }
  if (!found) return null;
  return null;
}

// Returns { doc, elementMap, version } at targetVersion (or current if null).
async function reconstruct(boardId, targetVersion, redis) {
  if (targetVersion == null) {
    const fast = await reconstructCurrentFromSnapshot(boardId, redis);
    if (fast) return fast;
  }

  const db = admin.firestore();
  const doc = new Y.Doc();

  // 1. Choose base: latest milestone <= targetVersion, else empty.
  let milestones = [];
  try {
    milestones = await r2.listMilestoneVersions(boardId);
  } catch (e) {
    milestones = [];
  }
  const base = targetVersion == null
    ? null
    : (milestones.filter(v => v <= targetVersion).pop() ?? null);
  if (base != null) {
    try {
      const buf = await r2.getBytesGzip(`${boardId}/milestones/state_v${base}.bin.gz`);
      Y.applyUpdate(doc, buf);
    } catch (_) {
      /* missing checkpoint — replay from empty below */
    }
  }

  // 2. Apply archived blocks with version > base and <= target.
  let blocks = [];
  try {
    const idx = await db.collection('boards').doc(boardId)
      .collection('activity_index').orderBy('fromVersion').get();
    blocks = idx.docs.map(d => d.data()).filter(Boolean);
  } catch (_) {
    blocks = [];
  }
  for (const b of blocks) {
    if (base != null && b.toVersion <= base) continue;
    if (targetVersion != null && b.fromVersion > targetVersion) break;
    let ops = [];
    try {
      ops = await r2.getGzipJson(b.r2BlockKey);
    } catch (_) {
      continue;
    }
    for (const op of (ops || [])) {
      if (base != null && op.version <= base) continue;
      if (targetVersion != null && op.version > targetVersion) continue;
      applyBase64(doc, op.payloadBase64);
    }
  }

  // 3. Apply the un-archived stream tail.
  for (const entry of await readStream(redis, boardId)) {
    if (base != null && entry.version <= base) continue;
    if (targetVersion != null && entry.version > targetVersion) continue;
    applyBase64(doc, entry.payloadBase64);
  }

  const elementMap = doc.getMap('elements').toJSON();
  let version = targetVersion;
  if (version == null) {
    version = 0;
    try {
      version = parseInt(await redis.get(`board:${boardId}:version`) || '0', 10) || 0;
    } catch (_) { /* ignore */ }
  }
  return { doc, elementMap, version };
}

// Every op with fromVersion <= version <= toVersion, ascending, from archived
// blocks + the un-archived stream tail. The timeline builder replays a range
// once and captures board states at chosen stops, so it needs the raw op list
// (not just a single reconstructed snapshot). Blocks that fail to load are
// skipped, mirroring reconstruct's tolerance; a version seen in both a block
// and the stream is applied once (first record wins).
async function loadOpsInRange(boardId, fromVersion, toVersion, redis) {
  const db = admin.firestore();
  const byVersion = new Map();

  let blocks = [];
  try {
    const idx = await db.collection('boards').doc(boardId)
      .collection('activity_index').orderBy('fromVersion').get();
    blocks = idx.docs.map(d => d.data()).filter(Boolean);
  } catch (_) {
    blocks = [];
  }
  for (const b of blocks) {
    if (!b.r2BlockKey) continue;
    if (b.toVersion < fromVersion || b.fromVersion > toVersion) continue;
    let blockOps = [];
    try {
      blockOps = await r2.getGzipJson(b.r2BlockKey);
    } catch (_) {
      continue;
    }
    for (const op of (blockOps || [])) {
      if (!op || op.version < fromVersion || op.version > toVersion) continue;
      if (!byVersion.has(op.version)) byVersion.set(op.version, op);
    }
  }

  if (redis) {
    try {
      const raw = await redis.xrange(`board_updates:${boardId}`, '-', '+');
      for (const [, fields] of (raw || [])) {
        const e = parseStreamFields(fields);
        if (e.version < fromVersion || e.version > toVersion) continue;
        if (byVersion.has(e.version)) continue;
        byVersion.set(e.version, {
          version: e.version,
          updateId: e.updateId,
          userId: e.sourceClientId,
          elementId: e.elementId || null,
          action: e.action || null,
          payloadBase64: e.payloadBase64,
          timestamp: e.timestamp,
        });
      }
    } catch (_) { /* stream unavailable */ }
  }

  return [...byVersion.values()].sort((a, b) => a.version - b.version);
}

module.exports = { reconstruct, loadOpsInRange, parseStreamFields };
