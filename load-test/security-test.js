/**
 * InkLink Security & Access Control Test Suite (FYP Proposal Page 11)
 *
 * Tests authentication, CORS origin enforcement, RBAC (outsider / viewer /
 * editor / owner), Agora HTTP route auth, and malformed payload validation,
 * then writes load-test/reports/SECURITY_REPORT.md.
 *
 * Usage:
 *   node security-test.js [--target=https://inklink-api.duckdns.org]
 */

const fs = require('fs');
const path = require('path');
const { io } = require('socket.io-client');
const { loadState, mintFreshTokens } = require('./setup-env');

function getArg(name, fallback) {
  const prefix = `--${name}=`;
  const hit = process.argv.find(a => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

const TARGET_URL = getArg('target', process.env.TARGET_URL || 'https://inklink-api.duckdns.org').replace(/\/+$/, '');
const REPORTS_DIR = path.resolve(__dirname, 'reports');
const REPORT_PATH = path.join(REPORTS_DIR, 'SECURITY_REPORT.md');

function connectSocket({ token, extraHeaders, timeoutMs = 8000 } = {}) {
  return new Promise((resolve) => {
    const opts = {
      transports: ['websocket'],
      reconnection: false,
      timeout: timeoutMs,
    };
    if (token !== undefined) opts.auth = { token };
    if (extraHeaders) opts.extraHeaders = extraHeaders;

    const socket = io(TARGET_URL, opts);
    let settled = false;

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      try { socket.disconnect(); } catch (_) {}
      resolve({ ok: false, error: 'timeout' });
    }, timeoutMs + 1000);

    socket.on('connect', () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ ok: true, socket });
    });

    socket.on('connect_error', (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try { socket.disconnect(); } catch (_) {}
      resolve({ ok: false, error: err?.message || String(err) });
    });
  });
}

function emitWithAck(socket, event, payload, timeoutMs = 8000) {
  return new Promise((resolve) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      resolve({ status: 'error', message: 'ack_timeout' });
    }, timeoutMs);

    socket.emit(event, payload, (ack) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(ack);
    });
  });
}

