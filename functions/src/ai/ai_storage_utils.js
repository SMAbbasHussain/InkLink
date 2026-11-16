/**
 * Cloudflare R2 storage for AI images.
 *
 * Objects live at `ai-images/{boardId}/{generationId}.png`. The client setup
 * is copied from src/profile/upload_profile_photo.js (same secrets); that file
 * is intentionally left untouched.
 *
 * Ends in `_utils.js` so functions/index.js does not export it.
 */

const { HttpsError } = require('firebase-functions/v2/https');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');

const AI_IMAGE_PREFIX = 'ai-images';
const REQUIRED_R2_ENV = [
  'CLOUDFLARE_ACCOUNT_ID',
  'CLOUDFLARE_R2_ACCESS_KEY',
  'CLOUDFLARE_R2_SECRET_KEY',
  'CLOUDFLARE_R2_BUCKET',
  'CLOUDFLARE_R2_PUBLIC_URL',
];
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function assertStorageConfigured(env = process.env) {
  const missing = REQUIRED_R2_ENV.filter(
    (key) => !env[key] || String(env[key]).trim().length === 0,
  );
  if (missing.length > 0) {
    throw new HttpsError(
      'failed-precondition',
      'Server storage configuration is incomplete. Contact support.',
      { missing },
    );
  }
}

function publicBase(env = process.env) {
  return String(env.CLOUDFLARE_R2_PUBLIC_URL || '').trim().replace(/\/+$/, '');
}

function aiImageKey(boardId, generationId) {
  return `${AI_IMAGE_PREFIX}/${boardId}/${generationId}.png`;
}

function aiImageUrl(boardId, generationId, env = process.env) {
  return `${publicBase(env)}/${aiImageKey(boardId, generationId)}`;
}

/**
 * Returns the R2 object key for `sourceImageUrl` only when the URL is one of
 * OUR AI images for THIS board. Anything else is rejected, so the functions
 * can never be used to fetch an arbitrary URL.
 */
function parseAiImageUrl(sourceImageUrl, boardId, env = process.env) {
  const invalid = () =>
    new HttpsError('invalid-argument', 'sourceImageUrl is not an AI image from this board.');

  if (typeof sourceImageUrl !== 'string') throw invalid();
  const base = publicBase(env);
  if (!base || !SAFE_ID.test(String(boardId))) throw invalid();

  const prefix = `${base}/${AI_IMAGE_PREFIX}/${boardId}/`;
  const url = sourceImageUrl.trim();
  if (!url.startsWith(prefix)) throw invalid();

  const fileName = url.substring(prefix.length);
  if (!fileName.endsWith('.png')) throw invalid();
  const generationId = fileName.slice(0, -'.png'.length);
  if (!SAFE_ID.test(generationId)) throw invalid();

  return aiImageKey(boardId, generationId);
}

function createR2Client(env = process.env) {
  return new S3Client({
    region: 'auto',
    credentials: {
      accessKeyId: env.CLOUDFLARE_R2_ACCESS_KEY,
      secretAccessKey: env.CLOUDFLARE_R2_SECRET_KEY,
    },
    endpoint: `https://${env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  });
}

/** Default storage backed by R2. Tests pass their own object instead. */
function createR2Storage(env = process.env) {
  let client = null;
  const getClient = () => {
    if (!client) client = createR2Client(env);
    return client;
  };

  return {
    assertConfigured: () => assertStorageConfigured(env),

    parseSourceUrl: (sourceImageUrl, boardId) =>
      parseAiImageUrl(sourceImageUrl, boardId, env),

    async upload({ boardId, generationId, pngBuffer }) {
      await getClient().send(
        new PutObjectCommand({
          Bucket: env.CLOUDFLARE_R2_BUCKET,
          Key: aiImageKey(boardId, generationId),
          Body: pngBuffer,
          ContentType: 'image/png',
        }),
      );
      return aiImageUrl(boardId, generationId, env);
    },

    async download(key) {
      let response;
      try {
        response = await getClient().send(
          new GetObjectCommand({ Bucket: env.CLOUDFLARE_R2_BUCKET, Key: key }),
        );
      } catch (error) {
        if (error?.name === 'NoSuchKey' || error?.$metadata?.httpStatusCode === 404) {
          throw new HttpsError('not-found', 'The source image no longer exists.');
        }
        throw error;
      }
      return Buffer.from(await response.Body.transformToByteArray());
    },
  };
}

module.exports = {
  AI_IMAGE_PREFIX,
  assertStorageConfigured,
  aiImageKey,
  aiImageUrl,
  parseAiImageUrl,
  createR2Storage,
};
