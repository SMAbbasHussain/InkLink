/**
 * InkLink Stress Test Suite Orchestrator (Before / After / Breaking-Point)
 *
 * Usage:
 *   node run-suite.js --phase=before [--target=https://inklink-api.duckdns.org]
 *   node run-suite.js --phase=after  [--target=https://inklink-api.duckdns.org]
 *   node run-suite.js --phase=breaking-point [--target=https://inklink-api.duckdns.org]
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { loadState, mintFreshTokens } = require('./setup-env');

function getArg(name, fallback) {
  const prefix = `--${name}=`;
  const hit = process.argv.find(a => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

const PHASE = getArg('phase', '');
const TARGET_URL = getArg('target', process.env.TARGET_URL || 'https://inklink-api.duckdns.org').replace(/\/+$/, '');
const STRESS_SCRIPT = path.resolve(__dirname, 'stress-test.js');
const REPORTS_DIR = path.resolve(__dirname, 'reports');
const SETTLE_PAUSE_MS = 5000;
const TOKEN_REFRESH_INTERVAL_MS = 40 * 60 * 1000; // Refresh before 1-hour expiry

const PHASES = {
  before: [
    {
      label: '01-before-baseline-5vu',
      args: ['--mode=baseline', '--vus=5', '--duration=45', '--previewHz=10', '--updateHz=1', '--notes=OLD server (before hot-path optimization)'],
    },
    {
      label: '02-before-fanout-30vu',
      args: ['--mode=fanout', '--vus=30', '--duration=45', '--previewHz=10', '--updateHz=0.5', '--notes=OLD server (before hot-path optimization)'],
    },
    {
      label: '03-before-fanout-50vu',
      args: ['--mode=fanout', '--vus=50', '--duration=45', '--previewHz=10', '--updateHz=0.5', '--notes=OLD server (before hot-path optimization)'],
    },
    {
      label: '04-before-ws-ceiling-100vu',
      args: ['--mode=previewonly', '--vus=100', '--duration=30', '--previewHz=15', '--notes=OLD server pure WS fan-out (0 Redis cost)'],
    },
  ],
  after: [
    {
      label: '05-after-baseline-5vu',
      args: ['--mode=baseline', '--vus=5', '--duration=45', '--previewHz=10', '--updateHz=1', '--notes=NEW optimized server (matches 01-before)'],
    },
    {
      label: '06-after-fanout-15vu',
      args: ['--mode=fanout', '--vus=15', '--duration=45', '--previewHz=10', '--updateHz=0.5', '--notes=NEW server - small classroom'],
    },
    {
      label: '07-after-fanout-30vu',
      args: ['--mode=fanout', '--vus=30', '--duration=45', '--previewHz=10', '--updateHz=0.5', '--notes=NEW optimized server (matches 02-before)'],
    },
    {
      label: '08-after-fanout-50vu',
      args: ['--mode=fanout', '--vus=50', '--duration=45', '--previewHz=10', '--updateHz=0.5', '--notes=NEW optimized server (matches 03-before)'],
    },
    {
      label: '09-after-offline-herd-25vu',
      args: ['--mode=offline', '--vus=25', '--offlineOps=150', '--notes=NEW server - 15 offline clients catch up 150 ops simultaneously'],
    },
    {
      label: '10-after-ws-ceiling-100vu',
      args: ['--mode=previewonly', '--vus=100', '--duration=30', '--previewHz=15', '--notes=NEW optimized server pure WS fan-out (matches 04-before, 0 Redis cost)'],
    },
    {
      label: '11-after-ws-ceiling-150vu',
      args: ['--mode=previewonly', '--vus=150', '--duration=30', '--previewHz=15', '--notes=NEW server - pushing single-board WS fan-out ceiling (0 Redis cost)'],
    },
    {
      label: '12-after-multiboard-100vu',
      args: ['--mode=multiboard', '--vus=100', '--duration=45', '--previewHz=5', '--updateHz=0.3', '--notes=NEW server - 100 users across 10 boards'],
    },
    {
      label: '13-after-multiboard-250vu',
      args: ['--mode=multiboard', '--vus=250', '--duration=45', '--previewHz=5', '--updateHz=0.2', '--notes=NEW server - 250 users across 10 boards'],
    },
  ],
  'breaking-point': [
    {
      label: '14-bp-ws-ceiling-200vu',
      args: ['--mode=previewonly', '--vus=200', '--duration=30', '--previewHz=15', '--notes=Breaking-point pure WS fan-out 200 VUs (0 Redis cost)'],
    },
    {
      label: '15-bp-ws-ceiling-300vu',
      args: ['--mode=previewonly', '--vus=300', '--duration=30', '--previewHz=15', '--notes=Breaking-point pure WS fan-out 300 VUs (0 Redis cost)'],
    },
    {
      label: '16-bp-multiboard-400vu',
      args: ['--mode=multiboard', '--vus=400', '--duration=45', '--previewHz=3', '--updateHz=0.1', '--notes=Breaking-point multi-board 400 VUs across 10 boards'],
    },
    {
      label: '17-bp-multiboard-600vu',
      args: ['--mode=multiboard', '--vus=600', '--duration=45', '--previewHz=3', '--updateHz=0.1', '--notes=Breaking-point multi-board 600 VUs across 10 boards'],
    },
  ],
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function parseCsvLine(line) {
  const out = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"' && line[i + 1] === '"') {
      cur += '"';
      i++;
    } else if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      out.push(cur);
      cur = '';
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}

function fmtPctDelta(beforeVal, afterVal) {
  const b = Number(beforeVal);
  const a = Number(afterVal);
  if (!Number.isFinite(b) || !Number.isFinite(a) || b <= 0) return '—';
  const pct = ((b - a) / b) * 100;
  const sign = pct >= 0 ? '-' : '+';
  return `${sign}${Math.abs(pct).toFixed(1)}%`;
}

function generateBeforeVsAfterReport() {
  const csvPath = path.join(REPORTS_DIR, 'all-runs-summary.csv');
  if (!fs.existsSync(csvPath)) {
    console.warn('[run-suite] Skipping BEFORE_VS_AFTER.md — all-runs-summary.csv not found.');
    return;
  }

  const lines = fs.readFileSync(csvPath, 'utf8').trim().split(/\r?\n/);
  if (lines.length < 2) return;

  const headers = parseCsvLine(lines[0]);
  const latestByLabel = new Map();
  for (const line of lines.slice(1)) {
    const cols = parseCsvLine(line);
    const row = {};
    headers.forEach((h, i) => { row[h] = cols[i]; });
    if (row.label) latestByLabel.set(row.label, row);
  }

  const pairs = [
    {
      name: 'Baseline (5 VUs, 1 board)',
      beforeLabel: '01-before-baseline-5vu',
      afterLabel: '05-after-baseline-5vu',
      primaryKey: 'update_e2e_p95_ms',
      secondaryKey: 'update_e2e_p99_ms',
      metricName: 'Update E2E',
    },
    {
      name: 'Single-Board Fan-Out (30 VUs)',
      beforeLabel: '02-before-fanout-30vu',
      afterLabel: '07-after-fanout-30vu',
      primaryKey: 'update_e2e_p95_ms',
      secondaryKey: 'update_e2e_p99_ms',
      metricName: 'Update E2E',
    },
    {
      name: 'Single-Board Fan-Out (50 VUs)',
      beforeLabel: '03-before-fanout-50vu',
      afterLabel: '08-after-fanout-50vu',
      primaryKey: 'update_e2e_p95_ms',
      secondaryKey: 'update_e2e_p99_ms',
      metricName: 'Update E2E',
    },
    {
      name: 'Pure WS Ceiling (100 VUs, 0 Redis)',
      beforeLabel: '04-before-ws-ceiling-100vu',
      afterLabel: '10-after-ws-ceiling-100vu',
      primaryKey: 'preview_p95_ms',
      secondaryKey: 'preview_p99_ms',
      metricName: 'Preview E2E',
    },
  ];

  let md = '# InkLink Before vs. After Optimization Comparison\n\n';
  md += `**Generated:** ${new Date().toISOString()}  \n`;
  md += `**Target Server:** \`${TARGET_URL}\`  \n\n`;
  md += 'Negative percentage values indicate **latency reduction (faster)** after deploying the 5 hot-path optimizations.\n\n';
  md += '| Scenario | Metric | Before p95 | After p95 | p95 Change | Before p99 | After p99 | p99 Change | After Peak RAM / Loop Lag | Reports |\n';
  md += '| :--- | :--- | ---: | ---: | :---: | ---: | ---: | :---: | :---: | :--- |\n';

  let matchedCount = 0;
  for (const p of pairs) {
    const b = latestByLabel.get(p.beforeLabel);
    const a = latestByLabel.get(p.afterLabel);
    if (!b && !a) continue;
    if (b && a) matchedCount++;

    const bP95 = b ? `${b[p.primaryKey]} ms` : '*(missing)*';
    const aP95 = a ? `${a[p.primaryKey]} ms` : '*(missing)*';
    const bP99 = b ? `${b[p.secondaryKey]} ms` : '*(missing)*';
    const aP99 = a ? `${a[p.secondaryKey]} ms` : '*(missing)*';
    const dP95 = b && a ? `**${fmtPctDelta(b[p.primaryKey], a[p.primaryKey])}**` : '—';
    const dP99 = b && a ? `**${fmtPctDelta(b[p.secondaryKey], a[p.secondaryKey])}**` : '—';
    const srv = a && Number(a.server_peak_rss_mb) > 0
      ? `${a.server_peak_rss_mb} MB / ${a.server_peak_loop_lag_p95_ms} ms`
      : '—';
    const links = [
      b ? `[before](./${b.report_file})` : 'before: n/a',
      a ? `[after](./${a.report_file})` : 'after: n/a',
    ].join(' · ');

    md += `| **${p.name}** | ${p.metricName} | ${bP95} | ${aP95} | ${dP95} | ${bP99} | ${aP99} | ${dP99} | ${srv} | ${links} |\n`;
  }

  if (matchedCount === 0) {
    md += '\n> Note: Run `--phase=before` first and `--phase=after` after deploying the optimized server to populate paired before/after deltas.\n';
  }

  const outPath = path.join(REPORTS_DIR, 'BEFORE_VS_AFTER.md');
  fs.writeFileSync(outPath, md);
  console.log(`\n[run-suite] Wrote before/after comparison: ${outPath}`);
}

async function checkAfterHealth() {
  try {
    const res = await fetch(`${TARGET_URL}/health`);
    if (!res.ok) {
      console.warn(`\n[WARNING] GET ${TARGET_URL}/health returned HTTP ${res.status}. Proceeding anyway...\n`);
      return;
    }
    const data = await res.json();
    if (!data || !data.metrics) {
      console.warn('\n============================================================');
      console.warn(' WARNING: /health did NOT return `metrics`!');
      console.warn(' The optimized server/src/index.js may NOT be deployed yet.');
      console.warn(' Deploy and restart EC2 before running --phase=after if you');
      console.warn(' want true post-optimization numbers and server telemetry.');
      console.warn('============================================================\n');
    } else {
      console.log(
        `[health] Optimized server confirmed: RSS=${data.metrics.rssMB}MB, ` +
        `Heap=${data.metrics.heapUsedMB}MB, LoopLagP95=${data.metrics.eventLoopLagP95Ms}ms`,
      );
    }
  } catch (err) {
    console.warn(`\n[WARNING] Failed to reach ${TARGET_URL}/health: ${err.message}\n`);
  }
}

async function main() {
  if (!PHASES[PHASE]) {
    console.error('\nUsage: node run-suite.js --phase=before|after|breaking-point [--target=https://inklink-api.duckdns.org]\n');
    process.exit(1);
  }

  const state = loadState();
  const runs = PHASES[PHASE];

  console.log('\n============================================================');
  console.log(` InkLink Load Suite | phase="${PHASE}" | runs=${runs.length}`);
  console.log(` Target: ${TARGET_URL}`);
  console.log(` Boards: ${state.boardIds.length} (${state.boardIds[0]} .. ${state.boardIds[state.boardIds.length - 1]})`);
  console.log('============================================================');

  if (PHASE === 'after') {
    await checkAfterHealth();
  } else if (PHASE === 'breaking-point') {
    console.warn('\n============================================================');
    console.warn(' WARNING: BREAKING-POINT PHASE');
    console.warn(' Runs 16 & 17 (400 & 600 VUs across 10 boards) generate');
    console.warn(' heavy Upstash Redis + Firestore traffic. Verify your');
    console.warn(' Upstash Free Tier (500K cmds/mo) headroom before running.');
    console.warn('============================================================\n');
  }

  let mintedAt = 0;
  let firebaseTokensEnv = '';

  async function ensureFreshTokens() {
    if (!firebaseTokensEnv || Date.now() - mintedAt > TOKEN_REFRESH_INTERVAL_MS) {
      const tokens = await mintFreshTokens(state, ['owner', 'editor']);
      firebaseTokensEnv = `${tokens.owner},${tokens.editor}`;
      mintedAt = Date.now();
      console.log('[run-suite] Minted fresh 1h Firebase ID tokens for owner + editor.');
    }
  }

  for (let i = 0; i < runs.length; i++) {
    const run = runs[i];
    await ensureFreshTokens();

    console.log(`\n>>> [${i + 1}/${runs.length}] Starting ${run.label} ...`);
    const childEnv = {
      ...process.env,
      TARGET_URL,
      FIREBASE_TOKENS: firebaseTokensEnv,
      BOARD_IDS: state.boardIds.join(','),
    };

    const result = spawnSync(
      process.execPath,
      [STRESS_SCRIPT, `--label=${run.label}`, ...run.args],
      {
        cwd: __dirname,
        env: childEnv,
        stdio: 'inherit',
      },
    );

    if (result.status !== 0) {
      console.warn(`[run-suite] Run "${run.label}" exited with code ${result.status}`);
    }

    if (i < runs.length - 1) {
      console.log(`[run-suite] Settling EC2 server for ${SETTLE_PAUSE_MS / 1000}s...`);
      await sleep(SETTLE_PAUSE_MS);
    }
  }

  if (PHASE === 'after') {
    generateBeforeVsAfterReport();
  }

  console.log(`\n[run-suite] Phase "${PHASE}" complete. See reports/MASTER_SUMMARY.md.\n`);
}

main().catch((err) => {
  console.error('\n[run-suite] FAILED:', err.message);
  process.exit(1);
});
