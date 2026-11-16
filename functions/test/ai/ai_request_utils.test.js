const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');

const {
  runAiRequest,
  validatePrompt,
  validateBoardId,
  validateAspectRatio,
  validateStrength,
  decodeMask,
  MAX_MASK_BYTES,
} = require('../../src/ai/ai_request_utils');
const { createMockProvider, AiProviderError } = require('../../src/ai/ai_provider_utils');
const { assertBoardEditAccess } = require('../../src/ai/ai_access_utils');
const { reserveDailySlot, refundDailySlot, usageDocId, getDailyLimit } = require('../../src/ai/ai_usage_utils');
const { parseAiImageUrl, assertStorageConfigured } = require('../../src/ai/ai_storage_utils');
const {
  TEST_ENV,
  createFakeFirestore,
  createFakeStorage,
  createSilentLogger,
  solidPng,
  rectMaskPng,
} = require('./fakes');

const OWNER = 'owner-uid-000000000000000001';
const EDITOR = 'editor-uid-00000000000000002';
const VIEWER = 'viewer-uid-00000000000000003';
const STRANGER = 'stranger-uid-000000000000004';
const BOARD = 'board123';

function boardDocs() {
  return {
    [`boards/${BOARD}`]: { ownerId: OWNER, members: [OWNER, EDITOR, VIEWER] },
    [`boards/${BOARD}/members/${OWNER}`]: { role: 'owner' },
    [`boards/${BOARD}/members/${EDITOR}`]: { role: 'editor' },
    [`boards/${BOARD}/members/${VIEWER}`]: { role: 'viewer' },
  };
}

function makeDeps(overrides = {}) {
  let counter = 0;
  return {
    firestore: createFakeFirestore(boardDocs()),
    storage: createFakeStorage(),
    provider: createMockProvider({ delayMs: 0 }),
    logger: createSilentLogger(),
    dailyLimit: 20,
    serverTimestamp: () => 'SERVER_TIMESTAMP',
    newGenerationId: () => `gen${++counter}`,
    providerTimeoutMs: 5000,
    ...overrides,
  };
}

async function codeOf(promise) {
  try {
    await promise;
  } catch (error) {
    return error.code;
  }
  return 'no-error';
}

const usageCount = (deps, uid) =>
  deps.firestore.docs.get(`ai_usage/${usageDocId(uid)}`)?.count ?? 0;

// ── Validation ──

test('validatePrompt trims and enforces 1..1000 characters', () => {
  assert.equal(validatePrompt('  a cat  '), 'a cat');
  assert.equal(validatePrompt('x'.repeat(1000)).length, 1000);
  for (const bad of [undefined, null, 42, '', '   ', 'x'.repeat(1001)]) {
    assert.throws(() => validatePrompt(bad), { code: 'invalid-argument' });
  }
});

test('validateBoardId rejects missing or unsafe ids', () => {
  assert.equal(validateBoardId(' abc_DEF-123 '), 'abc_DEF-123');
  for (const bad of [undefined, '', '  ', 'a/b', '../x', 'a b', 'x'.repeat(129), 7]) {
    assert.throws(() => validateBoardId(bad), { code: 'invalid-argument' });
  }
});

test('validateAspectRatio allows only the three ratios', () => {
  assert.equal(validateAspectRatio(undefined), '1:1');
  assert.equal(validateAspectRatio('16:9'), '16:9');
  assert.equal(validateAspectRatio('9:16'), '9:16');
  for (const bad of ['4:3', '', 'toString', 169, {}]) {
    assert.throws(() => validateAspectRatio(bad), { code: 'invalid-argument' });
  }
});

test('validateStrength defaults to 0.7 and enforces 0..1', () => {
  assert.equal(validateStrength(undefined), 0.7);
  assert.equal(validateStrength(0), 0);
  assert.equal(validateStrength(1), 1);
  for (const bad of [-0.1, 1.1, '0.5', NaN, Infinity]) {
    assert.throws(() => validateStrength(bad), { code: 'invalid-argument' });
  }
});

test('decodeMask accepts a PNG and rejects everything else', async () => {
  const png = await solidPng(8, 8, '#ffffff');
  assert.ok(decodeMask(png.toString('base64')).equals(png));

  const jpeg = await sharp(png).jpeg().toBuffer();
  const tooBig = Buffer.concat([png, Buffer.alloc(MAX_MASK_BYTES)]);
  for (const bad of [undefined, '', 'not base64!!', jpeg.toString('base64'), tooBig.toString('base64')]) {
    assert.throws(() => decodeMask(bad), { code: 'invalid-argument' });
  }
});

