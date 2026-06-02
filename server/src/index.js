const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Redis = require('ioredis');
const admin = require('firebase-admin');
const cors = require('cors');
const Y = require('yjs');
require('dotenv').config();

const app = express();
app.use(cors());

app.get('/health', (req, res) => {
  console.log("Ping Test");
  res.status(200).json({
    status: 'ok',
    time: new Date(),
  });
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CORS_ORIGIN || '*' },
});

function loadFirebaseServiceAccount() {
  const jsonValue =
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    process.env.SERVICE_ACCOUNT_JSON;
  const base64Value =
    process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 ||
    process.env.SERVICE_ACCOUNT_BASE64;

  if (jsonValue) {
    return JSON.parse(jsonValue);
  }

  if (base64Value) {
    return JSON.parse(Buffer.from(base64Value, 'base64').toString('utf8'));
  }

  const credentialsPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    process.env.SERVICE_ACCOUNT_PATH;

  if (credentialsPath) {
    return require(credentialsPath);
  }

  return require('../service-account.json');
}

// ============================================================
// REDIS PROVISIONING
// ============================================================
const redis = new Redis(process.env.REDIS_URL || 'redis://127.0.0.1:6379');
let redisAvailable = false;

// ============================================================
// RATE LIMITING
// ============================================================
const RATE_LIMIT_WINDOW_MS = 1000;
const RATE_LIMIT_MAX_EVENTS = 30;
const socketEventCounts = new Map();

function isRateLimited(socketId) {
  const now = Date.now();
  const entry = socketEventCounts.get(socketId) || { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
  if (now > entry.resetAt) {
    entry.count = 0;
    entry.resetAt = now + RATE_LIMIT_WINDOW_MS;
  }
  entry.count++;
  socketEventCounts.set(socketId, entry);
  return entry.count > RATE_LIMIT_MAX_EVENTS;
}

setInterval(() => {
  const now = Date.now();
  for (const [sid, entry] of socketEventCounts.entries()) {
    if (now > entry.resetAt + RATE_LIMIT_WINDOW_MS) {
      socketEventCounts.delete(sid);
    }
  }
}, 30000);

// ============================================================
// VALIDATION HELPERS
// ============================================================
function isValidBoardId(value) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= 128;
}

function isValidUpdate(update) {
  if (!update || typeof update !== 'object') return false;
  return typeof update.updateId === 'string' && update.updateId.length > 0;
}

function isValidPreview(preview) {
  if (!preview || typeof preview !== 'object') return false;
  return preview.previewId != null;
}

redis.on('connect', () => {
  redisAvailable = true;
  console.log('✓ Redis connected');
});

redis.on('error', (error) => {
  redisAvailable = false;
  console.warn('⚠ Redis unavailable, cursor-based sync will not be available');
});

