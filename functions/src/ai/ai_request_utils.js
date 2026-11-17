/**
 * Shared request pipeline for the three AI callables
 * (generateAiImage, editAiImage, inpaintAiImage):
 *
 *   auth → validate → edit access → reserve daily slot → provider (60s)
 *   → PNG → R2 upload → thumbnail → ai_generations record → response
 *
 * The slot is refunded on any failure after it was reserved.
 *
 * Dependencies (Firestore, storage, provider) are injectable so the pipeline
 * can be tested without Firebase, R2 or the network.
 *
 * Ends in `_utils.js` so functions/index.js does not export it.
 */

const crypto = require('crypto');
const { HttpsError } = require('firebase-functions/v2/https');
const {
  ASPECT_RATIOS,
  PROVIDER_TIMEOUT_MS,
  AiProviderError,
  normalizeToPng,
  makeThumbnail,
  getProvider,
} = require('./ai_provider_utils');
const { assertBoardEditAccess } = require('./ai_access_utils');
const { reserveDailySlot, refundDailySlot, getDailyLimit } = require('./ai_usage_utils');
const { createAiStorage } = require('./ai_storage_utils');

const AI_GENERATIONS_COLLECTION = 'ai_generations';
const MAX_PROMPT_LENGTH = 1000;
const MAX_MASK_BYTES = 4 * 1024 * 1024;
const DEFAULT_STRENGTH = 0.7;
const BOARD_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

// ──────────────────────────────────────────────
// Validation
// ──────────────────────────────────────────────

function validatePrompt(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Please enter a prompt.');
  }
  const prompt = value.trim();
  if (prompt.length > MAX_PROMPT_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `The prompt is too long. The maximum is ${MAX_PROMPT_LENGTH} characters.`,
    );
  }
  return prompt;
}

function validateBoardId(value) {
  if (typeof value !== 'string' || !BOARD_ID_PATTERN.test(value.trim())) {
    throw new HttpsError('invalid-argument', 'boardId is required.');
  }
  return value.trim();
}

function validateAspectRatio(value) {
  const ratio = value === undefined || value === null ? '1:1' : value;
  if (typeof ratio !== 'string' || !Object.hasOwn(ASPECT_RATIOS, ratio)) {
    throw new HttpsError('invalid-argument', 'aspectRatio must be 1:1, 16:9 or 9:16.');
  }
  return ratio;
}

function validateStrength(value) {
  if (value === undefined || value === null) return DEFAULT_STRENGTH;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new HttpsError('invalid-argument', 'strength must be a number between 0 and 1.');
  }
  return value;
}

function decodeMask(value) {
  const invalid = () =>
    new HttpsError('invalid-argument', 'maskBase64 must be a PNG image of at most 4 MB.');
  if (typeof value !== 'string' || value.length === 0) throw invalid();
  // 4 MB of bytes is about 5.6 MB of base64; reject early before decoding.
  if (value.length > Math.ceil((MAX_MASK_BYTES * 4) / 3) + 16) throw invalid();
  if (!/^[A-Za-z0-9+/=]+$/.test(value)) throw invalid();
  const buffer = Buffer.from(value, 'base64');
  if (buffer.length === 0 || buffer.length > MAX_MASK_BYTES) throw invalid();
  if (!buffer.subarray(0, 8).equals(PNG_SIGNATURE)) throw invalid();
  return buffer;
}

// ──────────────────────────────────────────────
// Error mapping
// ──────────────────────────────────────────────

function toHttpsError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AiProviderError) {
    switch (error.code) {
      case 'not_configured':
        return new HttpsError('failed-precondition', error.message);
      case 'timeout':
        return new HttpsError('deadline-exceeded', error.message);
      case 'invalid_input':
        return new HttpsError('invalid-argument', error.message);
      default:
        return new HttpsError('unavailable', error.message);
    }
  }
  return new HttpsError('internal', 'AI image request failed. Please try again later.');
}

function withTimeout(promise, timeoutMs) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new AiProviderError('timeout', 'The AI service took too long to respond.')),
      timeoutMs,
    );
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

// ──────────────────────────────────────────────
// Default dependencies (production)
// ──────────────────────────────────────────────

function defaultDeps() {
  // Required lazily so tests never initialise Firebase Admin.
  const admin = require('../../server/firebase-admin');
  const logger = require('../utils/logger');
  return {
    firestore: admin.firestore(),
    storage: createAiStorage(),
    provider: getProvider(),
    logger,
    dailyLimit: getDailyLimit(),
    // Imported from the module directly: the Functions emulator's wrapper
    // around `admin.firestore` does not expose `FieldValue`.
    serverTimestamp: () => require('firebase-admin/firestore').FieldValue.serverTimestamp(),
    newGenerationId: () => crypto.randomUUID().replace(/-/g, ''),
    providerTimeoutMs: PROVIDER_TIMEOUT_MS,
  };
}