// ── sourceImageUrl ──

test('parseAiImageUrl accepts only this board\'s AI images in our bucket', () => {
  const base = TEST_ENV.CLOUDFLARE_R2_PUBLIC_URL;
  assert.equal(
    parseAiImageUrl(`${base}/ai-images/${BOARD}/gen1.png`, BOARD, TEST_ENV),
    `ai-images/${BOARD}/gen1.png`,
  );
  const rejected = [
    'https://evil.example/ai-images/board123/gen1.png',
    `${base}.evil.example/ai-images/${BOARD}/gen1.png`,
    `${base}/ai-images/otherBoard/gen1.png`,
    `${base}/profiles/someone/photo.png`,
    `${base}/ai-images/${BOARD}/../../profiles/x.png`,
    `${base}/ai-images/${BOARD}/gen1.png?x=1`,
    `${base}/ai-images/${BOARD}/gen1.jpg`,
    `${base}/ai-images/${BOARD}/sub/gen1.png`,
    'http://169.254.169.254/latest/meta-data',
    '',
    null,
    42,
  ];
  for (const url of rejected) {
    assert.throws(() => parseAiImageUrl(url, BOARD, TEST_ENV), { code: 'invalid-argument' }, String(url));
  }
  // No public base configured: nothing can match.
  assert.throws(() => parseAiImageUrl(`/ai-images/${BOARD}/gen1.png`, BOARD, {}), {
    code: 'invalid-argument',
  });
});

test('assertStorageConfigured needs every R2 setting', () => {
  assert.doesNotThrow(() => assertStorageConfigured(TEST_ENV));
  assert.throws(() => assertStorageConfigured({ ...TEST_ENV, CLOUDFLARE_R2_BUCKET: ' ' }), {
    code: 'failed-precondition',
  });
});

// ── Access ──

test('edit access: owner and editor allowed, viewer and non-member denied', async () => {
  const firestore = createFakeFirestore(boardDocs());
  assert.equal((await assertBoardEditAccess(firestore, BOARD, OWNER)).role, 'owner');
  assert.equal((await assertBoardEditAccess(firestore, BOARD, EDITOR)).role, 'editor');
  assert.equal(await codeOf(assertBoardEditAccess(firestore, BOARD, VIEWER)), 'permission-denied');
  assert.equal(await codeOf(assertBoardEditAccess(firestore, BOARD, STRANGER)), 'permission-denied');
  assert.equal(await codeOf(assertBoardEditAccess(firestore, 'missing', OWNER)), 'not-found');
});

// ── Daily limit ──

test('daily limit: reserve counts up, blocks at the limit, refund frees a slot', async () => {
  const firestore = createFakeFirestore();
  const now = new Date('2026-11-16T23:59:00Z');
  assert.equal(usageDocId('u1', now), 'u1_20261116');

  const first = await reserveDailySlot(firestore, 'u1', { limit: 2, now });
  assert.equal(first.count, 1);
  await reserveDailySlot(firestore, 'u1', { limit: 2, now });
  assert.equal(await codeOf(reserveDailySlot(firestore, 'u1', { limit: 2, now })), 'resource-exhausted');

  await refundDailySlot(firestore, first.docId);
  assert.equal(firestore.docs.get('ai_usage/u1_20261116').count, 1);
  assert.equal((await reserveDailySlot(firestore, 'u1', { limit: 2, now })).count, 2);

  // Other users and other days are independent.
  assert.equal((await reserveDailySlot(firestore, 'u2', { limit: 2, now })).count, 1);
  const tomorrow = new Date('2026-11-17T00:00:01Z');
  assert.equal((await reserveDailySlot(firestore, 'u1', { limit: 2, now: tomorrow })).count, 1);

  // Refund never goes below zero.
  await refundDailySlot(firestore, 'nobody_20261116');
  assert.equal(firestore.docs.get('ai_usage/nobody_20261116'), undefined);
});

test('getDailyLimit reads AI_DAILY_LIMIT and defaults to 20', () => {
  assert.equal(getDailyLimit({}), 20);
  assert.equal(getDailyLimit({ AI_DAILY_LIMIT: '5' }), 5);
  assert.equal(getDailyLimit({ AI_DAILY_LIMIT: '0' }), 20);
  assert.equal(getDailyLimit({ AI_DAILY_LIMIT: 'abc' }), 20);
});

