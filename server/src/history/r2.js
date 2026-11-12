// server/src/history/r2.js
// Private Cloudflare R2 client for board history (bucket inklink-board-history).
// NEVER point this at the public profile-photo bucket (D7).
const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  DeleteObjectsCommand,
} = require('@aws-sdk/client-s3');
const zlib = require('zlib');

const BUCKET = process.env.CLOUDFLARE_R2_HISTORY_BUCKET;

const client = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY,
    secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_KEY,
  },
});

function assertConfigured() {
  if (!BUCKET || !process.env.CLOUDFLARE_ACCOUNT_ID
    || !process.env.CLOUDFLARE_R2_ACCESS_KEY || !process.env.CLOUDFLARE_R2_SECRET_KEY) {
    throw new Error('board history R2 is not configured (CLOUDFLARE_R2_HISTORY_BUCKET)');
  }
}

async function putGzip(key, jsonObj) {
  assertConfigured();
  const body = zlib.gzipSync(Buffer.from(JSON.stringify(jsonObj)));
  await client.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: body,
    ContentType: 'application/gzip',
  }));
}

async function putBytesGzip(key, buffer) {
  assertConfigured();
  await client.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: zlib.gzipSync(buffer),
    ContentType: 'application/gzip',
  }));
}

async function getGzipJson(key) {
  assertConfigured();
  const res = await client.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
  const chunks = [];
  for await (const c of res.Body) chunks.push(c);
  return JSON.parse(zlib.gunzipSync(Buffer.concat(chunks)).toString('utf8'));
}

async function getBytesGzip(key) {
  assertConfigured();
  const res = await client.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
  const chunks = [];
  for await (const c of res.Body) chunks.push(c);
  return zlib.gunzipSync(Buffer.concat(chunks));
}

// Paginated purge of a board prefix (blocks + milestones).
async function purgeBoardPrefix(boardId) {
  assertConfigured();
  let token;
  do {
    const listed = await client.send(new ListObjectsV2Command({
      Bucket: BUCKET,
      Prefix: `${boardId}/`,
      ContinuationToken: token,
    }));
    const keys = (listed.Contents || []).map(o => ({ Key: o.Key }));
    if (keys.length) {
      await client.send(new DeleteObjectsCommand({
        Bucket: BUCKET,
        Delete: { Objects: keys },
      }));
    }
    token = listed.IsTruncated ? listed.NextContinuationToken : undefined;
  } while (token);
}

// List milestone versions for a board (keys: {id}/milestones/state_v{N}.bin.gz).
async function listMilestoneVersions(boardId) {
  assertConfigured();
  const versions = [];
  let token;
  do {
    const listed = await client.send(new ListObjectsV2Command({
      Bucket: BUCKET,
      Prefix: `${boardId}/milestones/`,
      ContinuationToken: token,
    }));
    for (const o of (listed.Contents || [])) {
      const m = /state_v(\d+)\.bin\.gz$/.exec(o.Key);
      if (m) versions.push(parseInt(m[1], 10));
    }
    token = listed.IsTruncated ? listed.NextContinuationToken : undefined;
  } while (token);
  return versions.sort((a, b) => a - b);
}

module.exports = {
  putGzip,
  putBytesGzip,
  getGzipJson,
  getBytesGzip,
  purgeBoardPrefix,
  listMilestoneVersions,
  BUCKET,
};
