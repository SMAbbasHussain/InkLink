const { test } = require('node:test');
const assert = require('node:assert/strict');
const { resolveAiAccountId } = require('../../src/ai/ai_provider_utils');

test('AI uses the R2 Cloudflare account when no separate AI account is set', () => {
  assert.equal(resolveAiAccountId({ CLOUDFLARE_ACCOUNT_ID: 'team' }), 'team');
  assert.equal(
    resolveAiAccountId({ CLOUDFLARE_ACCOUNT_ID: 'team', CLOUDFLARE_AI_ACCOUNT_ID: '  ' }),
    'team',
  );
});

test('CLOUDFLARE_AI_ACCOUNT_ID moves only the AI calls to another account', () => {
  assert.equal(
    resolveAiAccountId({ CLOUDFLARE_ACCOUNT_ID: 'team', CLOUDFLARE_AI_ACCOUNT_ID: ' mine ' }),
    'mine',
  );
});
