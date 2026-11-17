/**
 * Hand-written fakes for the AI function tests. No Firebase, R2 or network.
 */

const sharp = require('sharp');
const { parseAiImageUrl, aiImageUrl } = require('../../src/ai/ai_storage_utils');

/** Minimal in-memory Firestore: collection().doc() paths, get/set, transactions. */
function createFakeFirestore(initial = {}) {
  const docs = new Map(Object.entries(initial));

  function docRef(path) {
    return {
      path,
      async get() {
        const data = docs.get(path);
        return { exists: data !== undefined, data: () => data };
      },
      async set(value, options) {
        const merged = options?.merge ? { ...(docs.get(path) || {}), ...value } : { ...value };
        docs.set(path, merged);
      },
      collection: (name) => collectionRef(`${path}/${name}`),
    };
  }

  function collectionRef(path) {
    return { doc: (id) => docRef(`${path}/${id}`) };
  }

  return {
    docs,
    collection: collectionRef,
    async runTransaction(fn) {
      const transaction = {
        get: (ref) => ref.get(),
        set: (ref, value, options) => {
          ref.set(value, options);
        },
      };
      return fn(transaction);
    },
  };
}

const TEST_ENV = {
  CLOUDFLARE_ACCOUNT_ID: 'test-account',
  CLOUDFLARE_R2_ACCESS_KEY: 'test-access',
  CLOUDFLARE_R2_SECRET_KEY: 'test-secret',
  CLOUDFLARE_R2_BUCKET: 'test-bucket',
  CLOUDFLARE_R2_PUBLIC_URL: 'https://cdn.example.test',
};

/** In-memory storage with the same interface as createR2Storage(). */
function createFakeStorage({ configured = true } = {}) {
  const objects = new Map();
  return {
    objects,
    assertConfigured() {
      if (!configured) {
        const { HttpsError } = require('firebase-functions/v2/https');
        throw new HttpsError('failed-precondition', 'Server storage configuration is incomplete.');
      }
    },
    parseSourceUrl: (url, boardId) => parseAiImageUrl(url, boardId, TEST_ENV),
    async upload({ boardId, generationId, pngBuffer }) {
      objects.set(`ai-images/${boardId}/${generationId}.png`, pngBuffer);
      return aiImageUrl(boardId, generationId, TEST_ENV);
    },
    async download(key) {
      const value = objects.get(key);
      if (!value) {
        const { HttpsError } = require('firebase-functions/v2/https');
        throw new HttpsError('not-found', 'The source image no longer exists.');
      }
      return value;
    },
  };
}

function createSilentLogger() {
  const calls = [];
  const record = (level) => (message, data) => calls.push({ level, message, data });
  return {
    calls,
    info: record('info'),
    warn: record('warn'),
    error: record('error'),
    debug: record('debug'),
  };
}

async function solidPng(width, height, colour) {
  return sharp({ create: { width, height, channels: 3, background: colour } })
    .png()
    .toBuffer();
}

/** Black mask with a white rectangle. */
async function rectMaskPng(width, height, rect) {
  const white = await sharp({
    create: { width: rect.width, height: rect.height, channels: 3, background: '#ffffff' },
  })
    .png()
    .toBuffer();
  return sharp({ create: { width, height, channels: 3, background: '#000000' } })
    .composite([{ input: white, left: rect.left, top: rect.top }])
    .png()
    .toBuffer();
}

async function pixelAt(buffer, x, y) {
  const { data, info } = await sharp(buffer)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const offset = (y * info.width + x) * info.channels;
  return [data[offset], data[offset + 1], data[offset + 2]];
}

module.exports = {
  TEST_ENV,
  createFakeFirestore,
  createFakeStorage,
  createSilentLogger,
  solidPng,
  rectMaskPng,
  pixelAt,
};
