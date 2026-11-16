const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');

const {
  ASPECT_RATIOS,
  KLEIN_MODEL,
  SCHNELL_MODEL,
  THUMBNAIL_MAX_SIDE,
  THUMBNAIL_MAX_BYTES,
  AiProviderError,
  makeThumbnail,
  compositeWithMask,
  createMockProvider,
  createCloudflareProvider,
  resolveProviderName,
} = require('../../src/ai/ai_provider_utils');
const { solidPng, rectMaskPng, pixelAt } = require('./fakes');

const mock = createMockProvider({ delayMs: 0 });

test('mock generate returns a real PNG sized to each aspect ratio', async () => {
  for (const [ratio, size] of Object.entries(ASPECT_RATIOS)) {
    const result = await mock.generate({ prompt: 'a red fox', aspectRatio: ratio });
    const meta = await sharp(result.buffer).metadata();
    assert.equal(meta.format, 'png');
    assert.equal(meta.width, size.width);
    assert.equal(meta.height, size.height);
    assert.equal(result.width, size.width);
    assert.equal(result.height, size.height);
    assert.equal(result.model, 'mock');
  }
});

test('mock edit keeps the size and visibly changes the image', async () => {
  const source = await solidPng(64, 48, '#ffffff');
  const result = await mock.edit({ imageBuffer: source, prompt: 'make it night', strength: 0.7 });
  assert.equal(result.width, 64);
  assert.equal(result.height, 48);
  assert.notDeepEqual(await pixelAt(result.buffer, 10, 10), [255, 255, 255]);
});

test('mock inpaint changes only the masked area', async () => {
  const source = await solidPng(100, 100, '#ffffff');
  const mask = await rectMaskPng(100, 100, { left: 50, top: 50, width: 40, height: 40 });
  const result = await mock.inpaint({ imageBuffer: source, maskBuffer: mask, prompt: 'a tree' });
  assert.equal(result.width, 100);
  assert.equal(result.height, 100);
  assert.deepEqual(await pixelAt(result.buffer, 10, 10), [255, 255, 255]);
  assert.notDeepEqual(await pixelAt(result.buffer, 70, 70), [255, 255, 255]);
});

test('compositeWithMask leaves pixels outside the mask unchanged', async () => {
  const original = await solidPng(120, 80, { r: 10, g: 200, b: 30 });
  const edited = await solidPng(60, 40, { r: 250, g: 0, b: 0 }); // different size on purpose
  const mask = await rectMaskPng(120, 80, { left: 70, top: 20, width: 40, height: 40 });

  const result = await compositeWithMask({
    originalBuffer: original,
    editedBuffer: edited,
    maskBuffer: mask,
  });

  assert.equal(result.width, 120);
  assert.equal(result.height, 80);
  // Far outside the mask: identical to the original.
  assert.deepEqual(await pixelAt(result.buffer, 5, 5), [10, 200, 30]);
  assert.deepEqual(await pixelAt(result.buffer, 30, 70), [10, 200, 30]);
  // Centre of the mask: the edited colour.
  assert.deepEqual(await pixelAt(result.buffer, 90, 40), [250, 0, 0]);
});

