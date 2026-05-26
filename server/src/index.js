const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Redis = require('ioredis');
const admin = require('firebase-admin');
const cors = require('cors');
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
  cors: { origin: '*' },
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

// 1. Redis Provisioning Setup
const redis = new Redis(process.env.REDIS_URL || 'redis://127.0.0.1:6379');
let redisAvailable = false;

// In-memory fallback queue for local development (expires after server restart)
const memoryQueue = {};

// Track UIDs that explicitly logged out so we skip queueing updates for them.
// Cleared on reconnect (new socket → re‑authenticated → new connection event).
const loggedOutUids = new Set();

// In-memory cache for board member lists.
// Avoids reading boards/{boardId}/members on every CRDT update (the #1 source of reads).
const boardMembersCache = new Map();
const MEMBERS_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

async function getBoardMembersCached(boardId) {
  const cached = boardMembersCache.get(boardId);
  if (cached && Date.now() - cached.fetchedAt < MEMBERS_CACHE_TTL_MS) {
    return cached.members;
  }

  // 1. Try Redis (Cloud Functions keep this up-to-date on member changes)
  if (redisAvailable) {
    try {
      const key = `board_members:${boardId}`;
      const members = await redis.smembers(key);
      if (members && members.length > 0) {
        await redis.expire(key, 604800); // refresh 7-day TTL on access
        boardMembersCache.set(boardId, { members, fetchedAt: Date.now() });
        return members;
      }
    } catch (e) {
      console.warn(`Redis read failed for board_members:${boardId}, falling back to Firestore`);
    }
  }

  // 2. Fallback to Firestore
  if (!db) return [];
  const snapshot = await db
    .collection('boards')
    .doc(boardId)
    .collection('members')
    .get();
  const members = snapshot.docs.map((doc) => doc.id);
  boardMembersCache.set(boardId, { members, fetchedAt: Date.now() });

  // Seed Redis so subsequent reads skip Firestore
  if (redisAvailable && members.length > 0) {
    try {
      const key = `board_members:${boardId}`;
      await redis.sadd(key, ...members);
      await redis.expire(key, 604800);
    } catch (_) {}
  }

  return members;
}

redis.on('connect', () => {
  redisAvailable = true;
  console.log('✓ Redis connected');
});

redis.on('error', (error) => {
  redisAvailable = false;
  console.warn('⚠ Redis unavailable, using in-memory queue fallback for offline sync');
  console.warn(`  To enable Redis: redis-server or set REDIS_URL env var`);
});

// 2. Firebase Admin Setup
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

async function clearUserQueues(uid) {
  if (redisAvailable) {
    try {
      const keys = await redis.keys(`queue:${uid}:board:*`);
      if (keys && keys.length > 0) {
        for (const key of keys) {
          await redis.del(key);
          console.log(`[logout] Cleared Redis queue: ${key}`);
        }
      }
    } catch (e) {
      console.warn(`[logout] Failed clearing Redis queues for ${uid}: ${e.message}`);
    }
    return;
  }

  const queuePrefix = `queue:${uid}:board:`;
  for (const key in memoryQueue) {
    if (key.startsWith(queuePrefix)) {
      delete memoryQueue[key];
      console.log(`[logout] Cleared memory queue: ${key}`);
    }
  }
}

// Helper to get connected users in a room
async function getConnectedSocketsInRoom(roomName) {
  const sockets = await io.in(roomName).fetchSockets();
  // We'll store decoded auth UID in socket.data.uid, or extract from connected socket custom data
  return sockets.map(s => s.data.uid).filter(Boolean);
}

// 3. Socket.io Connection & Authenticate
io.use(async (socket, next) => {
  try {
    const {token} = socket.handshake.auth;
    if (!token) return next(new Error('Authentication error: Token missing'));

    if (db) { // only run actual auth if Firebase is running
        const decodedToken = await admin.auth().verifyIdToken(token);
        socket.data.uid = decodedToken.uid;
    } else {
        // Fallback for local testing without valid service-account
        socket.data.uid = socket.handshake.auth.uid || "test-user";
    }
    next();
  } catch (error) {
    next(new Error('Authentication error: Invalid Token'));
  }
});