// ── Full pipeline ──

test('generate: full flow returns the response shape and stores everything', async () => {
  const deps = makeDeps();
  const result = await runAiRequest(
    { auth: { uid: EDITOR }, data: { boardId: BOARD, prompt: ' a red fox ', aspectRatio: '16:9' } },
    'generate',
    deps,
  );

  assert.equal(result.success, true);
  assert.equal(result.imageUrl, `${TEST_ENV.CLOUDFLARE_R2_PUBLIC_URL}/ai-images/${BOARD}/gen1.png`);
  assert.equal(result.width, 1280);
  assert.equal(result.height, 720);
  assert.equal(result.provider, 'mock');
  assert.equal(result.model, 'mock');
  assert.equal(result.generationId, 'gen1');

  const thumbMeta = await sharp(Buffer.from(result.thumbnailBase64, 'base64')).metadata();
  assert.equal(thumbMeta.format, 'jpeg');
  assert.ok(Math.max(thumbMeta.width, thumbMeta.height) <= 256);

  const stored = deps.storage.objects.get(`ai-images/${BOARD}/gen1.png`);
  assert.equal((await sharp(stored).metadata()).format, 'png');

  const record = deps.firestore.docs.get('ai_generations/gen1');
  assert.equal(record.uid, EDITOR);
  assert.equal(record.boardId, BOARD);
  assert.equal(record.type, 'generate');
  assert.equal(record.prompt, 'a red fox');
  assert.equal(record.aspectRatio, '16:9');
  assert.equal(record.status, 'succeeded');
  assert.equal(record.sourceImageUrl, null);

  assert.equal(usageCount(deps, EDITOR), 1);

  // Nothing sensitive or bulky in the logs.
  const logged = JSON.stringify(deps.logger.calls);
  assert.ok(!logged.includes(result.thumbnailBase64));
});

