/**
 * AI image providers.
 *
 * Every provider exposes the same three calls and returns
 * `{buffer, width, height, model}` where `buffer` is the raw image bytes as
 * the provider produced them (callers normalise to PNG):
 *
 *   generate({prompt, aspectRatio})
 *   edit({imageBuffer, prompt, strength})
 *   inpaint({imageBuffer, maskBuffer, prompt})
 *
 * To switch to another vendor, add a new `createXxxProvider` here and return
 * it from `getProvider`. Nothing outside this file knows which vendor is used.
 *
 * This file ends in `_utils.js` so functions/index.js does not export it.
 */

const crypto = require('crypto');
const sharp = require('sharp');

const ASPECT_RATIOS = {
  '1:1': { width: 1024, height: 1024 },
  '16:9': { width: 1280, height: 720 },
  '9:16': { width: 720, height: 1280 },
};

const KLEIN_MODEL = '@cf/black-forest-labs/flux-2-klein-4b';
const SCHNELL_MODEL = '@cf/black-forest-labs/flux-1-schnell';
const MOCK_MODEL = 'mock';

const PROVIDER_TIMEOUT_MS = 60000;
const MOCK_DELAY_MS = 1500;
const MASK_FEATHER_PX = 4;
const THUMBNAIL_MAX_SIDE = 256;
const THUMBNAIL_MAX_BYTES = 30 * 1024;

/** Error codes: not_configured | timeout | unavailable | invalid_input */
class AiProviderError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AiProviderError';
    this.code = code;
  }
}

// ──────────────────────────────────────────────
// Image helpers (sharp)
// ──────────────────────────────────────────────

/** Converts any supported image to PNG and reports its pixel size. */
async function normalizeToPng(buffer) {
  try {
    const { data, info } = await sharp(buffer)
      .png()
      .toBuffer({ resolveWithObject: true });
    return { buffer: data, width: info.width, height: info.height };
  } catch (error) {
    throw new AiProviderError('unavailable', 'The AI service returned an unreadable image.');
  }
}

/** JPEG thumbnail, at most 256px on the long side and about 30 KB. */
async function makeThumbnail(buffer) {
  const resized = await sharp(buffer)
    .resize(THUMBNAIL_MAX_SIDE, THUMBNAIL_MAX_SIDE, {
      fit: 'inside',
      withoutEnlargement: true,
    })
    .flatten({ background: '#ffffff' })
    .png()
    .toBuffer();

  let output = null;
  for (const quality of [72, 60, 48, 36, 24]) {
    output = await sharp(resized).jpeg({ quality }).toBuffer();
    if (output.length <= THUMBNAIL_MAX_BYTES) break;
  }
  return output;
}

/**
 * Pastes `editedBuffer` onto `originalBuffer` only where the mask is white.
 * The mask edge is feathered by a few pixels. The result has the original's
 * pixel size and is a PNG.
 */
async function compositeWithMask({
  originalBuffer,
  editedBuffer,
  maskBuffer,
  featherPx = MASK_FEATHER_PX,
}) {
  const { width, height } = await sharp(originalBuffer).metadata();

  // sharp applies operations in its own fixed order, not the chained order,
  // so each stage below is a separate pipeline working on raw pixels.
  const pixelCount = width * height;

  // 1. Mask → one byte per pixel (transparent areas count as black = keep).
  const maskStage = await sharp(maskBuffer)
    .resize(width, height, { fit: 'fill' })
    .flatten({ background: '#000000' })
    .greyscale()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let alpha = Buffer.alloc(pixelCount);
  for (let i = 0; i < pixelCount; i++) {
    alpha[i] = maskStage.data[i * maskStage.info.channels];
  }

  // 2. Feather the mask edge.
  if (featherPx > 0) {
    const blurred = await sharp(alpha, { raw: { width, height, channels: 1 } })
      .blur(featherPx)
      .raw()
      .toBuffer({ resolveWithObject: true });
    const feathered = Buffer.alloc(pixelCount);
    for (let i = 0; i < pixelCount; i++) {
      feathered[i] = blurred.data[i * blurred.info.channels];
    }
    alpha = feathered;
  }

  // 3. Edited image → RGB at the original's size, with the mask as alpha.
  const editedStage = await sharp(editedBuffer)
    .resize(width, height, { fit: 'fill' })
    .flatten({ background: '#ffffff' })
    .toColourspace('srgb')
    .raw()
    .toBuffer({ resolveWithObject: true });
  const editedChannels = editedStage.info.channels;
  const rgba = Buffer.alloc(pixelCount * 4);
  for (let i = 0; i < pixelCount; i++) {
    const source = i * editedChannels;
    const target = i * 4;
    rgba[target] = editedStage.data[source];
    rgba[target + 1] = editedStage.data[editedChannels >= 3 ? source + 1 : source];
    rgba[target + 2] = editedStage.data[editedChannels >= 3 ? source + 2 : source];
    rgba[target + 3] = alpha[i];
  }
  const editedWithAlpha = await sharp(rgba, { raw: { width, height, channels: 4 } })
    .png()
    .toBuffer();

  const buffer = await sharp(originalBuffer)
    .composite([{ input: editedWithAlpha }])
    .png()
    .toBuffer();

  return { buffer, width, height };
}