io.on('connection', (socket) => {
  const {uid} = socket.data;
  console.log(`User connected: ${uid} (socket: ${socket.id})`);

  // User re‑authenticated (new login) — resume queueing for them
  loggedOutUids.delete(uid);

  // Phase 2: Live Sync - Join Room
  socket.on('watch_board', (boardId) => {
    socket.join(`board_room:${boardId}`);
    socket.data.currentBoardId = boardId;
    console.log(`[watch_board] User ${uid} joined board ${boardId} (socket: ${socket.id})`);
  });

  // Force-refresh the member list cache for a board.
  // Emitted by the client after a Cloud Function adds them as a member,
  // so the server picks up the updated list from Redis immediately.
  socket.on('refresh_board_members', (boardId) => {
    boardMembersCache.delete(boardId);
    console.log(`[refresh_board_members] Invalidated cache for board ${boardId} (triggered by ${uid})`);
  });

  socket.on('leave_board', (boardId) => {
    socket.leave(`board_room:${boardId}`);
    console.log(`[leave_board] User ${uid} left board ${boardId}`);
  });

  // Phase 2 & 3: Incoming Update Relay
  socket.on('crdt_update', async ({ boardId, update }, ack) => {
    logWsEvent('UPDATE RECEIVED', [
      `[event] crdt_update`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
      `[updateId] ${update.updateId}`,
      `[elementId] ${update.elementId ?? 'n/a'}`,
    ]);

    const isSingleUser = update._singleUser === true;
    // Strip the client-side flag before persisting
    if (isSingleUser) {
      delete update._singleUser;
    }

    try {
      // Save to Firestore (always)
      if (db) {
        await db.collection('boards').doc(boardId).collection('crdt_updates')
          .doc(update.updateId)
          .set({
            ...update,
            updateId: update.updateId,
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        console.log(`[crdt_update] Wrote update ${update.updateId} to Firestore`);
      }

      if (isSingleUser) {
        // Single-user board: skip broadcast, skip Redis, skip offline queue
        console.log(`[crdt_update] Single-user board — saved directly, no broadcast/queue`);
        if (typeof ack === 'function') {
          ack({ status: 'success', updateId: update.updateId, boardId });
        }
        return;
      }

      // Multi-user: broadcast + offline queue
      socket.to(`board_room:${boardId}`).emit('crdt_update', { boardId, update });
      console.log(`[WS UPDATE SENT] board_room:${boardId} updateId=${update.updateId}`);

      const members = await getBoardMembersCached(boardId);
      const connectedUids = await getConnectedSocketsInRoom(`board_room:${boardId}`);
      console.log(`[crdt_update] Connected UIDs in board ${boardId}: ${connectedUids.join(', ')}`);
      const offlineMembers = members.filter(
        memberUid => !connectedUids.includes(memberUid) && !loggedOutUids.has(memberUid)
      );
      console.log(`[crdt_update] Offline members (excluding logged‑out) for board ${boardId}: ${offlineMembers.join(', ')}`);

      const ttlSeconds = 604800; // 7 days

      for (const memberUid of offlineMembers) {
        const queueKey = `queue:${memberUid}:board:${boardId}`;
        console.log(`[crdt_update] Queueing update ${update.updateId} for offline member ${memberUid} (key: ${queueKey})`);

        if (redisAvailable) {
          try {
            await redis.rpush(queueKey, JSON.stringify(update));
            await redis.expire(queueKey, ttlSeconds);
            console.log(`[crdt_update] Successfully queued update to Redis for ${queueKey}`);
          } catch (redisError) {
            console.warn(`Redis queue failed for ${queueKey}, using memory fallback`);
            if (!memoryQueue[queueKey]) memoryQueue[queueKey] = [];
            memoryQueue[queueKey].push(update);
          }
        } else {
          if (!memoryQueue[queueKey]) memoryQueue[queueKey] = [];
          memoryQueue[queueKey].push(update);
          console.log(`[crdt_update] Queued update to memory for ${queueKey}`);
        }
      }

      if (typeof ack === 'function') {
        ack({ status: 'success', updateId: update.updateId, boardId });
      }
    } catch (error) {
      console.error('Failed processing crdt_update:', error);
      if (typeof ack === 'function') {
        try {
          ack({ status: 'error', message: error.message });
        } catch (e) {
          // ignore
        }
      }
    }
  });

  // Live preview relay for in-progress canvas edits.
  socket.on('crdt_preview', async ({ boardId, preview }, ack) => {
    logWsEvent('PREVIEW RECEIVED', [
      `[event] crdt_preview`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
      `[previewId] ${preview?.previewId ?? 'n/a'}`,
      `[elementId] ${preview?.elementId ?? 'n/a'}`,
    ]);

    socket.to(`board_room:${boardId}`).emit('crdt_preview', { boardId, preview });
    console.log(
      `[WS PREVIEW SENT] board_room:${boardId} previewId=${preview?.previewId ?? 'n/a'}`,
    );

    if (typeof ack === 'function') {
      ack({ status: 'success', previewId: preview?.previewId ?? null, boardId });
    }
  });

  // Phase 3: Offline Sync Demand & Fallback
  socket.on('sync_offline', async ({ boardId }, callback) => {
    logWsEvent('SYNC REQUEST RECEIVED', [
      `[event] sync_offline`,
      `[direction] client -> server`,
      `[user] ${uid}`,
      `[board] ${boardId}`,
    ]);
    try {
      const queueKey = `queue:${uid}:board:${boardId}`;
      console.log(`[sync_offline] Draining queue: ${queueKey}`);
      let elements = [];
      let source = 'redis';

      if (redisAvailable) {
        // Atomically pop the entire queue: rename to a temp key so no other
        // consumer (or repeated request) can touch it, then read + delete.
        const tmpKey = `${queueKey}:processing`;
        try {
          const renamed = await redis.renamenx(queueKey, tmpKey);
          if (renamed === 1) {
            elements = await redis.lrange(tmpKey, 0, -1);
            await redis.del(tmpKey);
            console.log(`[sync_offline] Drained ${elements.length} elements from Redis for ${queueKey}`);
          } else {
            // Queue either doesn't exist or another consumer is already draining it
            console.log(`[sync_offline] Queue ${queueKey} already drained or claimed by another consumer`);
          }
        } catch (redisError) {
          console.warn(`Redis sync_offline failed for ${queueKey}: ${redisError.message}`);
          elements = memoryQueue[queueKey] || [];
          source = 'memory';
          delete memoryQueue[queueKey];
        }
      } else {
        elements = memoryQueue[queueKey] || [];
        source = 'memory';
        delete memoryQueue[queueKey];
        console.log(`[sync_offline] Drained ${elements.length} elements from memory for ${queueKey}`);
      }

      if (elements && elements.length > 0) {
        let updates;
        try {
          updates = elements.map(el => typeof el === 'string' ? JSON.parse(el) : el);
        } catch (parseError) {
          console.error(`[sync_offline] Corrupt queue data for ${queueKey}: ${parseError.message}`);
          if (typeof callback === 'function') {
            callback({ status: 'error', boardId, error: 'corrupt_queue' });
          }
          return;
        }

        logWsEvent('SYNC RESPONSE SENT', [
          `[event] sync_offline`,
          `[direction] server -> client`,
          `[user] ${uid}`,
          `[board] ${boardId}`,
          `[source] ${source}`,
          `[updates] ${updates.length}`,
        ]);

        if (typeof callback === 'function') {
          callback({ status: 'success', updates, source });
        } else {
          socket.emit('sync_offline_response', { status: 'success', boardId, updates, source });
        }
      } else {
        logWsEvent('SYNC FALLBACK REQUESTED', [
          `[event] sync_offline`,
          `[direction] server -> client`,
          `[user] ${uid}`,
          `[board] ${boardId}`,
          `[result] fallback_required`,
        ]);
        const payload = { status: 'fallback_required', boardId };
        if (typeof callback === 'function') {
          callback(payload);
        } else {
          socket.emit('sync_offline_response', payload);
        }
      }
    } catch (error) {
      console.error('Error in sync_offline:', error);
      if (typeof callback === 'function') {
        callback({ status: 'error', error: error.message });
      }
    }
  });

  socket.on('disconnect', () => {
    console.log(`[WS DISCONNECT] user=${uid} socket=${socket.id}`);
    // IMPORTANT: Do NOT clear user queues on simple disconnect. Queues
    // must be preserved across transient disconnects. Clearing should be
    // done only on explicit logout (handled via 'logout' event).
    // This preserves pending offline updates for later delivery.
  });

  // Explicit logout: clear per-user queues only when client intentionally logs out
  socket.on('logout', async (payload, callback) => {
    logWsEvent('LOGOUT RECEIVED', [
      `[event] logout`,
      `[direction] client -> server`,
      `[user] ${uid}`,
    ]);
    try {
      await clearUserQueues(uid);
      loggedOutUids.add(uid);
      console.log(`[logout] Added ${uid} to logged‑out set — future updates for this user will NOT be queued until they log in again`);
      if (typeof callback === 'function') callback({ status: 'success' });
      else socket.emit('logout_response', { status: 'success' });
    } catch (e) {
      console.error(`[logout] Failed clearing queues for ${uid}: ${e.message}`);
      if (typeof callback === 'function') callback({ status: 'error', message: e.message });
      else socket.emit('logout_response', { status: 'error', message: e.message });
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`WebSocket server listening on port ${PORT}`);
});
