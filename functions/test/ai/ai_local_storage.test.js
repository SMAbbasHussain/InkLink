const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  isLocalStorageEnabled,
  createLocalStorage,
  createAiStorage,
} = require('../../src/ai/ai_storage_utils');

test('local storage is off unless BOTH emulator and opt-in flags are set', () => {
  assert.equal(isLocalStorageEnabled({}), false);
  assert.equal(isLocalStorageEnabled({ AI_LOCAL_STORAGE: 'true' }), false);
  assert.equal(isLocalStorageEnabled({ FUNCTIONS_EMULATOR: 'true' }), false);
  assert.equal(
    isLocalStorageEnabled({ FUNCTIONS_EMULATOR: 'true', AI_LOCAL_STORAGE: 'true' }),
    true,
  );
});

test('production (no emulator flag) always gets R2 storage', () => {
  const storage = createAiStorage({ AI_LOCAL_STORAGE: 'true' });
  // R2 storage refuses to run without its secrets; local storage never throws.
  assert.throws(() => storage.assertConfigured());
});

test('local storage round-trips an image and validates source URLs', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-local-test-'));
  try {
    const storage = createLocalStorage({
      AI_LOCAL_STORAGE_DIR: dir,
      AI_LOCAL_IMAGE_BASE_URL: 'http://127.0.0.1:5005',
    });
    storage.assertConfigured();

    const png = Buffer.from('fake-png-bytes');
    const url = await storage.upload({ boardId: 'board1', generationId: 'gen1', pngBuffer: png });
    assert.equal(url, 'http://127.0.0.1:5005/ai-images/board1/gen1.png');

    const key = storage.parseSourceUrl(url, 'board1');
    assert.deepEqual(await storage.download(key), png);

    assert.throws(() => storage.parseSourceUrl('https://evil.example/x.png', 'board1'));
    assert.throws(() => storage.parseSourceUrl(url, 'otherBoard'));
    await assert.rejects(() => storage.download('ai-images/board1/missing.png'), {
      code: 'not-found',
    });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