test('compositeWithMask treats a transparent mask background as "keep"', async () => {
  const original = await solidPng(40, 40, { r: 0, g: 0, b: 255 });
  const edited = await solidPng(40, 40, { r: 255, g: 255, b: 0 });
  const transparentMask = await sharp({
    create: { width: 40, height: 40, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .png()
    .toBuffer();
  const result = await compositeWithMask({
    originalBuffer: original,
    editedBuffer: edited,
    maskBuffer: transparentMask,
  });
  assert.deepEqual(await pixelAt(result.buffer, 20, 20), [0, 0, 255]);
});

test('makeThumbnail is a JPEG of at most 256px and about 30 KB', async () => {
  // Noise is the worst case for JPEG size.
  const width = 1280;
  const height = 720;
  const noise = Buffer.alloc(width * height * 3);
  for (let i = 0; i < noise.length; i++) noise[i] = (i * 7919 + (i >> 3) * 31) % 256;
  const source = await sharp(noise, { raw: { width, height, channels: 3 } }).png().toBuffer();

  const thumbnail = await makeThumbnail(source);
  const meta = await sharp(thumbnail).metadata();
  assert.equal(meta.format, 'jpeg');
  assert.ok(Math.max(meta.width, meta.height) <= THUMBNAIL_MAX_SIDE);
  assert.equal(meta.width, 256);
  assert.ok(thumbnail.length <= THUMBNAIL_MAX_BYTES, `thumbnail is ${thumbnail.length} bytes`);
});

test('makeThumbnail does not enlarge small images', async () => {
  const thumbnail = await makeThumbnail(await solidPng(100, 50, '#336699'));
  const meta = await sharp(thumbnail).metadata();
  assert.equal(meta.width, 100);
  assert.equal(meta.height, 50);
});

test('resolveProviderName: cloudflare only when a token exists, unless overridden', () => {
  assert.equal(resolveProviderName({}), 'mock');
  assert.equal(resolveProviderName({ CLOUDFLARE_AI_API_TOKEN: '  ' }), 'mock');
  assert.equal(resolveProviderName({ CLOUDFLARE_AI_API_TOKEN: 'x' }), 'cloudflare');
  assert.equal(resolveProviderName({ CLOUDFLARE_AI_API_TOKEN: 'x', AI_PROVIDER: 'mock' }), 'mock');
  assert.equal(resolveProviderName({ AI_PROVIDER: 'cloudflare' }), 'cloudflare');
  assert.equal(resolveProviderName({ AI_PROVIDER: 'nonsense' }), 'mock');
});

// ── Cloudflare provider, with a fake fetch (no network) ──

function jsonImageResponse(buffer) {
  return new Response(
    JSON.stringify({ result: { image: buffer.toString('base64') }, success: true }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  );
}

test('cloudflare generate calls klein with the token and returns a PNG', async () => {
  const jpeg = await sharp(await solidPng(1280, 720, '#123456')).jpeg().toBuffer();
  const calls = [];
  const provider = createCloudflareProvider({
    accountId: 'acct',
    apiToken: 'secret-token',
    fetchImpl: async (url, init) => {
      calls.push({ url, init });
      return jsonImageResponse(jpeg);
    },
  });

  const result = await provider.generate({ prompt: 'a city', aspectRatio: '16:9' });

  assert.equal(calls.length, 1);
  assert.ok(calls[0].url.endsWith(`/accounts/acct/ai/run/${KLEIN_MODEL}`));
  assert.equal(calls[0].init.headers.Authorization, 'Bearer secret-token');
  assert.ok(calls[0].init.body instanceof FormData);
  assert.equal(calls[0].init.body.get('prompt'), 'a city');
  assert.equal(result.model, KLEIN_MODEL);
  assert.equal(result.width, 1280);
  assert.equal(result.height, 720);
  assert.equal((await sharp(result.buffer).metadata()).format, 'png');
});

test('cloudflare generate falls back to schnell when klein fails', async () => {
  const jpeg = await sharp(await solidPng(1024, 1024, '#654321')).jpeg().toBuffer();
  const models = [];
  const provider = createCloudflareProvider({
    accountId: 'acct',
    apiToken: 'token',
    fetchImpl: async (url, init) => {
      models.push(url.split('/ai/run/')[1]);
      if (url.endsWith(KLEIN_MODEL)) return new Response('boom', { status: 500 });
      assert.deepEqual(JSON.parse(init.body), { prompt: 'a city', steps: 4 });
      return jsonImageResponse(jpeg);
    },
  });

  const result = await provider.generate({ prompt: 'a city', aspectRatio: '9:16' });
  assert.deepEqual(models, [KLEIN_MODEL, SCHNELL_MODEL]);
  assert.equal(result.model, SCHNELL_MODEL);
  assert.equal(result.width, 1024);
  assert.equal(result.height, 1024);
});

test('cloudflare accepts a raw image response as well as JSON', async () => {
  const png = await solidPng(512, 512, '#00ff00');
  const provider = createCloudflareProvider({
    accountId: 'acct',
    apiToken: 'token',
    fetchImpl: async () =>
      new Response(png, { status: 200, headers: { 'content-type': 'image/png' } }),
  });
  const result = await provider.edit({ imageBuffer: png, prompt: 'x', strength: 0.5 });
  assert.equal(result.width, 512);
});

test('cloudflare edit sends the source image and inpaint keeps the original size', async () => {
  const source = await solidPng(200, 100, '#ffffff');
  const edited = await solidPng(208, 96, '#ff0000');
  let sentImage = null;
  const provider = createCloudflareProvider({
    accountId: 'acct',
    apiToken: 'token',
    fetchImpl: async (_url, init) => {
      sentImage = init.body.get('input_image_0');
      return jsonImageResponse(edited);
    },
  });
  const mask = await rectMaskPng(200, 100, { left: 120, top: 20, width: 60, height: 60 });

  const result = await provider.inpaint({ imageBuffer: source, maskBuffer: mask, prompt: 'red' });

  assert.ok(sentImage, 'the source image is sent to the model');
  assert.equal(result.width, 200);
  assert.equal(result.height, 100);
  assert.deepEqual(await pixelAt(result.buffer, 10, 10), [255, 255, 255]);
  assert.deepEqual(await pixelAt(result.buffer, 150, 50), [255, 0, 0]);
});

test('cloudflare maps failures to provider error codes', async () => {
  const make = (fetchImpl, extra = {}) =>
    createCloudflareProvider({ accountId: 'acct', apiToken: 'token', fetchImpl, ...extra });
  const png = await solidPng(64, 64, '#000000');
  const codeOf = async (promise) => {
    try {
      await promise;
    } catch (error) {
      assert.ok(error instanceof AiProviderError);
      return error.code;
    }
    return 'no-error';
  };

  assert.equal(
    await codeOf(
      createCloudflareProvider({ accountId: '', apiToken: '' }).edit({ imageBuffer: png, prompt: 'x' }),
    ),
    'not_configured',
  );
  assert.equal(
    await codeOf(make(async () => new Response('no', { status: 401 })).edit({ imageBuffer: png, prompt: 'x' })),
    'not_configured',
  );
  assert.equal(
    await codeOf(make(async () => new Response('bad', { status: 400 })).edit({ imageBuffer: png, prompt: 'x' })),
    'invalid_input',
  );
  assert.equal(
    await codeOf(make(async () => new Response('down', { status: 503 })).edit({ imageBuffer: png, prompt: 'x' })),
    'unavailable',
  );
  assert.equal(
    await codeOf(
      make(async () => {
        throw new TypeError('fetch failed');
      }).edit({ imageBuffer: png, prompt: 'x' }),
    ),
    'unavailable',
  );
  assert.equal(
    await codeOf(
      make(
        (_url, init) =>
          new Promise((_, reject) => {
            init.signal.addEventListener('abort', () => reject(init.signal.reason));
          }),
        { timeoutMs: 20 },
      ).edit({ imageBuffer: png, prompt: 'x' }),
    ),
    'timeout',
  );
  // A bad token is not retried on the fallback model.
  let calls = 0;
  assert.equal(
    await codeOf(
      make(async () => {
        calls += 1;
        return new Response('no', { status: 403 });
      }).generate({ prompt: 'x', aspectRatio: '1:1' }),
    ),
    'not_configured',
  );
  assert.equal(calls, 1);
});