// ──────────────────────────────────────────────
// Pipeline
// ──────────────────────────────────────────────

/**
 * @param {object} request  The callable request ({auth, data}).
 * @param {'generate'|'edit'|'inpaint'} type
 * @param {object} [injected]  Test overrides for defaultDeps().
 */
async function runAiRequest(request, type, injected) {
  const uid = request?.auth?.uid;
  let deps = null;
  let reservation = null;

  try {
    // 1. Auth
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    // 2. Validate (cheap checks first, before any I/O)
    const data = request.data || {};
    const boardId = validateBoardId(data.boardId);
    const prompt = validatePrompt(data.prompt);
    const aspectRatio = type === 'generate' ? validateAspectRatio(data.aspectRatio) : null;
    const strength = type === 'edit' ? validateStrength(data.strength) : null;
    const maskBuffer = type === 'inpaint' ? decodeMask(data.maskBase64) : null;

    deps = injected || defaultDeps();
    const { firestore, storage, provider, logger } = deps;

    storage.assertConfigured();
    const sourceKey =
      type === 'generate' ? null : storage.parseSourceUrl(data.sourceImageUrl, boardId);
    const sourceImageUrl = type === 'generate' ? null : String(data.sourceImageUrl).trim();

    // 3. Edit access
    await assertBoardEditAccess(firestore, boardId, uid);

    // 4. Daily limit (reserved now, refunded on failure)
    reservation = await reserveDailySlot(firestore, uid, { limit: deps.dailyLimit });

    // 5. Provider
    const sourceBuffer = sourceKey ? await storage.download(sourceKey) : null;
    let providerCall;
    if (type === 'generate') {
      providerCall = provider.generate({ prompt, aspectRatio });
    } else if (type === 'edit') {
      providerCall = provider.edit({ imageBuffer: sourceBuffer, prompt, strength });
    } else {
      providerCall = provider.inpaint({ imageBuffer: sourceBuffer, maskBuffer, prompt });
    }
    const result = await withTimeout(providerCall, deps.providerTimeoutMs);

    // 6. PNG + upload
    const png = await normalizeToPng(result.buffer);
    const generationId = deps.newGenerationId();
    const imageUrl = await storage.upload({
      boardId,
      generationId,
      pngBuffer: png.buffer,
    });

    // 7. Thumbnail
    const thumbnail = await makeThumbnail(png.buffer);

    // 8. Record
    await firestore.collection(AI_GENERATIONS_COLLECTION).doc(generationId).set({
      uid,
      boardId,
      type,
      prompt,
      aspectRatio,
      provider: provider.name,
      model: result.model,
      imageUrl,
      sourceImageUrl,
      width: png.width,
      height: png.height,
      status: 'succeeded',
      createdAt: deps.serverTimestamp(),
    });

    // 9. Log (never prompts' images, tokens or base64)
    logger.info('AI image request succeeded', {
      uid,
      boardId,
      type,
      provider: provider.name,
      model: result.model,
      generationId,
      width: png.width,
      height: png.height,
    });

    return {
      success: true,
      imageUrl,
      thumbnailBase64: thumbnail.toString('base64'),
      width: png.width,
      height: png.height,
      provider: provider.name,
      model: result.model,
      generationId,
    };
  } catch (error) {
    if (reservation && deps) {
      try {
        await refundDailySlot(deps.firestore, reservation.docId);
      } catch (refundError) {
        deps.logger.warn('AI image request: failed to refund daily slot', {
          uid,
          errorMessage: refundError?.message,
        });
      }
    }

    const httpsError = toHttpsError(error);
    if (deps) {
      const details = { uid, type, code: httpsError.code, errorMessage: error?.message };
      if (httpsError.code === 'internal') {
        deps.logger.error('AI image request failed', error);
      } else {
        deps.logger.warn('AI image request rejected', details);
      }
    }
    throw httpsError;
  }
}

module.exports = {
  AI_GENERATIONS_COLLECTION,
  MAX_PROMPT_LENGTH,
  MAX_MASK_BYTES,
  DEFAULT_STRENGTH,
  validatePrompt,
  validateBoardId,
  validateAspectRatio,
  validateStrength,
  decodeMask,
  toHttpsError,
  runAiRequest,
};
