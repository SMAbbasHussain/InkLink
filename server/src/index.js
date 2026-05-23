const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Redis = require('ioredis');
const admin = require('firebase-admin');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());

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

  // Phase 2: Live Sync - Join Room
  socket.on('watch_board', (boardId) => {
    socket.join(`board_room:${boardId}`);
    socket.data.currentBoardId = boardId;
    console.log(`[watch_board] User ${uid} joined board ${boardId} (socket: ${socket.id})`);
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
    
    // 1. Broadcast to room
    socket.to(`board_room:${boardId}`).emit('crdt_update', { boardId, update });
    console.log(`[WS UPDATE SENT] board_room:${boardId} updateId=${update.updateId}`);

    try {
      // 2. Forward to Firestore
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

      // 3. Redis-Backed Offline Queue
      let members = [];
      if (db) {
        const membersSnapshot = await db.collection('boards').doc(boardId).collection('members').get();
        members = membersSnapshot.docs.map(doc => doc.id);
        console.log(`[crdt_update] Board ${boardId} has members: ${members.join(', ')}`);
      }

      const connectedUids = await getConnectedSocketsInRoom(`board_room:${boardId}`);
      console.log(`[crdt_update] Connected UIDs in board ${boardId}: ${connectedUids.join(', ')}`);
      const offlineMembers = members.filter(memberUid => !connectedUids.includes(memberUid));
      console.log(`[crdt_update] Offline members for board ${boardId}: ${offlineMembers.join(', ')}`);

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
          // Use in-memory fallback
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
          console.log(`[sync_offline] Looking for queue key: ${queueKey}`);
          let elements = [];
          let source = 'redis';
          
          if (redisAvailable) {
              try {
                  elements = await redis.lrange(queueKey, 0, -1);
                  console.log(`[sync_offline] Retrieved ${elements.length} elements from Redis for ${queueKey}`);
              } catch (redisError) {
                  console.warn(`Redis sync_offline failed, checking memory queue: ${redisError.message}`);
                  elements = memoryQueue[queueKey] || [];
                  source = 'memory';
              }
          } else {
              // Use in-memory queue
              elements = memoryQueue[queueKey] || [];
              source = 'memory';
              console.log(`[sync_offline] Using memory queue for ${queueKey}, found ${elements.length} elements`);
          }

          if (elements && elements.length > 0) {
              const updates = elements.map(el => typeof el === 'string' ? JSON.parse(el) : el);
              logWsEvent('SYNC RESPONSE SENT', [
                `[event] sync_offline`,
                `[direction] server -> client`,
                `[user] ${uid}`,
                `[board] ${boardId}`,
                `[source] ${source}`,
                `[updates] ${updates.length}`,
              ]);
              
              // Clean up queue
              if (redisAvailable) {
                  try {
                      await redis.del(queueKey);
                      console.log(`[sync_offline] Deleted queue key from Redis: ${queueKey}`);
                  } catch (e) {
                      delete memoryQueue[queueKey];
                  }
              } else {
                  delete memoryQueue[queueKey];
              }
              
              if (typeof callback === 'function') {
                  callback({ status: 'success', updates, source });
              } else {
                  socket.emit('sync_offline_response', { status: 'success', boardId, updates, source });
              }
          } else {
              // The list is empty (due to TTL expiration or no updates) -> Special payload
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
