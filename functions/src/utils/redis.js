const path = require('path');

let redisClient = null;
let redisAvailable = false;

function getRedisClient() {
  if (redisClient) return redisClient;

  const url = process.env.REDIS_URL;
  if (!url) {
    try {
      require('dotenv').config({ path: path.join(__dirname, '../../../server/.env') });
    } catch (_) {}
    const url2 = process.env.REDIS_URL;
    if (!url2) return null;
    return _createClient(url2);
  }

  return _createClient(url);
}

function _createClient(url) {
  const Redis = require('ioredis');
  redisClient = new Redis(url);
  redisClient.on('connect', () => { redisAvailable = true; });
  redisClient.on('error', (e) => {
    redisAvailable = false;
    console.warn('Redis unavailable:', e.message);
  });
  return redisClient;
}

async function addBoardMember(boardId, uid) {
  try {
    const client = getRedisClient();
    if (!client) return;
    const key = `board_members:${boardId}`;
    await client.sadd(key, uid);
    await client.expire(key, 604800);
  } catch (_) {}
}

async function removeBoardMember(boardId, uid) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.srem(`board_members:${boardId}`, uid);
  } catch (_) {}
}

async function addBoardMembers(boardId, uids) {
  try {
    const client = getRedisClient();
    if (!client || !Array.isArray(uids) || uids.length === 0) return;
    const key = `board_members:${boardId}`;
    await client.sadd(key, ...uids);
    await client.expire(key, 604800);
  } catch (_) {}
}

async function deleteBoardMembers(boardId) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.del(`board_members:${boardId}`);
  } catch (_) {}
}

async function publishBoardEvent(event) {
  try {
    const client = getRedisClient();
    if (!client) return;
    await client.publish('board_events', JSON.stringify(event));
  } catch (_) {}
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
  } catch (_) {}
}

module.exports = {
  addBoardMember,
  removeBoardMember,
  deleteBoardMembers,
  addBoardMembers,
  publishBoardEvent,
  deleteBoardState,
};
