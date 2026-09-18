const path = require('path');

let redisClient = null;

function getRedisClient() {
  if (redisClient) return redisClient;

  // 1. Prefer @upstash/redis REST client if REST credentials are provided
  // (Optimal for serverless environments: zero connection overhead, stateless HTTP)
  const restUrl = process.env.UPSTASH_REDIS_REST_URL;
  const restToken = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (restUrl && restToken) {
    try {
      const { Redis: UpstashRedis } = require('@upstash/redis');
      redisClient = new UpstashRedis({
        url: restUrl,
        token: restToken,
      });
      return redisClient;
    } catch (err) {
      console.warn('Failed to initialize @upstash/redis client:', err.message);
    }
  }

  // 2. Fallback to ioredis if REDIS_URL is provided (local dev / Docker / TCP)
  const url = process.env.REDIS_URL;
  if (!url) {
    try {
      require('dotenv').config({ path: path.join(__dirname, '../../../server/.env') });
    } catch (_) {}
    const fallbackUrl = process.env.REDIS_URL;
    if (!fallbackUrl) return null;
    return _createIoRedisClient(fallbackUrl);
  }

  return _createIoRedisClient(url);
}

function _createIoRedisClient(url) {
  try {
    const IORedis = require('ioredis');
    redisClient = new IORedis(url, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      connectTimeout: 5000,
    });
    redisClient.on('error', (e) => {
      console.warn('Redis unavailable:', e.message);
    });
    return redisClient;
  } catch (err) {
    console.warn('Failed to create ioredis client:', err.message);
    return null;
  }
}

async function addBoardMember(boardId, uid) {
  try {
    const client = getRedisClient();
    if (!client) return;
    const key = `board_members:${boardId}`;
    const p = client.pipeline();
    p.sadd(key, uid);
    p.expire(key, 604800);
    await p.exec();
  } catch (e) {
    console.warn(`[redis] addBoardMember failed for board ${boardId}:`, e.message);
  }
}

async function removeBoardMember(boardId, uid) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.srem(`board_members:${boardId}`, uid);
  } catch (e) {
    console.warn(`[redis] removeBoardMember failed for board ${boardId}:`, e.message);
  }
}

async function addBoardMembers(boardId, uids) {
  try {
    const client = getRedisClient();
    if (!client || !Array.isArray(uids) || uids.length === 0) return;
    const key = `board_members:${boardId}`;
    const p = client.pipeline();
    p.sadd(key, ...uids);
    p.expire(key, 604800);
    await p.exec();
  } catch (e) {
    console.warn(`[redis] addBoardMembers failed for board ${boardId}:`, e.message);
  }
}

async function deleteBoardMembers(boardId) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.del(`board_members:${boardId}`);
  } catch (e) {
    console.warn(`[redis] deleteBoardMembers failed for board ${boardId}:`, e.message);
  }
}

async function publishBoardEvent(event) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.publish('board_events', JSON.stringify(event));
  } catch (e) {
    console.warn('[redis] publishBoardEvent failed:', e.message);
  }
}

async function deleteBoardState(boardId) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.del(
      `board_members:${boardId}`,
      `board:${boardId}:version`,
      `board_updates:${boardId}`,
      `board:dedup:${boardId}`,
      `board:lastActivity:${boardId}`,
      `board:lastSnapshotCursor:${boardId}`,
      `board:lastSnapshotVersion:${boardId}`
    );
  } catch (e) {
    console.warn(`[redis] deleteBoardState failed for board ${boardId}:`, e.message);
  }
}

module.exports = {
  addBoardMember,
  removeBoardMember,
  deleteBoardMembers,
  addBoardMembers,
  publishBoardEvent,
  deleteBoardState,
};