test('edit and inpaint: use the stored source image and return a new one', async () => {
  const deps = makeDeps();
  const generated = await runAiRequest(
    { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox', aspectRatio: '1:1' } },
    'generate',
    deps,
  );

  const edited = await runAiRequest(
    {
      auth: { uid: OWNER },
      data: { boardId: BOARD, sourceImageUrl: generated.imageUrl, prompt: 'at night', strength: 0.4 },
    },
    'edit',
    deps,
  );
  assert.equal(edited.width, 1024);
  assert.equal(edited.height, 1024);
  assert.notEqual(edited.imageUrl, generated.imageUrl);
  assert.equal(deps.firestore.docs.get(`ai_generations/${edited.generationId}`).sourceImageUrl, generated.imageUrl);

  const mask = await rectMaskPng(1024, 1024, { left: 100, top: 100, width: 300, height: 300 });
  const inpainted = await runAiRequest(
    {
      auth: { uid: OWNER },
      data: {
        boardId: BOARD,
        sourceImageUrl: edited.imageUrl,
        maskBase64: mask.toString('base64'),
        prompt: 'a tree',
      },
    },
    'inpaint',
    deps,
  );
  assert.equal(inpainted.width, 1024);
  assert.equal(deps.firestore.docs.get(`ai_generations/${inpainted.generationId}`).type, 'inpaint');
  assert.equal(usageCount(deps, OWNER), 3);
});

test('rejects unauthenticated, invalid, viewer and non-member requests without using a slot', async () => {
  const deps = makeDeps();
  const call = (auth, data, type = 'generate') => codeOf(runAiRequest({ auth, data }, type, deps));
  const good = { boardId: BOARD, prompt: 'a fox', aspectRatio: '1:1' };

  assert.equal(await call(undefined, good), 'unauthenticated');
  assert.equal(await call({}, good), 'unauthenticated');
  assert.equal(await call({ uid: OWNER }, { ...good, prompt: '  ' }), 'invalid-argument');
  assert.equal(await call({ uid: OWNER }, { ...good, aspectRatio: '4:3' }), 'invalid-argument');
  assert.equal(await call({ uid: OWNER }, { ...good, boardId: 'a/b' }), 'invalid-argument');
  assert.equal(await call({ uid: VIEWER }, good), 'permission-denied');
  assert.equal(await call({ uid: STRANGER }, good), 'permission-denied');
  assert.equal(await call({ uid: OWNER }, { ...good, boardId: 'nope' }), 'not-found');
  assert.equal(
    await call({ uid: OWNER }, { boardId: BOARD, prompt: 'x', sourceImageUrl: 'https://evil.example/a.png' }, 'edit'),
    'invalid-argument',
  );
  assert.equal(
    await call(
      { uid: OWNER },
      { boardId: BOARD, prompt: 'x', sourceImageUrl: 'https://evil.example/a.png', strength: 2 },
      'edit',
    ),
    'invalid-argument',
  );
  assert.equal(
    await call(
      {
        uid: OWNER,
      },
      {
        boardId: BOARD,
        prompt: 'x',
        sourceImageUrl: `${TEST_ENV.CLOUDFLARE_R2_PUBLIC_URL}/ai-images/${BOARD}/g.png`,
        maskBase64: 'AAAA',
      },
      'inpaint',
    ),
    'invalid-argument',
  );

  for (const uid of [OWNER, EDITOR, VIEWER, STRANGER]) {
    assert.equal(usageCount(deps, uid), 0);
  }
  assert.equal(deps.storage.objects.size, 0);
});

test('daily limit reached returns resource-exhausted with a friendly message', async () => {
  const deps = makeDeps({ dailyLimit: 1 });
  const request = { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox' } };
  await runAiRequest(request, 'generate', deps);

  await assert.rejects(runAiRequest(request, 'generate', deps), (error) => {
    assert.equal(error.code, 'resource-exhausted');
    assert.match(error.message, /limit of 1 AI images/);
    return true;
  });
  assert.equal(usageCount(deps, OWNER), 1);
});

test('provider failures are mapped and the slot is refunded', async () => {
  const failing = (code) => ({
    name: 'failing',
    generate: async () => {
      throw new AiProviderError(code, `provider said ${code}`);
    },
  });
  const request = { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox' } };
  const expectations = {
    not_configured: 'failed-precondition',
    timeout: 'deadline-exceeded',
    unavailable: 'unavailable',
    invalid_input: 'invalid-argument',
  };
  for (const [providerCode, httpsCode] of Object.entries(expectations)) {
    const deps = makeDeps({ provider: failing(providerCode) });
    assert.equal(await codeOf(runAiRequest(request, 'generate', deps)), httpsCode);
    assert.equal(usageCount(deps, OWNER), 0, `slot refunded after ${providerCode}`);
    assert.equal(deps.storage.objects.size, 0);
    assert.equal(deps.firestore.docs.get('ai_generations/gen1'), undefined);
  }
});

test('a provider that never answers times out and refunds the slot', async () => {
  const deps = makeDeps({
    provider: { name: 'slow', generate: () => new Promise(() => {}) },
    providerTimeoutMs: 20,
  });
  const request = { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox' } };
  assert.equal(await codeOf(runAiRequest(request, 'generate', deps)), 'deadline-exceeded');
  assert.equal(usageCount(deps, OWNER), 0);
});

test('unexpected errors become "internal", refund the slot and do not leak details', async () => {
  const storage = createFakeStorage();
  storage.upload = async () => {
    throw new Error('R2 exploded: secret-internal-detail');
  };
  const deps = makeDeps({ storage });
  const request = { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox' } };
  await assert.rejects(runAiRequest(request, 'generate', deps), (error) => {
    assert.equal(error.code, 'internal');
    assert.ok(!error.message.includes('secret-internal-detail'));
    return true;
  });
  assert.equal(usageCount(deps, OWNER), 0);
});

test('missing storage configuration fails before access checks or usage', async () => {
  const deps = makeDeps({ storage: createFakeStorage({ configured: false }) });
  const request = { auth: { uid: OWNER }, data: { boardId: BOARD, prompt: 'a fox' } };
  assert.equal(await codeOf(runAiRequest(request, 'generate', deps)), 'failed-precondition');
  assert.equal(usageCount(deps, OWNER), 0);
});

test('editing a source image that no longer exists returns not-found and refunds', async () => {
  const deps = makeDeps();
  const request = {
    auth: { uid: OWNER },
    data: {
      boardId: BOARD,
      prompt: 'x',
      sourceImageUrl: `${TEST_ENV.CLOUDFLARE_R2_PUBLIC_URL}/ai-images/${BOARD}/gone.png`,
    },
  };
  assert.equal(await codeOf(runAiRequest(request, 'edit', deps)), 'not-found');
  assert.equal(usageCount(deps, OWNER), 0);
});