async function main() {
  const state = loadState();
  const boardId = state.boardIds[0];
  const tokens = await mintFreshTokens(state, ['owner', 'editor', 'viewer', 'outsider']);

  const results = [];
  const openSockets = [];

  function record(id, name, expected, observed, passed) {
    results.push({ id, name, expected, observed, passed });
    console.log(`  [${passed ? 'PASS' : 'FAIL'}] #${id} ${name} -> ${observed}`);
  }

  console.log('\n============================================================');
  console.log(' InkLink Security & Access Control Penetration Suite');
  console.log(` Target: ${TARGET_URL}`);
  console.log(` Board:  ${boardId}`);
  console.log('============================================================');

  try {
    // 1. Missing token
    {
      const r = await connectSocket({});
      if (r.ok) openSockets.push(r.socket);
      record(
        1,
        'Socket.IO connect with missing token',
        'Rejected with auth error',
        r.ok ? 'UNEXPECTEDLY CONNECTED' : `Rejected (${r.error})`,
        !r.ok,
      );
    }

    // 2. Forged/invalid JWT
    {
      const forgedJwt = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWtlIiwiZXhwIjo5OTk5OTk5OTk5fQ.invalidsignature';
      const r = await connectSocket({ token: forgedJwt });
      if (r.ok) openSockets.push(r.socket);
      record(
        2,
        'Socket.IO connect with forged/invalid JWT',
        'Rejected with auth error',
        r.ok ? 'UNEXPECTEDLY CONNECTED' : `Rejected (${r.error})`,
        !r.ok,
      );
    }

    // 3. Disallowed Origin
    {
      const r = await connectSocket({
        token: tokens.owner,
        extraHeaders: { Origin: 'https://evil.example' },
      });
      if (r.ok) openSockets.push(r.socket);
      record(
        3,
        'Socket.IO connect with disallowed Origin (https://evil.example)',
        'Rejected by CORS policy',
        r.ok ? 'UNEXPECTEDLY CONNECTED' : `Rejected (${r.error})`,
        !r.ok,
      );
    }

    // 4. Outsider calling watch_board & crdt_update
    {
      const r = await connectSocket({ token: tokens.outsider });
      if (!r.ok) {
        record(4, 'Outsider watch_board & crdt_update', 'Both return forbidden', `Connect failed (${r.error})`, false);
      } else {
        openSockets.push(r.socket);
        const watchAck = await emitWithAck(r.socket, 'watch_board', boardId);
        const updateAck = await emitWithAck(r.socket, 'crdt_update', {
          boardId,
          update: {
            updateId: `sec_outsider_${Date.now()}`,
            payloadBase64: Buffer.from([0, 0]).toString('base64'),
            elementId: 'sec_el_1',
            action: 'upsert',
          },
        });
        const passed =
          watchAck?.status === 'error' && watchAck?.message === 'forbidden' &&
          updateAck?.status === 'error' && updateAck?.message === 'forbidden';
        record(
          4,
          'Outsider watch_board & crdt_update on private board',
          'Both return forbidden',
          `watch_board=${watchAck?.status}:${watchAck?.message}, crdt_update=${updateAck?.status}:${updateAck?.message}`,
          passed,
        );
      }
    }

    // 5. Viewer watch_board succeeds, crdt_update returns forbidden
    {
      const r = await connectSocket({ token: tokens.viewer });
      if (!r.ok) {
        record(5, 'Viewer read-only enforcement', 'watch_board=success, crdt_update=forbidden', `Connect failed (${r.error})`, false);
      } else {
        openSockets.push(r.socket);
        const watchAck = await emitWithAck(r.socket, 'watch_board', boardId);
        const updateAck = await emitWithAck(r.socket, 'crdt_update', {
          boardId,
          update: {
            updateId: `sec_viewer_${Date.now()}`,
            payloadBase64: Buffer.from([0, 0]).toString('base64'),
            elementId: 'sec_el_2',
            action: 'upsert',
          },
        });
        const passed =
          watchAck?.status === 'success' &&
          updateAck?.status === 'error' && updateAck?.message === 'forbidden';
        record(
          5,
          'Viewer watch_board (allow) & crdt_update (deny)',
          'watch_board=success, crdt_update=forbidden',
          `watch_board=${watchAck?.status}, crdt_update=${updateAck?.status}:${updateAck?.message}`,
          passed,
        );
      }
    }

    // 6. Non-owner Editor calling history_get_versions -> forbidden
    {
      const r = await connectSocket({ token: tokens.editor });
      if (!r.ok) {
        record(6, 'Non-owner Editor history_get_versions', 'Returns forbidden (owner-only)', `Connect failed (${r.error})`, false);
      } else {
        openSockets.push(r.socket);
        const histAck = await emitWithAck(r.socket, 'history_get_versions', {
          boardId,
          limit: 10,
        });
        const passed = histAck?.status === 'error' && histAck?.message === 'forbidden';
        record(
          6,
          'Non-owner Editor calling history_get_versions',
          'Returns forbidden (owner-only)',
          `history_get_versions=${histAck?.status}:${histAck?.message}`,
          passed,
        );

        // 8. Malformed crdt_update payload (empty payloadBase64) -> invalid_payload
        const badAck = await emitWithAck(r.socket, 'crdt_update', {
          boardId,
          update: {
            updateId: `sec_malformed_${Date.now()}`,
            payloadBase64: '',
            elementId: 'sec_el_bad',
            action: 'upsert',
          },
        });
        const badPassed = badAck?.status === 'error' && badAck?.message === 'invalid_payload';
        record(
          8,
          'Malformed crdt_update (empty payloadBase64)',
          'Returns invalid_payload',
          `crdt_update=${badAck?.status}:${badAck?.message}`,
          badPassed,
        );
      }
    }

    // 7. POST /api/agora/rtc/token -> 401 unauthenticated, 403 outsider
    {
      const unauthRes = await fetch(`${TARGET_URL}/api/agora/rtc/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ boardId }),
      });
      const outsiderRes = await fetch(`${TARGET_URL}/api/agora/rtc/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${tokens.outsider}`,
        },
        body: JSON.stringify({ boardId }),
      });
      const passed = unauthRes.status === 401 && outsiderRes.status === 403;
      record(
        7,
        'POST /api/agora/rtc/token auth & RBAC',
        'Unauthenticated=401, Outsider=403',
        `Unauthenticated=HTTP ${unauthRes.status}, Outsider=HTTP ${outsiderRes.status}`,
        passed,
      );
    }
  } finally {
    for (const s of openSockets) {
      try { s.disconnect(); } catch (_) {}
    }
  }

  // Sort by check id so #7 appears before #8 in the report
  results.sort((a, b) => a.id - b.id);
  const passedCount = results.filter(r => r.passed).length;
  const allPassed = passedCount === results.length;

  fs.mkdirSync(REPORTS_DIR, { recursive: true });
  let md = `# InkLink Security & Access Control Report (${allPassed ? '✅ PASS' : '❌ FAIL'})\n\n`;
  md += `**Timestamp:** ${new Date().toISOString()}  \n`;
  md += `**Target Server:** \`${TARGET_URL}\`  \n`;
  md += `**Test Board:** \`${boardId}\`  \n`;
  md += `**Score:** **${passedCount}/${results.length}** checks passed  \n\n`;
  md += '| # | Security Check | Expected Behavior | Observed Result | Status |\n';
  md += '| :-: | :--- | :--- | :--- | :---: |\n';
  for (const r of results) {
    md += `| ${r.id} | ${r.name} | ${r.expected} | ${r.observed} | ${r.passed ? '✅ PASS' : '❌ FAIL'} |\n`;
  }
  fs.writeFileSync(REPORT_PATH, md);

  console.log('------------------------------------------------------------');
  console.log(` Result: ${passedCount}/${results.length} passed (${allPassed ? 'ALL PASS' : 'FAILURES DETECTED'})`);
  console.log(` Report: ${REPORT_PATH}`);
  console.log('============================================================\n');

  process.exit(allPassed ? 0 : 1);
}

main().catch((err) => {
  console.error('\n[security-test] FAILED:', err.message);
  process.exit(1);
});