// ──────────────────────────────────────────────
// Mock provider (no network)
// ──────────────────────────────────────────────

function colourFromText(text) {
  const hash = crypto.createHash('sha256').update(String(text)).digest();
  // Keep colours mid-range so the placeholder is visible in light and dark.
  return {
    r: 60 + (hash[0] % 150),
    g: 60 + (hash[1] % 150),
    b: 60 + (hash[2] % 150),
  };
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createMockProvider({ delayMs = MOCK_DELAY_MS } = {}) {
  async function tinted(imageBuffer, prompt) {
    const { width, height } = await sharp(imageBuffer).metadata();
    const overlay = await sharp({
      create: {
        width,
        height,
        channels: 4,
        background: { ...colourFromText(prompt), alpha: 0.55 },
      },
    })
      .png()
      .toBuffer();
    const buffer = await sharp(imageBuffer)
      .composite([{ input: overlay }])
      .png()
      .toBuffer();
    return { buffer, width, height };
  }

  return {
    name: 'mock',

    async generate({ prompt, aspectRatio }) {
      await delay(delayMs);
      const size = ASPECT_RATIOS[aspectRatio] || ASPECT_RATIOS['1:1'];
      // A random salt makes "Regenerate" produce a visibly different colour.
      const salt = crypto.randomBytes(4).toString('hex');
      const buffer = await sharp({
        create: {
          width: size.width,
          height: size.height,
          channels: 3,
          background: colourFromText(`${prompt}:${salt}`),
        },
      })
        .png()
        .toBuffer();
      return { buffer, width: size.width, height: size.height, model: MOCK_MODEL };
    },

    async edit({ imageBuffer, prompt }) {
      await delay(delayMs);
      const result = await tinted(imageBuffer, prompt);
      return { ...result, model: MOCK_MODEL };
    },

    async inpaint({ imageBuffer, maskBuffer, prompt }) {
      await delay(delayMs);
      const edited = await tinted(imageBuffer, prompt);
      const result = await compositeWithMask({
        originalBuffer: imageBuffer,
        editedBuffer: edited.buffer,
        maskBuffer,
      });
      return { ...result, model: MOCK_MODEL };
    },
  };
}

// ──────────────────────────────────────────────
// Cloudflare Workers AI provider
// ──────────────────────────────────────────────

function mapHttpStatus(status, detail) {
  if (status === 400 || status === 413 || status === 422) {
    return new AiProviderError(
      'invalid_input',
      'The AI service rejected this request. Try a different prompt or image.',
    );
  }
  if (status === 401 || status === 403) {
    return new AiProviderError(
      'not_configured',
      'AI image generation is not configured correctly on the server.',
    );
  }
  return new AiProviderError(
    'unavailable',
    `The AI service is unavailable right now (status ${status}${detail ? `: ${detail}` : ''}).`,
  );
}

async function parseImageResponse(response) {
  const contentType = (response.headers.get('content-type') || '').toLowerCase();
  if (contentType.startsWith('image/')) {
    return Buffer.from(await response.arrayBuffer());
  }
  let body;
  try {
    body = await response.json();
  } catch (_) {
    throw new AiProviderError('unavailable', 'The AI service returned an unreadable response.');
  }
  const base64 = body?.result?.image || body?.image;
  if (typeof base64 !== 'string' || base64.length === 0) {
    throw new AiProviderError('unavailable', 'The AI service returned no image.');
  }
  return Buffer.from(base64, 'base64');
}

function createCloudflareProvider({
  accountId,
  apiToken,
  fetchImpl = fetch,
  timeoutMs = PROVIDER_TIMEOUT_MS,
}) {
  async function post(model, init) {
    if (!accountId || !apiToken) {
      throw new AiProviderError(
        'not_configured',
        'AI image generation is not configured on the server.',
      );
    }
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`;
    let response;
    try {
      response = await fetchImpl(url, {
        method: 'POST',
        ...init,
        headers: { Authorization: `Bearer ${apiToken}`, ...(init.headers || {}) },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
        throw new AiProviderError('timeout', 'The AI service took too long to respond.');
      }
      throw new AiProviderError('unavailable', 'Could not reach the AI service.');
    }
    if (!response.ok) {
      // Short, token-free detail for logs only.
      const detail = (await response.text().catch(() => '')).slice(0, 200);
      throw mapHttpStatus(response.status, detail.replace(/\s+/g, ' '));
    }
    return parseImageResponse(response);
  }

  // UNVERIFIED: confirm field names with first real call
  // ---------------------------------------------------------------------
  // This is the ONLY place that knows how flux-2-klein-4b is called. The
  // Cloudflare docs say the model takes multipart form data and returns JSON
  // with a base64 `image`, but they do not list the form field names. The
  // names below (`prompt`, `width`, `height`, `input_image_0`) and the 512px
  // input-image limit are assumptions. If the first real call fails, fix them
  // here and nowhere else. `strength` is accepted by our interface but is not
  // sent, because no such field is documented for this model.
  // ---------------------------------------------------------------------
  const KLEIN_MAX_INPUT_SIDE = 512;
  async function callKlein({ prompt, width, height, inputImageBuffer }) {
    const form = new FormData();
    form.append('prompt', prompt);
    form.append('width', String(width));
    form.append('height', String(height));
    if (inputImageBuffer) {
      const resizedInput = await sharp(inputImageBuffer)
        .resize(KLEIN_MAX_INPUT_SIDE, KLEIN_MAX_INPUT_SIDE, {
          fit: 'inside',
          withoutEnlargement: true,
        })
        .png()
        .toBuffer();
      form.append(
        'input_image_0',
        new Blob([resizedInput], { type: 'image/png' }),
        'input.png',
      );
    }
    // fetch sets the multipart boundary header itself.
    return post(KLEIN_MODEL, { body: form });
  }

  async function callSchnell({ prompt }) {
    return post(SCHNELL_MODEL, {
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, steps: 4 }),
    });
  }

  /** Output size for an edit: the source size, capped and snapped to 16px. */
  function editOutputSize(width, height) {
    const scale = Math.min(1, 1024 / Math.max(width, height));
    const snap = (value) => Math.max(256, Math.round((value * scale) / 16) * 16);
    return { width: snap(width), height: snap(height) };
  }

  async function edit({ imageBuffer, prompt }) {
    const meta = await sharp(imageBuffer).metadata();
    const size = editOutputSize(meta.width, meta.height);
    const raw = await callKlein({ prompt, ...size, inputImageBuffer: imageBuffer });
    const png = await normalizeToPng(raw);
    return { ...png, model: KLEIN_MODEL };
  }

  return {
    name: 'cloudflare',

    async generate({ prompt, aspectRatio }) {
      const size = ASPECT_RATIOS[aspectRatio] || ASPECT_RATIOS['1:1'];
      try {
        const raw = await callKlein({ prompt, ...size });
        const png = await normalizeToPng(raw);
        return { ...png, model: KLEIN_MODEL };
      } catch (error) {
        // A wrong token will not work for the fallback model either.
        if (error instanceof AiProviderError && error.code === 'not_configured') {
          throw error;
        }
        // Fallback: square image from flux-1-schnell.
        const raw = await callSchnell({ prompt });
        const png = await normalizeToPng(raw);
        return { ...png, model: SCHNELL_MODEL };
      }
    },

    edit,

    async inpaint({ imageBuffer, maskBuffer, prompt }) {
      // No current Cloudflare model does mask inpainting, so the whole image
      // is edited and the result is kept only inside the mask.
      const edited = await edit({ imageBuffer, prompt });
      const result = await compositeWithMask({
        originalBuffer: imageBuffer,
        editedBuffer: edited.buffer,
        maskBuffer,
      });
      return { ...result, model: KLEIN_MODEL };
    },
  };
}

// ──────────────────────────────────────────────
// Selection
// ──────────────────────────────────────────────

/**
 * AI_PROVIDER = cloudflare | mock. Default: cloudflare when
 * CLOUDFLARE_AI_API_TOKEN is set, otherwise mock.
 */
function resolveProviderName(env = process.env) {
  const configured = String(env.AI_PROVIDER || '').trim().toLowerCase();
  if (configured === 'cloudflare' || configured === 'mock') return configured;
  const token = String(env.CLOUDFLARE_AI_API_TOKEN || '').trim();
  return token.length > 0 ? 'cloudflare' : 'mock';
}

function getProvider(env = process.env) {
  if (resolveProviderName(env) === 'mock') {
    return createMockProvider();
  }
  return createCloudflareProvider({
    accountId: String(env.CLOUDFLARE_ACCOUNT_ID || '').trim(),
    apiToken: String(env.CLOUDFLARE_AI_API_TOKEN || '').trim(),
  });
}

module.exports = {
  ASPECT_RATIOS,
  KLEIN_MODEL,
  SCHNELL_MODEL,
  PROVIDER_TIMEOUT_MS,
  THUMBNAIL_MAX_SIDE,
  THUMBNAIL_MAX_BYTES,
  AiProviderError,
  normalizeToPng,
  makeThumbnail,
  compositeWithMask,
  createMockProvider,
  createCloudflareProvider,
  resolveProviderName,
  getProvider,
};
