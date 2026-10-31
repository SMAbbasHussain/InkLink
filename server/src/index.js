const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Redis = require('ioredis');
const admin = require('firebase-admin');
const cors = require('cors');
const Y = require('yjs');
const crypto = require('crypto');
// Official Agora token generator for Node. NOTE: the npm package is
// "agora-token" (verified against registry.npmjs.org in Oct 2026 —
// "agora-token-builder" does not exist on npm; only the Dart/Flutter and
// Python Agora token packages use that name).
const { RtcTokenBuilder, RtcRole, ChatTokenBuilder } = require('agora-token');
require('dotenv').config();

// ============================================================
// CORS & ORIGIN VALIDATION (Comments 2 & 3)
// ============================================================
const defaultAllowedOrigins = [
  'http://localhost:3000',
  'https://inklink.web.app',
  'https://inklink.app',
];

// Comment 2: Do NOT treat '*' as allowed when credentials are enabled; require explicit origins.
const configuredOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',')
      .map(s => s.trim())
      .filter(s => s.length > 0 && s !== '*')
  : defaultAllowedOrigins;

const allowedOrigins = configuredOrigins.length > 0 ? configuredOrigins : defaultAllowedOrigins;

function isOriginAllowed(origin) {
  // Allow requests with no Origin header (such as native mobile apps or curl)
  if (!origin) return true;
  return allowedOrigins.includes(origin);
}

