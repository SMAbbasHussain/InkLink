// functions/src/utils/r2_history.js
// Paginated purge of a board's PRIVATE history prefix
// (blocks + milestones). Mirrors server/src/history/r2.js.
const {
  S3Client,
  ListObjectsV2Command,
  DeleteObjectsCommand,
} = require('@aws-sdk/client-s3');

function buildClient() {
  return new S3Client({
    region: 'auto',
    credentials: {
      accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY,
      secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_KEY,
    },
    endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  });
}

async function purgeBoardPrefix(boardId) {
  const bucket = process.env.CLOUDFLARE_R2_HISTORY_BUCKET;
  if (!bucket || !boardId) return;
  if (!process.env.CLOUDFLARE_ACCOUNT_ID
    || !process.env.CLOUDFLARE_R2_ACCESS_KEY
    || !process.env.CLOUDFLARE_R2_SECRET_KEY) {
    return;
  }

  const client = buildClient();
  let token;
  do {
    const listed = await client.send(new ListObjectsV2Command({
      Bucket: bucket,
      Prefix: `${boardId}/`,
      ContinuationToken: token,
    }));
    const keys = (listed.Contents || []).map(o => ({ Key: o.Key }));
    if (keys.length) {
      await client.send(new DeleteObjectsCommand({
        Bucket: bucket,
        Delete: { Objects: keys },
      }));
    }
    token = listed.IsTruncated ? listed.NextContinuationToken : undefined;
  } while (token);
}

module.exports = { purgeBoardPrefix };