// ============================================================
// FIREBASE ADMIN
// ============================================================
try {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else {
    const serviceAccount = loadFirebaseServiceAccount();
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
} catch (error) {
  console.warn(
    'Firebase Admin not initialized. Set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_BASE64, GOOGLE_APPLICATION_CREDENTIALS, or SERVICE_ACCOUNT_PATH.',
  );
}

const db = admin.firestore?.() || null;

function logWsEvent(title, lines) {
  console.log('');
  console.log('==================================================');
  console.log(`WS ${title}`);
  for (const line of lines) {
    console.log(line);
  }
  console.log('==================================================');
}

async function getConnectedSocketsInRoom(roomName) {
  const sockets = await io.in(roomName).fetchSockets();
  return sockets.map(s => s.data.uid).filter(Boolean);
}

// ============================================================
// REDIS LUA SCRIPT — atomic append to board op log
// KEYS[1] = board:{boardId}:version       (INCR counter)
// KEYS[2] = board_updates:{boardId}       (STREAM)
// KEYS[3] = board:dedup:{boardId}         (SET for dedup)
// ARGV[1] = maxlen                        (e.g., "1000")
// ARGV[2] = updateId
// ARGV[3] = payloadBase64
// ARGV[4] = elementId
// ARGV[5] = sourceClientId
// ARGV[6] = timestamp (ISO8601)
// ARGV[7] = _singleUser ("true"|"false")
// Returns: version number, or -1 if duplicate
// ============================================================
const APPEND_UPDATE_LUA = `
local seen = redis.call('SADD', KEYS[3], ARGV[2])
if seen == 0 then
  return -1
end
redis.call('EXPIRE', KEYS[3], 3600)
local version = redis.call('INCR', KEYS[1])
redis.call('XADD', KEYS[2], 'MAXLEN', '~', ARGV[1], '*',
  'version', version,
  'updateId', ARGV[2],
  'payloadBase64', ARGV[3],
  'elementId', ARGV[4],
  'sourceClientId', ARGV[5],
  'timestamp', ARGV[6],
  '_singleUser', ARGV[7]
)
return version
`;

let appendUpdateSha = null;

// Load Lua script after Redis connects
redis.on('connect', async () => {
  try {
    appendUpdateSha = await redis.script('LOAD', APPEND_UPDATE_LUA);
    console.log('✓ Lua script loaded (SHA:', appendUpdateSha, ')');
  } catch (e) {
    console.warn('⚠ Failed to load Lua script:', e.message);
  }
});

// ============================================================
// PARSE REDIS STREAM ENTRY (field-value array → object)
// ============================================================
function parseStreamEntry(fields) {
  const obj = {};
  for (let i = 0; i < fields.length; i += 2) {
    obj[fields[i]] = fields[i + 1];
  }
  if (obj.version) obj.version = parseInt(obj.version, 10);
  if (obj._singleUser) obj._singleUser = obj._singleUser === 'true';
  return obj;
}

// ============================================================
// SEED Redis version from Firestore snapshot (recovery)
// ============================================================
async function seedRedisFromFirestore(boardId) {
  if (!redisAvailable || !db) return;
  const versionKey = `board:${boardId}:version`;
  const exists = await redis.exists(versionKey);
  if (exists) return;

  try {
    const snap = await db.collection('boards').doc(boardId)
      .collection('snapshot').doc('latest').get();
    if (snap.exists) {
      const data = snap.data();
      if (data.lastAppliedVersion) {
        await redis.set(versionKey, data.lastAppliedVersion.toString(), 'EX', 604800);
        console.log(`[seed] Board ${boardId}: version seeded to ${data.lastAppliedVersion} from Firestore`);
      }
      if (data.lastAppliedStreamId) {
        await redis.set(`board:lastSnapshotCursor:${boardId}`, data.lastAppliedStreamId, 'EX', 604800);
        await redis.set(`board:lastSnapshotVersion:${boardId}`, data.lastAppliedVersion.toString(), 'EX', 604800);
      }
    } else {
      await redis.set(versionKey, '0', 'EX', 604800);
    }
  } catch (e) {
    console.warn(`[seed] Failed to seed board ${boardId}: ${e.message}`);
  }
}

// ============================================================
// SNAPSHOT WORKER (Phase 3)
// ============================================================
async function triggerSnapshot(boardId) {
  if (!redisAvailable || !db) {
    console.warn(`[snapshot] Skipped board ${boardId}: Redis or Firestore unavailable`);
    return;
  }

  const streamKey = `board_updates:${boardId}`;
  const versionKey = `board:${boardId}:version`;
  const snapshotCursorKey = `board:lastSnapshotCursor:${boardId}`;
  const snapshotVersionKey = `board:lastSnapshotVersion:${boardId}`;

  // 1. Freeze the target version at the START of snapshot process
  const snapshotTargetVersion = parseInt(await redis.get(versionKey) || '0', 10);
  const lastSnapshotVersion = parseInt(await redis.get(snapshotVersionKey) || '0', 10);
  if (snapshotTargetVersion <= lastSnapshotVersion) return;

  // 2. Read stream entries since last snapshot cursor — incremental, not full scan
  const lastCursor = await redis.get(snapshotCursorKey) || '0-0';
  const rawEntries = await redis.xrange(streamKey, lastCursor, '+');

  // 3. Filter entries: only those with version <= snapshotTargetVersion
  //    (excludes entries that arrived during snapshot build)
  const entries = rawEntries
    .map(([id, fields]) => {
      const entry = parseStreamEntry(fields);
      entry._streamId = id;
      return entry;
    })
    .filter(e => e.version > lastSnapshotVersion && e.version <= snapshotTargetVersion)
    .sort((a, b) => a.version - b.version);

  if (entries.length === 0) return;

  // 4. Build materialized Yjs doc state
  const doc = new Y.Doc();
  for (const entry of entries) {
    if (!entry.payloadBase64 || entry._singleUser === true) continue;
    try {
      const buffer = Buffer.from(entry.payloadBase64, 'base64');
      Y.applyUpdate(doc, buffer);
    } catch (e) {
      console.warn(`[snapshot] Skipping corrupt update ${entry.updateId}: ${e.message}`);
    }
  }

  const stateUpdate = Buffer.from(Y.encodeStateAsUpdate(doc)).toString('base64');
  const stateVector = Buffer.from(Y.encodeStateVector(doc)).toString('base64');
  const elementCount = doc.getMap('elements').size;

  // 5. Find the stream ID of the LAST entry where version <= snapshotTargetVersion
  const lastIncluded = entries.filter(e => e.version <= snapshotTargetVersion).pop();
  const lastAppliedStreamId = lastIncluded ? lastIncluded._streamId : lastCursor;

  // 6. Write to Firestore
  const snapshotRef = db.collection('boards').doc(boardId)
    .collection('snapshot').doc('latest');

  try {
    await snapshotRef.set({
      boardId,
      lastAppliedVersion: snapshotTargetVersion,
      lastAppliedStreamId,
      stateUpdate,
      stateVector,
      elementCount,
      snapshotVersion: lastSnapshotVersion + 1,
      lastSnapshotAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: '__snapshot_worker__',
    });

    // 7. Update Redis cursor only after Firestore write succeeds
    await redis.set(snapshotCursorKey, lastAppliedStreamId, 'EX', 604800);
    await redis.set(snapshotVersionKey, snapshotTargetVersion.toString(), 'EX', 604800);

    // 8. Trim stream at snapshot boundary — remove entries before last applied stream ID
    await redis.xtrim(streamKey, 'MINID', lastAppliedStreamId).catch(() => {});

    console.log(`[snapshot] Board ${boardId}: v${lastSnapshotVersion} → v${snapshotTargetVersion} (${entries.length} updates, ${elementCount} elements)`);
  } catch (e) {
    console.warn(`[snapshot] Firestore write FAILED for board ${boardId}: ${e.message} — will retry`);
    // Do NOT update Redis cursor or trim — next attempt will include same entries
  }
}

// ============================================================
// CLEANUP WORKER (Phase 3) — snapshot stale boards, then trim
// ============================================================
setInterval(async () => {
  if (!redisAvailable) return;

  const threeDaysAgo = Date.now() - 3 * 24 * 60 * 60 * 1000;
  const stream = redis.scanStream({ match: 'board:lastActivity:*', count: 100 });

  stream.on('data', async (keys) => {
    for (const key of keys) {
      try {
        const boardId = key.replace('board:lastActivity:', '');
        const lastActivity = parseInt(await redis.get(key) || '0', 10);
        if (lastActivity === 0 || lastActivity > threeDaysAgo) continue;
        console.log(`[cleanup] Board ${boardId} inactive > 3 days — taking snapshot`);
        await triggerSnapshot(boardId);
      } catch (e) {
        console.warn(`[cleanup] Failed for ${key}: ${e.message}`);
      }
    }
  });
}, 60 * 60 * 1000);

// ============================================================
// SOCKET.IO AUTH MIDDLEWARE
// ============================================================
io.use(async (socket, next) => {
  try {
    const {token} = socket.handshake.auth;
    if (!token) return next(new Error('Authentication error: Token missing'));

    if (db) {
        const decodedToken = await admin.auth().verifyIdToken(token);
        socket.data.uid = decodedToken.uid;
    } else {
        socket.data.uid = socket.handshake.auth.uid || "test-user";
    }
    next();
  } catch (error) {
    next(new Error('Authentication error: Invalid Token'));
  }
});

// ============================================================
// SOCKET.IO CONNECTION
// ============================================================
io.on('connection', (socket) => {
  const {uid} = socket.data;
  console.log(`User connected: ${uid} (socket: ${socket.id})`);

  // ----------------------------------------------------------
  // watch_board
  // ----------------------------------------------------------
  socket.on('watch_board', (boardId) => {
    if (!isValidBoardId(boardId)) {
      console.warn(`[watch_board] Invalid boardId from ${uid}`);
      return;
    }
    socket.join(`board_room:${boardId}`);
    socket.data.currentBoardId = boardId;
    console.log(`[watch_board] User ${uid} joined board ${boardId} (socket: ${socket.id})`);
  });

  // ----------------------------------------------------------
  // leave_board
  // ----------------------------------------------------------
  socket.on('leave_board', (boardId) => {
    if (!isValidBoardId(boardId)) {
      console.warn(`[leave_board] Invalid boardId from ${uid}`);
      return;
    }
    socket.leave(`board_room:${boardId}`);
    console.log(`[leave_board] User ${uid} left board ${boardId}`);
  });

  // ============================================================
  // crdt_update — LIVE UPDATE RELAY + PERSISTENCE
  // ============================================================
  socket.on('crdt_update', async ({ boardId, update }, ack) => {
    if (isRateLimited(socket.id)) {
      console.warn(`[crdt_update] Rate limited ${uid} (socket: ${socket.id})`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'rate_limited' });
      return;
    }

    if (!isValidBoardId(boardId) || !isValidUpdate(update)) {
      console.warn(`[crdt_update] Invalid payload from ${uid}`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'invalid_payload' });
      return;
    }

    logWsEvent('UPDATE RECEIVED', [
      `[event] crdt_update`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
      `[updateId] ${update.updateId}`,
      `[elementId] ${update.elementId ?? 'n/a'}`,
    ]);

    const isSingleUser = update._singleUser === true;
    if (isSingleUser) {
      delete update._singleUser;
    }

    try {
      // -------------------------------------------------------
      // PHASE 1: Atomic append to Redis STREAM via Lua script
      // -------------------------------------------------------
      let version = null;
      let isDuplicate = false;

      if (redisAvailable && !isSingleUser) {
        // Seed Redis version from Firestore if missing (handles Redis loss recovery)
        await seedRedisFromFirestore(boardId);

        const now = new Date().toISOString();
        try {
          let result;
          try {
            result = await redis.evalsha(appendUpdateSha, 3,
              `board:${boardId}:version`,
              `board_updates:${boardId}`,
              `board:dedup:${boardId}`,
              1000,
              update.updateId,
              update.payloadBase64,
              update.elementId || '',
              update.sourceClientId || '',
              now,
              isSingleUser ? 'true' : 'false'
            );
          } catch (shaError) {
            if (shaError.message && shaError.message.includes('NOSCRIPT')) {
              result = await redis.eval(APPEND_UPDATE_LUA, 3,
                `board:${boardId}:version`,
                `board_updates:${boardId}`,
                `board:dedup:${boardId}`,
                1000,
                update.updateId,
                update.payloadBase64,
                update.elementId || '',
                update.sourceClientId || '',
                now,
                isSingleUser ? 'true' : 'false'
              );
            } else {
              throw shaError;
            }
          }

          if (result === -1) {
            isDuplicate = true;
            console.log(`[crdt_update] Duplicate updateId ${update.updateId} — acking success, skipping storage`);
          } else {
            version = result;

            // Update last activity timestamp (best-effort)
            redis.set(`board:lastActivity:${boardId}`, Date.now().toString(), 'EX', 604800).catch(() => {});
          }
        } catch (luaError) {
          console.warn(`[crdt_update] Lua script failed: ${luaError.message}`);
        }
      }

      if (isSingleUser) {
        console.log(`[crdt_update] Single-user board — saved directly, no broadcast/queue`);
        if (typeof ack === 'function') {
          ack({ status: 'success', updateId: update.updateId, boardId, version: version || 0 });
        }
        return;
      }

      if (isDuplicate) {
        // Duplicate: ack success but no broadcast (already broadcast the first time)
        if (typeof ack === 'function') {
          ack({ status: 'success', updateId: update.updateId, boardId, version: 0 });
        }
        return;
      }

      // If persistence failed (Redis unavailable or Lua error), reject so client retries
      if (version === null && !isSingleUser) {
        if (typeof ack === 'function') {
          ack({ status: 'error', message: 'persistence_unavailable' });
        }
        return;
      }

      // -------------------------------------------------------
      // Broadcast to room (with version for client cursor tracking)
      // -------------------------------------------------------
      const broadcastPayload = { boardId, update: { ...update, version } };
      socket.to(`board_room:${boardId}`).emit('crdt_update', broadcastPayload);
      console.log(`[WS UPDATE SENT] board_room:${boardId} updateId=${update.updateId} version=${version}`);

      // -------------------------------------------------------
      // Trigger snapshot every 100 updates (fire-and-forget)
      // -------------------------------------------------------
      if (redisAvailable && version !== null && version % 100 === 0) {
        triggerSnapshot(boardId).catch(e =>
          console.warn(`[snapshot] trigger failed: ${e.message}`)
        );
      }

      if (typeof ack === 'function') {
        ack({ status: 'success', updateId: update.updateId, boardId, version: version || 0 });
      }
    } catch (error) {
      console.error('Failed processing crdt_update:', error);
      if (typeof ack === 'function') {
        try {
          ack({ status: 'error', message: error.message });
        } catch (e) {}
      }
    }
  });

  // ----------------------------------------------------------
  // crdt_preview — EPHEMERAL RELAY (unchanged)
  // ----------------------------------------------------------
  socket.on('crdt_preview', async ({ boardId, preview }, ack) => {
    if (isRateLimited(socket.id)) {
      console.warn(`[crdt_preview] Rate limited ${uid} (socket: ${socket.id})`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'rate_limited' });
      return;
    }

    if (!isValidBoardId(boardId) || !isValidPreview(preview)) {
      console.warn(`[crdt_preview] Invalid payload from ${uid}`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'invalid_payload' });
      return;
    }

    logWsEvent('PREVIEW RECEIVED', [
      `[event] crdt_preview`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
      `[previewId] ${preview?.previewId ?? 'n/a'}`,
      `[elementId] ${preview?.elementId ?? 'n/a'}`,
    ]);

    socket.to(`board_room:${boardId}`).emit('crdt_preview', { boardId, preview });

    if (typeof ack === 'function') {
      ack({ status: 'success', previewId: preview?.previewId ?? null, boardId });
    }
  });

  // ============================================================
  // sync_offline — VERSION-BASED SYNC (Phase 2+)
  // ============================================================
  socket.on('sync_offline', async ({ boardId, lastSeenCursor, sinceVersion }, callback) => {
    if (!isValidBoardId(boardId)) {
      console.warn(`[sync_offline] Invalid boardId from ${uid}`);
      if (typeof callback === 'function') callback({ status: 'error', boardId, error: 'invalid_board_id' });
      return;
    }

    logWsEvent('SYNC REQUEST RECEIVED', [
      `[event] sync_offline`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
      `[cursor] ${lastSeenCursor || sinceVersion || 'none'}`,
    ]);

    try {
      // ============================================================
      // PATH 1 (PRIMARY): Stream cursor-based incremental sync
      // ============================================================
      if (redisAvailable && lastSeenCursor) {
        const streamKey = `board_updates:${boardId}`;
        const streamId = lastSeenCursor.split(':')[0];

        const raw = await redis.xread('COUNT', 100, 'STREAMS', streamKey, streamId);

        if (raw && raw[0] && raw[0][1] && raw[0][1].length > 0) {
          const entries = raw[0][1];
          const updates = [];
          let lastEntryId = streamId;
          let lastVersion = parseInt(lastSeenCursor.split(':')[1] || '0', 10);

          for (const [entryId, fields] of entries) {
            const entry = parseStreamEntry(fields);
            entry.appliedAt = entry.timestamp;
            updates.push(entry);
            lastEntryId = entryId;
            if (entry.version > lastVersion) lastVersion = entry.version;
          }

          const newCursor = `${lastEntryId}:${lastVersion}`;
          const hasMore = entries.length >= 100;

          // Store cursor for this user
          await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, newCursor, 'EX', 604800).catch(() => {});

          logWsEvent('SYNC RESPONSE (cursor)', [
            `[user] ${uid}`,
            `[board] ${boardId}`,
            `[updates] ${updates.length}`,
            `[cursor] ${newCursor}`,
            `[hasMore] ${hasMore}`,
          ]);

          if (typeof callback === 'function') {
            callback({ status: 'success', updates, cursor: newCursor, hasMore, source: 'cursor' });
          }
          return;
        }

        // XREAD returned empty — no new entries; return current cursor
        if (typeof callback === 'function') {
          callback({ status: 'success', updates: [], cursor: lastSeenCursor, hasMore: false, source: 'cursor' });
        }
        return;
      }

      // ============================================================
      // PATH 2 (SECONDARY): Snapshot + remaining deltas
      // ============================================================
      if (redisAvailable && db) {
        const snapshotCursorKey = `board:lastSnapshotCursor:${boardId}`;
        const snapshotVersionKey = `board:lastSnapshotVersion:${boardId}`;
        const lastSnapshotVersion = parseInt(await redis.get(snapshotVersionKey) || '0', 10);
        const lastServerVersion = parseInt(await redis.get(`board:${boardId}:version`) || '0', 10);

        // Only use snapshot path if client is behind the snapshot version
        const effectiveServerVersion = sinceVersion || lastServerVersion;
        if (lastSnapshotVersion > 0 && lastSnapshotVersion > effectiveServerVersion) {
          // Load Firestore snapshot
          const snapDoc = await db.collection('boards').doc(boardId)
            .collection('snapshot').doc('latest').get();

          if (snapDoc.exists) {
            const snapshotData = snapDoc.data();
            const lastCursor = await redis.get(snapshotCursorKey) || '0-0';

            // Fetch deltas after snapshot from stream
            const raw = await redis.xread('COUNT', 100, 'STREAMS', `board_updates:${boardId}`, lastCursor);

            let updates = [];
            let lastEntryId = lastCursor;
            let lastVer = snapshotData.lastAppliedVersion || 0;

            if (raw && raw[0] && raw[0][1]) {
              for (const [entryId, fields] of raw[0][1]) {
                const entry = parseStreamEntry(fields);
                entry.appliedAt = entry.timestamp;
                updates.push(entry);
                lastEntryId = entryId;
                if (entry.version > lastVer) lastVer = entry.version;
              }
            }

            const newCursor = `${lastEntryId}:${lastVer}`;
            await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, newCursor, 'EX', 604800).catch(() => {});

            logWsEvent('SYNC RESPONSE (snapshot+delta)', [
              `[user] ${uid}`,
              `[board] ${boardId}`,
              `[snapshotVersion] ${snapshotData.lastAppliedVersion}`,
              `[deltas] ${updates.length}`,
              `[cursor] ${newCursor}`,
            ]);

            if (typeof callback === 'function') {
              callback({
                status: 'success',
                snapshot: {
                  stateUpdate: snapshotData.stateUpdate,
                  lastAppliedVersion: snapshotData.lastAppliedVersion,
                  lastAppliedStreamId: lastCursor,
                },
                updates,
                cursor: newCursor,
                source: 'snapshot_with_deltas',
              });
            }
            return;
          }
        }

        // Client is caught up to snapshot but we have no cursor — seed from current version
        const currentVersion = await redis.get(`board:${boardId}:version`) || '0';
        const dummyCursor = `0-0:${currentVersion}`;
        await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, dummyCursor, 'EX', 604800).catch(() => {});

        if (typeof callback === 'function') {
          callback({ status: 'success', updates: [], cursor: dummyCursor, hasMore: false, source: 'cursor' });
        }
        return;
      }

      // ============================================================
      // PATH 3 (TERTIARY): Firestore snapshot only (Redis unavailable)
      // ============================================================
      if (!redisAvailable && db) {
        const snapDoc = await db.collection('boards').doc(boardId)
          .collection('snapshot').doc('latest').get();
        if (snapDoc.exists) {
          const snapshotData = snapDoc.data();
          logWsEvent('SYNC RESPONSE (snapshot only)', [
            `[user] ${uid}`,
            `[board] ${boardId}`,
            `[snapshotVersion] ${snapshotData.lastAppliedVersion}`,
          ]);
          if (typeof callback === 'function') {
            callback({
              status: 'success',
              snapshot: {
                stateUpdate: snapshotData.stateUpdate,
                lastAppliedVersion: snapshotData.lastAppliedVersion,
              },
              updates: [],
              cursor: null,
              source: 'snapshot_only',
            });
          }
          return;
        }
      }

      if (typeof callback === 'function') {
        callback({ status: 'fallback_required', boardId });
      }
    } catch (error) {
      console.error('Error in sync_offline:', error);
      if (typeof callback === 'function') {
        callback({ status: 'error', error: error.message });
      }
    }
  });

  // ----------------------------------------------------------
  // disconnect
  // ----------------------------------------------------------
  socket.on('disconnect', () => {
    console.log(`[WS DISCONNECT] user=${uid} socket=${socket.id}`);
    socketEventCounts.delete(socket.id);
  });

  // ----------------------------------------------------------
  // logout
  // ----------------------------------------------------------
  socket.on('logout', async (payload, callback) => {
    logWsEvent('LOGOUT RECEIVED', [
      `[event] logout`,
      `[direction] client -> server`,
      `[user] ${uid}`,
    ]);
    try {
      // Clear cursor tracking for this user
      if (redisAvailable) {
        const keys = await redis.keys(`user:lastSeenCursor:${uid}:*`);
        if (keys && keys.length > 0) {
          for (const key of keys) {
            await redis.del(key);
          }
        }
      }

      console.log(`[logout] Cleared cursors for ${uid}`);
      if (typeof callback === 'function') callback({ status: 'success' });
      else socket.emit('logout_response', { status: 'success' });
    } catch (e) {
      console.error(`[logout] Failed clearing cursors for ${uid}: ${e.message}`);
      if (typeof callback === 'function') callback({ status: 'error', message: e.message });
      else socket.emit('logout_response', { status: 'error', message: e.message });
    }
  });
});

// ============================================================
// SERVER START
// ============================================================
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`WebSocket server listening on port ${PORT}`);
});

// Graceful shutdown
function gracefulShutdown(signal) {
  console.log(`\nReceived ${signal}, shutting down gracefully...`);
  server.close(() => {
    console.log('HTTP server closed');
    if (redisAvailable) {
      redis.quit().then(() => {
        console.log('Redis connection closed');
        process.exit(0);
      }).catch(() => process.exit(0));
    } else {
      process.exit(0);
    }
  });
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