const corsOptions = {
  origin: (origin, callback) => {
    if (isOriginAllowed(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
};

const app = express();
app.use(cors(corsOptions));
// Parse JSON bodies for the Agora token routes below (Socket.IO is attached
// directly to the http server and is unaffected by this middleware).
app.use(express.json());

app.get('/health', (req, res) => {
  console.log("Ping Test");
  res.status(200).json({
    status: 'ok',
    time: new Date(),
  });
});

// ============================================================
// AGORA TOKEN HTTP ROUTES — per-user chat token + voice RTC token
// ============================================================
// Both routes verify a Firebase Auth ID token (same identity check as the
// Socket.IO handshake) and never log issued tokens. Socket.IO still carries
// live board traffic; these endpoints exist so the client can mint/renew
// tokens for the Agora-Chat SDK and for RTC voice joins.

app.post('/api/agora/chat/token', async (req, res) => {
  try {
    const decoded = await authenticateFirebaseRequest(req);
    if (!decoded) {
      console.warn('[agora-chat] /api/agora/chat/token → 401 (missing/invalid Firebase ID token)');
      return res.status(401).json({ error: 'unauthorized' });
    }

    if (!isAgoraChatConfigured()) {
      const cfg = getAgoraChatConfig();
      const missing = [
        ['AGORA_CHAT_ORG_NAME', cfg.orgName],
        ['AGORA_CHAT_APP_NAME', cfg.appName],
        ['AGORA_CHAT_REST_CLIENT_ID', cfg.clientId],
        ['AGORA_CHAT_REST_CLIENT_SECRET', cfg.clientSecret],
      ].filter(([, v]) => !v).map(([k]) => k);
      console.warn(`[agora-chat] /api/agora/chat/token → 503 (not configured; missing env: ${missing.join(', ')})`);
      // Client falls back to local-first chat mode when chat REST is not configured.
      return res.status(503).json({ error: 'agora chat not configured' });
    }

    // Must mirror the client's _sanitizeAgoraUid exactly so both sides
    // agree on the Agora Chat username.
    const agoraUsername = sanitizeAgoraUid(decoded.uid);
    const cacheKey = `agora_chat:token:${agoraUsername}`;

    // Redis-first: serve the cached token while it is still fresh (5 min headroom).
    if (redisAvailable) {
      const cachedRaw = await redis.get(cacheKey).catch(() => null);
      if (cachedRaw) {
        try {
          const cached = JSON.parse(cachedRaw);
          if (cached && cached.token && cached.expiresAt > Date.now() + 600000) {
            return res.status(200).json(cached);
          }
        } catch (_) { }
      }
    }

    const config = getAgoraChatConfig();
    const expirySeconds = config.tokenExpiryHours * 3600;

    const appToken = await getAgoraChatAppToken();
    await ensureAgoraChatUser(agoraUsername, appToken);
    const minted = await createAgoraChatUserToken(agoraUsername, expirySeconds);
    console.log(`[agora-chat] minted Chat user token for ${agoraUsername} (valid ${config.tokenExpiryHours}h, cache miss)`);

    const payload = {
      agoraUsername,
      appKey: `${config.orgName}#${config.appName}`,
      appId: process.env.AGORA_APP_ID || null,
      token: minted.token,
      expiresAt: minted.expiresAt,
    };

    // Cache TTL = token lifetime - 600s so the entry always outlives the token.
    if (redisAvailable) {
      const cacheTtl = Math.max(60, Math.floor((payload.expiresAt - Date.now()) / 1000) - 600);
      redis.set(cacheKey, JSON.stringify(payload), 'EX', cacheTtl).catch(() => { });
    }

    return res.status(200).json(payload);
  } catch (err) {
    console.error('[agora/chat/token] Error:', err);
    return res.status(502).json({ error: 'agora chat token request failed' });
  }
});

app.post('/api/agora/rtc/token', async (req, res) => {
  try {
    const decoded = await authenticateFirebaseRequest(req);
    if (!decoded) {
      console.warn('[agora-rtc] /api/agora/rtc/token → 401 (missing/invalid Firebase ID token)');
      return res.status(401).json({ error: 'unauthorized' });
    }

    const boardId = req.body?.boardId;
    if (!isValidBoardId(boardId)) {
      console.warn(`[agora-rtc] /api/agora/rtc/token → 400 (invalid board id "${boardId}")`);
      return res.status(400).json({ error: 'invalid_board_id' });
    }

    const hasAccess = await canUserAccessBoard(boardId, decoded.uid, false);
    if (!hasAccess) {
      console.warn(`[agora-rtc] /api/agora/rtc/token → 403 (uid ${decoded.uid} lacks access to board ${boardId})`);
      return res.status(403).json({ error: 'forbidden' });
    }

    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    if (!appId || !appCertificate) {
      const missing = [
        !appId ? 'AGORA_APP_ID' : null,
        !appCertificate ? 'AGORA_APP_CERTIFICATE' : null,
      ].filter(Boolean).join(', ');
      console.warn(`[agora-rtc] /api/agora/rtc/token → 503 (${missing} not configured)`);
      return res.status(503).json({ error: 'agora certificate not configured' });
    }

    const channelName = `board_${boardId}`;
    const { token, privilegeExpiredTs } = buildAgoraRtcToken(appId, appCertificate, channelName);
    console.log(`[agora-rtc] minted RTC token for ${decoded.uid} channel ${channelName} (valid 1h)`);
    return res.status(200).json({ appId, token, channelName, privilegeExpiredTs });
  } catch (err) {
    console.error('[agora/rtc/token] Error:', err);
    return res.status(500).json({ error: 'agora rtc token request failed' });
  }
});

const server = http.createServer(app);

// Comment 3: Explicit origin check for Socket.IO WebSocket handshakes via Engine.IO allowRequest
const io = new Server(server, {
  cors: corsOptions,
  allowRequest: (req, callback) => {
    const origin = req.headers.origin;
    if (isOriginAllowed(origin)) {
      return callback(null, true);
    }
    console.warn(`[Socket.IO handshake] Rejected unlisted origin: ${origin}`);
    return callback('Origin not allowed by CORS policy', false);
  },
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

// ============================================================
// REDIS SUBSCRIBER — Real-time Room Eviction
// ============================================================
const redisSub = new Redis(process.env.REDIS_URL || 'redis://127.0.0.1:6379', {
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

redisSub.on('ready', () => {
  redisSub.subscribe('board_events', (err) => {
    if (err) {
      console.warn('[board_events] Failed to subscribe:', err.message);
    } else {
      console.log('✓ Subscribed to board_events channel');
    }
  });
});

redisSub.on('error', (error) => {
  console.warn('⚠ Redis subscriber error:', error.message);
});

redisSub.on('message', async (channel, message) => {
  if (channel === 'board_events') {
    try {
      const data = JSON.parse(message);
      if (data.type === 'member_removed' && data.boardId && data.uid) {
        // Prune the server-side membership cache immediately so a removed
        // user can't keep socket-level access until the cache TTL expires.
        if (redisAvailable) {
          redis.srem(`board_members:${data.boardId}`, data.uid).catch(() => { });
        }
        const sockets = await io.in(`board_room:${data.boardId}`).fetchSockets();
        for (const s of sockets) {
          if (s.data.uid === data.uid) {
            s.leave(`board_room:${data.boardId}`);
            s.emit('board_access_revoked', { boardId: data.boardId, reason: 'removed' });
            console.log(`[board_events] Evicted user ${data.uid} from board_room:${data.boardId}`);
          }
        }
      } else if (data.type === 'board_deleted' && data.boardId) {
        if (redisAvailable) {
          redis.del(`board_members:${data.boardId}`).catch(() => { });
        }
        io.to(`board_room:${data.boardId}`).emit('board_access_revoked', { boardId: data.boardId, reason: 'deleted' });
        io.socketsLeave(`board_room:${data.boardId}`);
        console.log(`[board_events] Evicted all users from deleted board_room:${data.boardId}`);
      }
    } catch (e) {
      console.warn('[board_events] Failed to process event:', e.message);
    }
  }
});

// ============================================================
// BOARD AUTHORIZATION HELPER
// ============================================================
async function canUserAccessBoard(boardId, uid, requireEdit = false) {
  if (!uid || !boardId) return false;

  try {
    if (redisAvailable) {
      const isMember = await redis.sismember(`board_members:${boardId}`, uid);
      if (isMember && !requireEdit) {
        return true;
      }
    }

    if (db) {
      const boardDoc = await db.collection('boards').doc(boardId).get();
      if (!boardDoc.exists) return false;
      const data = boardDoc.data() || {};

      if (data.ownerId === uid) {
        if (redisAvailable) {
          const p = redis.pipeline();
          p.sadd(`board_members:${boardId}`, uid);
          p.expire(`board_members:${boardId}`, 86400);
          await p.exec().catch(() => { });
        }
        return true;
      }

      const members = Array.isArray(data.members) ? data.members : [];
      if (!members.includes(uid)) {
        return false;
      }

      if (requireEdit) {
        const memberDoc = await db.collection('boards').doc(boardId)
          .collection('members').doc(uid).get();
        if (memberDoc.exists) {
          const role = memberDoc.data()?.role;
          if (role === 'viewer') return false;
        }
      }

      if (redisAvailable) {
        const p = redis.pipeline();
        p.sadd(`board_members:${boardId}`, uid);
        p.expire(`board_members:${boardId}`, 86400);
        await p.exec().catch(() => { });
      }
      return true;
    }
  } catch (err) {
    console.warn(`[canUserAccessBoard] Error verifying access for ${uid} on ${boardId}:`, err.message);
    return false;
  }

  // Fail closed whenever membership cannot be positively verified
  return false;
}

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
// AGORA HELPERS — Chat REST + RTC token builder
// ============================================================
// Agora Chat REST credentials come from the Agora Console (Project → Chat →
// Overview: Client ID / Client Secret). The REST base URL is host-dependent —
// legacy apps use https://a1.easemob.com, newer apps are hosted at
// https://a???.chat.agora.io (read the exact URL from the console and set
// AGORA_CHAT_REST_BASE accordingly). Endpoint shapes verified against the
// official Agora Chat REST docs (Oct 2026):
//   App token:  POST {base}/{org}/{app}/token   {grant_type:'client_credentials', client_id, client_secret}
//                                              → 200 {access_token, expires_in(seconds), application}
//   Register:   POST {base}/{org}/{app}/users   body is an ARRAY [{username, password}]
//                                              duplicate user → HTTP 400 "duplicate_unique_property_exists"
//   User token: POST {base}/{org}/{app}/token   {grant_type:'inherit', username, autoCreateUser:true, ttl}
//                                              → 200 {access_token, expires_in, user}
//               (replaces the legacy form POST /{org}/{app}/users/{username}/token with {expiry})
//   Docs: https://docs.agora.io/en/chat/restful-api/user-account (resolved via doc.easemob.com)
// TODO: if a specific Easemob deployment (e.g. legacy/VIP5 cluster) still only
// serves the legacy /users/{username}/token form, switch the user-token call below.

// Voice-call RTC tokens live 1 hour (kept in lockstep with join_voice_call).
const AGORA_RTC_TOKEN_TTL_SECONDS = 3600;
// Refresh app tokens 5 minutes before their documented expiry.
const AGORA_CHAT_APP_TOKEN_HEADROOM_MS = 300000;

function getAgoraChatConfig() {
  return {
    restBase: (process.env.AGORA_CHAT_REST_BASE && process.env.AGORA_CHAT_REST_BASE !== 'https://a1.easemob.com') ? process.env.AGORA_CHAT_REST_BASE : (((process.env.AGORA_CHAT_APP_NAME || '').startsWith('61') || (process.env.AGORA_CHAT_ORG_NAME || '').startsWith('61')) ? 'https://a61.chat.agora.io' : (process.env.AGORA_CHAT_REST_BASE || 'https://a1.easemob.com')),
    orgName: (process.env.AGORA_CHAT_APP_NAME || '').includes('#') ? process.env.AGORA_CHAT_APP_NAME.split('#')[0] : (process.env.AGORA_CHAT_ORG_NAME || ''),
    appName: (process.env.AGORA_CHAT_APP_NAME || '').includes('#') ? process.env.AGORA_CHAT_APP_NAME.split('#')[1] : (process.env.AGORA_CHAT_APP_NAME || ''),
    clientId: process.env.AGORA_CHAT_REST_CLIENT_ID || '',
    clientSecret: process.env.AGORA_CHAT_REST_CLIENT_SECRET || '',
    // Per-user chat token lifetime (env is hours; default 24h).
    tokenExpiryHours: Math.max(1, parseInt(process.env.AGORA_CHAT_TOKEN_EXPIRY_HOURS, 10) || 24),
  };
}

function isAgoraChatConfigured() {
  const config = getAgoraChatConfig();
  return Boolean(config.orgName && config.appName && config.clientId && config.clientSecret);
}

// expires_in is documented in seconds; legacy (VIP5) Easemob clusters report
// milliseconds — treat implausibly large values as ms and normalize to seconds.
function normalizeAgoraExpirySeconds(expiresIn) {
  const value = Number(expiresIn);
  if (!Number.isFinite(value) || value <= 0) return null;
  return Math.floor(value > 31536000 ? value / 1000 : value);
}

let agoraChatAppTokenCache = null; // { token, expiresAt }

async function getAgoraChatAppToken() {
  if (!isAgoraChatConfigured()) {
    throw new Error('agora chat not configured');
  }
  const config = getAgoraChatConfig();
  const now = Date.now();

  if (agoraChatAppTokenCache && agoraChatAppTokenCache.token
    && agoraChatAppTokenCache.expiresAt > now + AGORA_CHAT_APP_TOKEN_HEADROOM_MS) {
    return agoraChatAppTokenCache.token;
  }

  if (redisAvailable) {
    const cachedRaw = await redis.get('agora_chat:app_token').catch(() => null);
    if (cachedRaw) {
      try {
        const cached = JSON.parse(cachedRaw);
        if (cached && cached.token && cached.expiresAt > now + AGORA_CHAT_APP_TOKEN_HEADROOM_MS) {
          agoraChatAppTokenCache = cached;
          return cached.token;
        }
      } catch (_) { }
    }
  }

  // Prefer local Agora AppToken generation via ChatTokenBuilder when AGORA_APP_ID & AGORA_APP_CERTIFICATE are set.
  if (process.env.AGORA_APP_ID && process.env.AGORA_APP_CERTIFICATE) {
    const ttlSeconds = 86400;
    const token = ChatTokenBuilder.buildAppToken(process.env.AGORA_APP_ID, process.env.AGORA_APP_CERTIFICATE, ttlSeconds);
    agoraChatAppTokenCache = { token, expiresAt: now + ttlSeconds * 1000 };
    if (redisAvailable) {
      await redis.set('agora_chat:app_token', JSON.stringify(agoraChatAppTokenCache), 'EX', ttlSeconds - 300).catch(() => { });
    }
    return token;
  }
  // Never log client secrets or token strings — only status + truncated error body.
  const response = await fetch(
    `${config.restBase}/${encodeURIComponent(config.orgName)}/${encodeURIComponent(config.appName)}/token`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        grant_type: 'client_credentials',
        client_id: config.clientId,
        client_secret: config.clientSecret,
      }),
    },
  );

  if (!response.ok) {
    const detail = (await response.text().catch(() => '')).slice(0, 300);
    console.warn(`[agora-chat] App token request failed: HTTP ${response.status} ${detail}`);
    throw new Error(`agora chat app token request failed (${response.status})`);
  }

  const data = await response.json();
  const expiresIn = normalizeAgoraExpirySeconds(data.expires_in);
  if (!data.access_token || !expiresIn) {
    throw new Error('agora chat app token response missing access_token/expires_in');
  }

  agoraChatAppTokenCache = { token: data.access_token, expiresAt: now + expiresIn * 1000 };

  // Cross-process cache: TTL = expires_in - 300s so it is refreshed before expiry.
  if (redisAvailable) {
    await redis.set('agora_chat:app_token', JSON.stringify(agoraChatAppTokenCache),
      'EX', Math.max(300, expiresIn - 300)).catch(() => { });
  }

  return agoraChatAppTokenCache.token;
}

async function ensureAgoraChatUser(username, appToken) {
  if (!isAgoraChatConfigured()) {
    throw new Error('agora chat not configured');
  }
  const config = getAgoraChatConfig();

  // Users log in with tokens only, so the password is a throwaway secret the
  // server never stores (Easemob requires one for registration; ≤64 chars).
  const password = crypto.randomBytes(24).toString('hex');

  const response = await fetch(
    `${config.restBase}/${encodeURIComponent(config.orgName)}/${encodeURIComponent(config.appName)}/users`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${appToken}`,
      },
      // Easemob's documented registration body is an array of users.
      body: JSON.stringify([{ username, password }]),
    },
  );

  if (response.ok) return true;

  const detail = (await response.text().catch(() => '')).slice(0, 300);
  let body = null;
  try { body = JSON.parse(detail); } catch (_) { }
  const duplicate = body?.error === 'duplicate_unique_property_exists'
    || (typeof detail === 'string' && detail.includes('requires that property named username be unique'));
  if (response.status === 400 && duplicate) {
    // "User already exists" — idempotent success.
    console.log(`[agora-chat] Chat user ${username} already registered`);
    return true;
  }

  if (response.status === 401 || response.status === 403) {
    // Auth failures are NOT swallowed — the app token itself is bad/expired.
    console.warn(`[agora-chat] User registration rejected: HTTP ${response.status} ${detail}`);
    throw new Error(`agora chat user registration rejected (${response.status})`);
  }

  // Pessimistic-but-idempotent: other failures (transient 5xx etc.) are
  // swallowed with a log — token minting below surfaces real problems anyway.
  console.warn(`[agora-chat] User registration failed (HTTP ${response.status}): ${detail}`);
  return false;
}

async function createAgoraChatUserToken(username, expirySeconds) {
  if (!isAgoraChatConfigured()) {
    throw new Error('agora chat not configured');
  }
  const config = getAgoraChatConfig();
  const appToken = await getAgoraChatAppToken();

  const response = await fetch(
    `${config.restBase}/${encodeURIComponent(config.orgName)}/${encodeURIComponent(config.appName)}/token`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${appToken}`,
      },
      body: JSON.stringify({
        grant_type: 'inherit',
        username,
        autoCreateUser: true,
        ttl: expirySeconds,
      }),
    },
  );

  if (!response.ok) {
    const detail = (await response.text().catch(() => '')).slice(0, 300);
    console.warn(`[agora-chat] User token request failed for ${username}: HTTP ${response.status} ${detail}`);
    throw new Error(`agora chat user token request failed (${response.status})`);
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new Error('agora chat user token response missing access_token');
  }
  // expires_in is documented in seconds (ms on legacy VIP5 clusters).
  const expiresIn = normalizeAgoraExpirySeconds(data.expires_in) || expirySeconds;
  return { token: data.access_token, expiresAt: Date.now() + expiresIn * 1000 };
}

// MUST mirror the client's _sanitizeAgoraUid
// (lib/domain/services/chat/agora_chat_service.dart): replace every char
// outside [a-zA-Z0-9_-] with '_' (the '-' sits last in the class so it stays
// literal), then lowercase.
function sanitizeAgoraUid(uid) {
  return String(uid).replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
}

// Server-side Firebase Auth check for the HTTP token routes — mirrors the
// transient-error fallback behavior of the Socket.IO handshake middleware.
async function authenticateFirebaseRequest(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return null;
  if (!db || !admin.apps || !admin.apps.length) return null;

  const idToken = header.slice('Bearer '.length).trim();
  try {
    return await admin.auth().verifyIdToken(idToken, true);
  } catch (error) {
    // Same transient fallback as the socket middleware: only when the
    // verification backend itself is unavailable, verify without the
    // revocation check — genuine invalid/revoked tokens still fail closed.
    const transient = error && (
      error.code === 'auth/internal-error' ||
      error.code === 'auth/network-error' ||
      error.code === 'auth/network-timeout' ||
      (typeof error.message === 'string' && error.message.includes('ETIMEDOUT'))
    );
    if (!transient) return null;
    console.warn('[agora] Revocation check unavailable, verifying without it:', error.message);
    try {
      return await admin.auth().verifyIdToken(idToken);
    } catch (_) {
      return null;
    }
  }
}

// Real RTC token for voice (replaces the old dummy token). uid 0 = wildcard:
// the token is valid for ANY client uid in `channelName`, since clients pick
// their own numeric uid. NOTE: agora-token@2.x (AccessToken2) interprets
// tokenExpire/privilegeExpire as RELATIVE seconds from now — pre-2.x builders
// took an absolute epoch there, which is why this is NOT
// `Math.floor(Date.now()/1000) + 3600` for the builder itself.
function buildAgoraRtcToken(appId, appCertificate, channelName) {
  const tokenExpire = AGORA_RTC_TOKEN_TTL_SECONDS;
  const token = RtcTokenBuilder.buildTokenWithUid(
    appId, appCertificate, channelName, 0, RtcRole.PUBLISHER, tokenExpire, tokenExpire,
  );
  // Absolute epoch (seconds) at which the token/privileges lapse — returned to
  // clients so they can renew via POST /api/agora/rtc/token.
  const privilegeExpiredTs = Math.floor(Date.now() / 1000) + tokenExpire;
  return { token, privilegeExpiredTs };
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
-- Refresh the version key TTL on every append so it can never expire while
-- the board is active (a version reset would rewind the snapshot cursor).
redis.call('EXPIRE', KEYS[1], 604800)
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
      const data = snap.data() || {};
      const p = redis.pipeline();
      if (data.lastAppliedVersion) {
        p.set(versionKey, data.lastAppliedVersion.toString(), 'EX', 604800);
        console.log(`[seed] Board ${boardId}: version seeded to ${data.lastAppliedVersion} from Firestore`);
      }
      if (data.lastAppliedStreamId) {
        p.set(`board:lastSnapshotCursor:${boardId}`, data.lastAppliedStreamId, 'EX', 604800);
        p.set(`board:lastSnapshotVersion:${boardId}`, (data.lastAppliedVersion || 0).toString(), 'EX', 604800);
      }
      await p.exec();
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

  // 1. Freeze target version and last cursor in a single round-trip MGET
  const [targetVerStr, lastVerStr, lastCursorStr] = await redis.mget(
    versionKey,
    snapshotVersionKey,
    snapshotCursorKey
  );
  const snapshotTargetVersion = parseInt(targetVerStr || '0', 10);
  const lastSnapshotVersion = parseInt(lastVerStr || '0', 10);
  if (snapshotTargetVersion <= lastSnapshotVersion) return;

  // 2. Read stream entries since last snapshot cursor — incremental, not full scan
  const lastCursor = lastCursorStr || '0-0';
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

  // 4. Build materialized Yjs doc state, starting from the prior snapshot if any
  const doc = new Y.Doc();
  if (lastSnapshotVersion > 0) {
    try {
      const prevSnap = await db.collection('boards').doc(boardId)
        .collection('snapshot').doc('latest').get();
      if (prevSnap.exists) {
        const prevStateUpdate = prevSnap.data().stateUpdate;
        if (prevStateUpdate) {
          Y.applyUpdate(doc, Buffer.from(prevStateUpdate, 'base64'));
        }
      }
    } catch (e) {
      console.warn(`[snapshot] Could not load prior snapshot for board ${boardId}: ${e.message} — rebuilding from stream`);
    }
  }
  for (const entry of entries) {
    // Single-user updates are persisted to the stream too — they must be
    // included in the snapshot or solo-board content would be lost.
    if (!entry.payloadBase64) continue;
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

    // 7 & 8. Update Redis cursor and trim stream at snapshot boundary atomically via pipeline
    const p = redis.pipeline();
    p.set(snapshotCursorKey, lastAppliedStreamId, 'EX', 604800);
    p.set(snapshotVersionKey, snapshotTargetVersion.toString(), 'EX', 604800);
    p.xtrim(streamKey, 'MINID', lastAppliedStreamId);
    await p.exec();

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

  stream.on('error', (err) => {
    // Without an error listener, an unhandled 'error' event on the stream
    // throws and kills the process.
    console.warn(`[cleanup] Scan stream error: ${err.message}`);
  });

  stream.on('data', async (keys) => {
    if (!keys || keys.length === 0) return;
    try {
      const activities = await redis.mget(...keys);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const boardId = key.replace('board:lastActivity:', '');
        const lastActivity = parseInt(activities[i] || '0', 10);
        if (lastActivity === 0 || lastActivity > threeDaysAgo) continue;
        console.log(`[cleanup] Board ${boardId} inactive > 3 days — taking snapshot`);
        await triggerSnapshot(boardId);
      }
    } catch (e) {
      console.warn(`[cleanup] Failed for keys batch: ${e.message}`);
    }
  });
}, 60 * 60 * 1000);

// Snapshot worker loop — persists pending stream updates to Firestore every
// 5 minutes. Without this, snapshots only happen on `% 100 === 0` appends or
// after 3 days of inactivity, so a crash could lose up to ~100 acknowledged
// updates for later joiners.
setInterval(async () => {
  if (!redisAvailable) return;
  const stream = redis.scanStream({ match: 'board:lastActivity:*', count: 100 });

  stream.on('error', (err) => {
    console.warn(`[snapshot-loop] Scan stream error: ${err.message}`);
  });

  stream.on('data', async (keys) => {
    if (!keys || keys.length === 0) return;
    for (const key of keys) {
      const boardId = key.replace('board:lastActivity:', '');
      try {
        const [verStr, snapVerStr] = await redis.mget(
          `board:${boardId}:version`,
          `board:lastSnapshotVersion:${boardId}`,
        );
        const version = parseInt(verStr || '0', 10) || 0;
        const snapshotVersion = parseInt(snapVerStr || '0', 10) || 0;
        if (version > snapshotVersion) {
          await triggerSnapshot(boardId);
        }
      } catch (e) {
        console.warn(`[snapshot-loop] Failed for board ${boardId}: ${e.message}`);
      }
    }
  });
}, 5 * 60 * 1000);

// ============================================================
// SOCKET.IO AUTH MIDDLEWARE
// ============================================================
io.use(async (socket, next) => {
  try {
    // Comment 3: Validate origin during Socket.IO connection initialization
    const origin = socket.handshake.headers.origin;
    if (origin && !isOriginAllowed(origin)) {
      console.warn(`[Socket.IO auth] Rejected unlisted origin: ${origin}`);
      return next(new Error('CORS error: Origin not allowed'));
    }

    const { token } = socket.handshake.auth;
    if (!token) return next(new Error('Authentication error: Token missing'));

    if (!db || !admin.apps || !admin.apps.length) {
      if (process.env.NODE_ENV === 'development' && process.env.ALLOW_DEV_AUTH === 'true') {
        socket.data.uid = socket.handshake.auth.uid || "test-user";
        return next();
      }
      return next(new Error('Authentication service unavailable'));
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(token, true);
    } catch (error) {
      // Fall back to a non-revocation check only when the verification
      // backend itself is unavailable (transient errors) — genuine
      // invalid/revoked tokens must still be rejected.
      const transient = error && (
        error.code === 'auth/internal-error' ||
        error.code === 'auth/network-error' ||
        error.code === 'auth/network-timeout' ||
        (typeof error.message === 'string' && error.message.includes('ETIMEDOUT'))
      );
      if (!transient) throw error;
      console.warn('[Socket.IO auth] Revocation check unavailable, verifying without it:', error.message);
      decodedToken = await admin.auth().verifyIdToken(token);
    }
    socket.data.uid = decodedToken.uid;
    next();
  } catch (error) {
    next(new Error('Authentication error: Invalid Token'));
  }
});

// ============================================================
// SOCKET.IO CONNECTION
// ============================================================
io.on('connection', (socket) => {
  const { uid } = socket.data;
  console.log(`User connected: ${uid} (socket: ${socket.id})`);

  // ----------------------------------------------------------
  // watch_board
  // ----------------------------------------------------------
  socket.on('watch_board', async (boardId, callback) => {
    if (!isValidBoardId(boardId)) {
      console.warn(`[watch_board] Invalid boardId from ${uid}`);
      if (typeof callback === 'function') callback({ status: 'error', message: 'invalid_board_id' });
      return;
    }

    const hasAccess = await canUserAccessBoard(boardId, uid, false);
    if (!hasAccess) {
      console.warn(`[watch_board] Forbidden: User ${uid} cannot access board ${boardId}`);
      if (typeof callback === 'function') callback({ status: 'error', message: 'forbidden' });
      return;
    }

    socket.join(`board_room:${boardId}`);
    socket.data.currentBoardId = boardId;
    console.log(`[watch_board] User ${uid} joined board ${boardId} (socket: ${socket.id})`);
    if (typeof callback === 'function') callback({ status: 'success', boardId });
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

    const canEdit = await canUserAccessBoard(boardId, uid, true);
    if (!canEdit) {
      console.warn(`[crdt_update] Forbidden: User ${uid} cannot edit board ${boardId}`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'forbidden' });
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
      // Single-user boards are persisted the same way (skip only the
      // broadcast below) so the snapshot worker durably stores them —
      // acking "success" without persisting would lose all solo work.
      // -------------------------------------------------------
      let version = null;
      let isDuplicate = false;

      if (redisAvailable) {
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
            redis.set(`board:lastActivity:${boardId}`, Date.now().toString(), 'EX', 604800).catch(() => { });
          }
        } catch (luaError) {
          console.warn(`[crdt_update] Lua script failed: ${luaError.message}`);
        }
      }

      if (isDuplicate) {
        // Duplicate: ack success but no broadcast (already broadcast the first time)
        if (typeof ack === 'function') {
          ack({ status: 'success', updateId: update.updateId, boardId, version: 0 });
        }
        return;
      }

      // If persistence failed (Redis unavailable or Lua error), reject so client retries
      if (version === null) {
        if (typeof ack === 'function') {
          ack({ status: 'error', message: 'persistence_unavailable' });
        }
        return;
      }

      // -------------------------------------------------------
      // Broadcast to room (with version for client cursor tracking).
      // Single-user boards skip the broadcast — no peers to relay to —
      // but the update is already durably appended to the stream above.
      // -------------------------------------------------------
      if (!isSingleUser) {
        const broadcastPayload = { boardId, update: { ...update, version } };
        socket.to(`board_room:${boardId}`).emit('crdt_update', broadcastPayload);
        console.log(`[WS UPDATE SENT] board_room:${boardId} updateId=${update.updateId} version=${version}`);
      }

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
        } catch (e) { }
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

    // Access check — previews are relayed into the board room; without this,
    // any connected socket could spam/deface previews on any board.
    const hasAccess = await canUserAccessBoard(boardId, uid, false);
    if (!hasAccess) {
      console.warn(`[crdt_preview] Forbidden: User ${uid} cannot access board ${boardId}`);
      if (typeof ack === 'function') ack({ status: 'error', message: 'forbidden' });
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

    const hasAccess = await canUserAccessBoard(boardId, uid, false);
    if (!hasAccess) {
      console.warn(`[sync_offline] Forbidden: User ${uid} cannot access board ${boardId}`);
      if (typeof callback === 'function') callback({ status: 'error', boardId, error: 'forbidden' });
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
        const cursorVersion = parseInt(lastSeenCursor.split(':')[1] || '0', 10);

        // If client cursor is behind the snapshot, the stream may have been trimmed.
        // Skip cursor sync and fall through to snapshot + delta path below.
        const snapVerKey = `board:lastSnapshotVersion:${boardId}`;
        const snapVer = parseInt(await redis.get(snapVerKey) || '0', 10);
        const needsSnapshot = snapVer > 0 && cursorVersion < snapVer;

        if (!needsSnapshot) {
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
            await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, newCursor, 'EX', 604800).catch(() => { });

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
        // Fall through to PATH 2 when client needs snapshot
      }

      // ============================================================
      // PATH 2 (SECONDARY): Snapshot + remaining deltas
      // ============================================================
      if (redisAvailable && db) {
        const snapshotCursorKey = `board:lastSnapshotCursor:${boardId}`;
        const snapshotVersionKey = `board:lastSnapshotVersion:${boardId}`;
        const lastSnapshotVersion = parseInt(await redis.get(snapshotVersionKey) || '0', 10);
        const lastServerVersion = parseInt(await redis.get(`board:${boardId}:version`) || '0', 10);

        // Use snapshot path if client has no cursor (fresh login) or cursor is behind snapshot
        const cursorVersion = lastSeenCursor ? parseInt(lastSeenCursor.split(':')[1] || '0', 10) : 0;
        const effectiveServerVersion = sinceVersion ?? cursorVersion;
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
            await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, newCursor, 'EX', 604800).catch(() => { });

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

        // Snapshot path didn't apply (no snapshot, or client is current).
        // Try reading any pending entries from the Redis stream directly
        // before giving up.  This handles boards with < 100 updates where
        // no snapshot has been created yet.
        const streamKey = `board_updates:${boardId}`;
        const raw = await redis.xread('COUNT', 100, 'STREAMS', streamKey, '0-0');
        if (raw && raw[0] && raw[0][1] && raw[0][1].length > 0) {
          const entries = raw[0][1];
          const updates = [];
          let lastEntryId = '0-0';
          let lastVer = 0;
          for (const [entryId, fields] of entries) {
            const entry = parseStreamEntry(fields);
            entry.appliedAt = entry.timestamp;
            updates.push(entry);
            lastEntryId = entryId;
            if (entry.version > lastVer) lastVer = entry.version;
          }
          const newCursor = `${lastEntryId}:${lastVer}`;
          await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, newCursor, 'EX', 604800).catch(() => { });

          logWsEvent('SYNC RESPONSE (stream catch-up)', [
            `[user] ${uid}`,
            `[board] ${boardId}`,
            `[updates] ${updates.length}`,
            `[cursor] ${newCursor}`,
          ]);

          if (typeof callback === 'function') {
            callback({ status: 'success', updates, cursor: newCursor, hasMore: entries.length >= 100, source: 'cursor' });
          }
          return;
        }

        // Stream is empty — seed cursor from current version
        const currentVersion = await redis.get(`board:${boardId}:version`) || '0';
        const dummyCursor = `0-0:${currentVersion}`;
        await redis.set(`user:lastSeenCursor:${uid}:${boardId}`, dummyCursor, 'EX', 604800).catch(() => { });

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

  // ============================================================
  // board_chat_message — IN-BOARD LIVE CHAT + REDIS HISTORY (Agora-only)
  // ============================================================
  socket.on('board_chat_message', async (data, ack) => {
    try {
      const boardId = data?.boardId;
      const messageObj = (data?.message && typeof data.message === 'object') ? data.message : (data || {});
      const rawText = messageObj?.text || data?.text || '';
      const text = String(rawText).trim();

      if (!isValidBoardId(boardId) || !text) {
        if (typeof ack === 'function') ack({ status: 'error', message: 'invalid_payload' });
        return;
      }

      const hasAccess = await canUserAccessBoard(boardId, uid, false);
      if (!hasAccess) {
        if (typeof ack === 'function') ack({ status: 'error', message: 'forbidden' });
        return;
      }

      const chatMessage = {
        // Doc/storage id is ALWAYS generated server-side — client-supplied ids
        // are never trusted (they could overwrite another user's message).
        id: `msg_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`,
        boardId,
        senderUid: uid,
        senderName: messageObj.senderName || data?.senderName || 'Anonymous',
        senderPhotoUrl: messageObj.senderPhotoUrl || data?.senderPhotoUrl || null,
        text: text.substring(0, 2000),
        timestamp: messageObj.timestamp || data?.timestamp || Date.now(),
      };

      // 1. Broadcast to all active board viewers in real-time.
      //    NOTE: board chat no longer persists to Firestore (Agora Chat
      //    migration) — accepted messages are broadcast live and stored in
      //    Redis history only. Redis persistence (AOF) must be enabled for
      //    history to survive restarts.
      io.to(`board_room:${boardId}`).emit('board_chat_message', chatMessage);

      // 2. Cache in Redis with TTL (BOARD_CHAT_HISTORY_TTL_DAYS, default 90 days)
      if (redisAvailable) {
        const historyKey = `board_chat:${boardId}:history`;
        const historyTtlDays = Math.max(1, parseInt(process.env.BOARD_CHAT_HISTORY_TTL_DAYS, 10) || 90);
        const payloadStr = JSON.stringify(chatMessage);
        await redis.rpush(historyKey, payloadStr);
        await redis.expire(historyKey, historyTtlDays * 86400);
      }

      if (typeof ack === 'function') ack({ status: 'success', message: chatMessage });
    } catch (err) {
      console.error('[board_chat_message] Error:', err);
      if (typeof ack === 'function') ack({ status: 'error', message: err.message });
    }
  });

  socket.on('get_board_chat_history', async ({ boardId, limit = 50 }, callback) => {
    try {
      if (!isValidBoardId(boardId)) {
        if (typeof callback === 'function') callback({ status: 'error', message: 'invalid_board_id' });
        return;
      }
      const hasAccess = await canUserAccessBoard(boardId, uid, false);
      if (!hasAccess) {
        if (typeof callback === 'function') callback({ status: 'error', message: 'forbidden' });
        return;
      }

      // Clamp to a sane range — unsanitized values (negative/NaN/huge) would
      // be passed straight into Redis queries.
      const historyLimit = Math.max(1, Math.min(200, Number(limit) || 50));

      // Redis-only: board chat no longer has a Firestore fallback (Agora
      // Chat migration). An empty/missing history list means no messages yet.
      if (redisAvailable) {
        const historyKey = `board_chat:${boardId}:history`;
        const raw = await redis.lrange(historyKey, -historyLimit, -1);
        const messages = (raw || []).map(r => JSON.parse(r));
        if (typeof callback === 'function') callback({ status: 'success', messages });
        return;
      }

      if (typeof callback === 'function') callback({ status: 'success', messages: [] });
    } catch (err) {
      console.error('[get_board_chat_history] Error:', err);
      if (typeof callback === 'function') callback({ status: 'error', message: err.message });
    }
  });

  // ============================================================
  // AGORA VOICE CALL SIGNALING & SESSION MANAGEMENT
  // ============================================================
  socket.on('join_voice_call', async (data, callback) => {
    try {
      const { boardId, displayName, photoUrl } = data || {};
      if (!isValidBoardId(boardId)) {
        console.warn(`[voice] join_voice_call rejected: invalid board id`);
        if (typeof callback === 'function') callback({ status: 'error', message: 'invalid_board_id' });
        return;
      }
      const hasAccess = await canUserAccessBoard(boardId, uid, false);
      if (!hasAccess) {
        console.warn(`[voice] join_voice_call rejected: uid ${uid} lacks access to board ${boardId}`);
        if (typeof callback === 'function') callback({ status: 'error', message: 'forbidden' });
        return;
      }

      const participant = {
        uid,
        displayName: displayName || 'Anonymous',
        photoUrl: photoUrl || null,
        joinedAt: Date.now(),
        isSpeaking: false,
        isMuted: false,
      };

      if (redisAvailable) {
        const voiceKey = `voice:board:${boardId}:participants`;
        await redis.hset(voiceKey, uid, JSON.stringify(participant));
        await redis.expire(voiceKey, 86400); // 24h TTL
      }

      socket.join(`board_voice:${boardId}`);
      socket.data.currentVoiceBoardId = boardId;

      // Voice events target the voice room — voice sockets only ever join
      // `board_voice:` (they never call watch_board), so emitting to
      // `board_room:` would leave participants blind to each other.
      io.to(`board_voice:${boardId}`).emit('voice_participant_joined', participant);

      const channelName = `board_${boardId}`;
      const appId = process.env.AGORA_APP_ID;
      const appCertificate = process.env.AGORA_APP_CERTIFICATE;
      if (!appId || !appCertificate) {
        console.warn(`[voice] Agora RTC not configured (AGORA_APP_ID/AGORA_APP_CERTIFICATE); rejecting join from ${uid}`);
        if (typeof callback === 'function') callback({ status: 'error', message: 'agora certificate not configured' });
        return;
      }

      const { token } = buildAgoraRtcToken(appId, appCertificate, channelName);

      console.log(`[voice] User ${uid} joined voice channel ${channelName}`);
      if (typeof callback === 'function') {
        callback({
          status: 'success',
          channelName,
          appId,
          token,
          participant,
        });
      }
    } catch (err) {
      console.error('[join_voice_call] Error:', err);
      if (typeof callback === 'function') callback({ status: 'error', message: err.message });
    }
  });

  socket.on('leave_voice_call', async (data, callback) => {
    try {
      const boardId = data?.boardId || socket.data.currentVoiceBoardId;
      if (boardId) {
        if (redisAvailable) {
          const voiceKey = `voice:board:${boardId}:participants`;
          await redis.hdel(voiceKey, uid);
        }
        socket.leave(`board_voice:${boardId}`);
        socket.data.currentVoiceBoardId = null;
        io.to(`board_voice:${boardId}`).emit('voice_participant_left', { uid, boardId });
        console.log(`[voice] User ${uid} left voice channel board_${boardId}`);
      }
      if (typeof callback === 'function') callback({ status: 'success' });
    } catch (err) {
      console.error('[leave_voice_call] Error:', err);
      if (typeof callback === 'function') callback({ status: 'error', message: err.message });
    }
  });

  socket.on('voice_speaking_state', async ({ boardId, isSpeaking, isMuted }) => {
    try {
      if (!isValidBoardId(boardId)) return;
      // Access check — without it any connected socket could spam fake
      // speaking-state updates into any board's voice room.
      const hasAccess = await canUserAccessBoard(boardId, uid, false);
      if (!hasAccess) return;
      if (redisAvailable) {
        const voiceKey = `voice:board:${boardId}:participants`;
        const raw = await redis.hget(voiceKey, uid);
        if (raw) {
          const p = JSON.parse(raw);
          if (isSpeaking !== undefined) p.isSpeaking = !!isSpeaking;
          if (isMuted !== undefined) p.isMuted = !!isMuted;
          await redis.hset(voiceKey, uid, JSON.stringify(p));
        }
      }
      io.to(`board_voice:${boardId}`).emit('voice_speaking_changed', {
        uid,
        isSpeaking: !!isSpeaking,
        isMuted: !!isMuted,
      });
    } catch (_) { }
  });

  socket.on('get_voice_participants', async ({ boardId }, callback) => {
    try {
      if (!isValidBoardId(boardId)) {
        if (typeof callback === 'function') callback({ status: 'error', message: 'invalid_board_id' });
        return;
      }
      const hasAccess = await canUserAccessBoard(boardId, uid, false);
      if (!hasAccess) {
        if (typeof callback === 'function') callback({ status: 'error', message: 'forbidden' });
        return;
      }
      if (redisAvailable) {
        const voiceKey = `voice:board:${boardId}:participants`;
        const rawMap = await redis.hgetall(voiceKey);
        const participants = Object.values(rawMap || {}).map(v => JSON.parse(v));
        if (typeof callback === 'function') callback({ status: 'success', participants });
        return;
      }
      if (typeof callback === 'function') callback({ status: 'success', participants: [] });
    } catch (err) {
      if (typeof callback === 'function') callback({ status: 'error', message: err.message });
    }
  });

  // ----------------------------------------------------------
  // disconnect
  // ----------------------------------------------------------
  socket.on('disconnect', async () => {
    console.log(`[WS DISCONNECT] user=${uid} socket=${socket.id}`);
    socketEventCounts.delete(socket.id);
    const voiceBoardId = socket.data.currentVoiceBoardId;
    if (voiceBoardId) {
      try {
        if (redisAvailable) {
          await redis.hdel(`voice:board:${voiceBoardId}:participants`, uid);
        }
        io.to(`board_voice:${voiceBoardId}`).emit('voice_participant_left', { uid, boardId: voiceBoardId });
      } catch (_) { }
    }
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

  // One-time Agora config audit so a later 503/'not configured' response is
  // diagnosable from these logs alone. Secrets are never printed — only
  // presence booleans (org/app names and the REST base are identifiers).
  const rtcReady = Boolean(process.env.AGORA_APP_ID && process.env.AGORA_APP_CERTIFICATE);
  const chatCfg = getAgoraChatConfig();
  console.log('[agora] config audit:');
  console.log(`  AGORA_APP_ID: ${process.env.AGORA_APP_ID ? 'set' : 'MISSING'}`);
  console.log(`  AGORA_APP_CERTIFICATE: ${process.env.AGORA_APP_CERTIFICATE ? 'set' : 'MISSING'}`);
  console.log(`  → RTC voice tokens: ${rtcReady ? 'ready' : 'disabled (voice joins will fail)'}`);
  if (chatCfg.orgName || chatCfg.appName || chatCfg.clientId || chatCfg.clientSecret) {
    console.log(`  AGORA_CHAT_REST_BASE: ${chatCfg.restBase}`);
    console.log(`  AGORA_CHAT_ORG_NAME: ${chatCfg.orgName || 'MISSING'}`);
    console.log(`  AGORA_CHAT_APP_NAME: ${chatCfg.appName || 'MISSING'}`);
    console.log(`  AGORA_CHAT_REST_CLIENT_ID: ${chatCfg.clientId ? 'set' : 'MISSING'}`);
    console.log(`  AGORA_CHAT_REST_CLIENT_SECRET: ${chatCfg.clientSecret ? 'set' : 'MISSING'}`);
  } else {
    console.log('  AGORA_CHAT_* (org/app/client id/secret): all absent');
  }
  console.log(`  → Agora Chat tokens: ${isAgoraChatConfigured()
    ? `ready (appKey ${chatCfg.orgName}#${chatCfg.appName}, base ${chatCfg.restBase})`
    : 'disabled (clients will run chat in local-first mode)'}`);
});

// Graceful shutdown
async function gracefulShutdown(signal) {
  console.log(`\nReceived ${signal}, shutting down gracefully...`);

  // Snapshot boards that still have unsnapshotted updates so acknowledged
  // CRDT ops aren't lost between the last %100 snapshot and shutdown.
  try {
    if (redisAvailable) {
      const sockets = await io.fetchSockets();
      const boardIds = new Set(
        sockets.map(s => s.data?.currentBoardId).filter(Boolean),
      );
      for (const boardId of boardIds) {
        try {
          await triggerSnapshot(boardId);
        } catch (e) {
          console.warn(`[shutdown] Snapshot failed for board ${boardId}: ${e.message}`);
        }
      }
    }
  } catch (e) {
    console.warn(`[shutdown] Pre-shutdown snapshot pass failed: ${e.message}`);
  }

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
