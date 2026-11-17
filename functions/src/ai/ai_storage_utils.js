/**
 * Cloudflare R2 storage for AI images.
 *
 * Objects live at `ai-images/{boardId}/{generationId}.png`. The client setup
 * is copied from src/profile/upload_profile_photo.js (same secrets); that file
 * is intentionally left untouched.
 *
 * Ends in `_utils.js` so functions/index.js does not export it.
 */

const fs = require('fs/promises');
const os = require('os');
const path = require('path');
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

// ──────────────────────────────────────────────
// Local storage: Functions EMULATOR ONLY
// ──────────────────────────────────────────────
// Lets a developer without access to the R2 secrets test the AI feature on a
// phone. Images are written to a folder on the PC and served by
// scripts/serve_local_ai_images.js. It is used only when BOTH
// FUNCTIONS_EMULATOR=true (set by the emulator itself, never in production)
// and AI_LOCAL_STORAGE=true (set in functions/.env.local).

const DEFAULT_LOCAL_IMAGE_BASE_URL = 'http://127.0.0.1:5005';

function localStorageDir(env = process.env) {
  const configured = String(env.AI_LOCAL_STORAGE_DIR || '').trim();
  return configured || path.join(os.tmpdir(), 'inklink-ai-local-images');
}

function isLocalStorageEnabled(env = process.env) {
  return (
    String(env.FUNCTIONS_EMULATOR || '').trim().toLowerCase() === 'true' &&
    String(env.AI_LOCAL_STORAGE || '').trim().toLowerCase() === 'true'
  );
}

function createLocalStorage(env = process.env) {
  const dir = localStorageDir(env);
  const base = String(env.AI_LOCAL_IMAGE_BASE_URL || DEFAULT_LOCAL_IMAGE_BASE_URL).trim();
  // Reuse the R2 URL helpers with the local base so URL validation is identical.
  const localEnv = { CLOUDFLARE_R2_PUBLIC_URL: base };

  return {
    assertConfigured: () => {},

    parseSourceUrl: (sourceImageUrl, boardId) =>
      parseAiImageUrl(sourceImageUrl, boardId, localEnv),

    async upload({ boardId, generationId, pngBuffer }) {
      const file = path.join(dir, aiImageKey(boardId, generationId));
      await fs.mkdir(path.dirname(file), { recursive: true });
      await fs.writeFile(file, pngBuffer);
      return aiImageUrl(boardId, generationId, localEnv);
    },

    async download(key) {
      try {
        return await fs.readFile(path.join(dir, key));
      } catch (error) {
        if (error?.code === 'ENOENT') {
          throw new HttpsError('not-found', 'The source image no longer exists.');
        }
        throw error;
      }
    },
  };
}

/** R2 in production; local folder only inside the emulator when opted in. */
function createAiStorage(env = process.env) {
  return isLocalStorageEnabled(env) ? createLocalStorage(env) : createR2Storage(env);
}

module.exports = {
  AI_IMAGE_PREFIX,
  assertStorageConfigured,
  aiImageKey,
  aiImageUrl,
  parseAiImageUrl,
  createR2Storage,
  DEFAULT_LOCAL_IMAGE_BASE_URL,
  localStorageDir,
  isLocalStorageEnabled,
  createLocalStorage,
  createAiStorage,
};
