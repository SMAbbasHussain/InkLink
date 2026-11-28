/**
 * InkLink Stress & Load Testing Harness (FYP Report Edition)
 * Matched 100% to server/src/index.js
 *
 * Modes:
 *   --mode=baseline    5 VUs on 1 board (FYP Proposal Page 11 compliance proof)
 *   --mode=fanout      N VUs on 1 board (O(N^2) single-board classroom storm)
 *   --mode=multiboard  N VUs distributed across multiple boards
 *   --mode=offline     Disconnect 60% of VUs, write ops, reconnect all together (thundering herd)
 *   --mode=previewonly Pure Socket.IO fan-out (updateHz=0 -> ZERO Upstash/Firestore/R2 cost!)
 *
 * Required Env Vars:
 *   TARGET_URL=https://inklink-api.duckdns.org
 *   FIREBASE_TOKENS="<token1>,<token2>..."   (or single token)
 *   BOARD_IDS="<board1>,<board2>..."
 *
 * Optional Flags:
 *   --label="before-fix"     Tag for Before vs. After comparisons
 *   --notes="4G throttled"   Custom note included in the Markdown report
 *   --vus=30                 Number of virtual users
 *   --duration=60            Duration in seconds
 *   --activeRatio=0.35       Fraction of VUs actively drawing (0.0 - 1.0)
 *   --previewHz=10           Ephemeral crdt_preview/sec per active VU
 *   --updateHz=0.5           Durable crdt_update/sec per active VU
 *   --chatEverySec=0         Seconds between board chat msgs per active VU (0 = off)
 *   --offlineOps=150         Ops generated while offline in --mode=offline
 *   --elementPool=30         Bounded element ID pool (keeps Firestore snapshot < 1 MiB)
 */

const { io } = require('socket.io-client');
const Y = require('yjs');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

// ---------------- CLI & ENV PARSING ----------------
function getArg(name, fallback) {
  const prefix = `--${name}=`;
  const hit = process.argv.find(a => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

const TARGET_URL = (process.env.TARGET_URL || 'https://inklink-api.duckdns.org').replace(/\/+$/, '');
const TOKENS = (process.env.FIREBASE_TOKENS || process.env.FIREBASE_TOKEN || '')
  .split(',').map(s => s.trim()).filter(Boolean);
const BOARD_IDS = (process.env.BOARD_IDS || '')
  .split(',').map(s => s.trim()).filter(Boolean);

const MODE = getArg('mode', 'baseline');
const LABEL = getArg('label', MODE).replace(/[^a-zA-Z0-9_-]/g, '-');
const NOTES = getArg('notes', '');
const VUS = parseInt(getArg('vus', MODE === 'baseline' ? '5' : '25'), 10);
const DURATION_SEC = parseInt(getArg('duration', '60'), 10);
const ACTIVE_RATIO = parseFloat(getArg('activeRatio', MODE === 'baseline' ? '1.0' : '0.35'));
const PREVIEW_HZ = parseFloat(getArg('previewHz', MODE === 'previewonly' ? '15' : '10'));
const UPDATE_HZ = MODE === 'previewonly' ? 0 : parseFloat(getArg('updateHz', MODE === 'baseline' ? '1' : '0.5'));
const CHAT_EVERY_SEC = parseFloat(getArg('chatEverySec', '0'));
const ELEMENT_POOL = parseInt(getArg('elementPool', '30'), 10);
const OFFLINE_OPS = parseInt(getArg('offlineOps', '150'), 10);
const RAMP_DELAY_MS = parseInt(getArg('rampDelayMs', '30'), 10);
const REPORTS_DIR = path.resolve(getArg('outDir', './reports'));

if (!TOKENS.length || !BOARD_IDS.length) {
  console.error('\nERROR: Set FIREBASE_TOKENS (or FIREBASE_TOKEN) and BOARD_IDS environment variables first.\n');
  process.exit(1);
}

const EFFECTIVE_BOARDS = MODE === 'multiboard' ? BOARD_IDS : [BOARD_IDS[0]];
const FYP_LATENCY_SLA_MS = 1000; // Proposal Page 11 Success Criterion: <= 1s per update

// ---------------- RESERVOIR SAMPLER (safe for long soak tests) ----------------
class MetricBucket {
  constructor(maxSamples = 50000) {
    this.maxSamples = maxSamples;
    this.samples = [];
    this.totalCount = 0;
    this.sum = 0;
    this.min = Infinity;
    this.max = 0;
  }

  add(val) {
    if (!Number.isFinite(val) || val < 0 || val > 120000) return;
    this.totalCount++;
    this.sum += val;
    if (val < this.min) this.min = val;
    if (val > this.max) this.max = val;

    if (this.samples.length < this.maxSamples) {
      this.samples.push(val);
    } else {
      const idx = Math.floor(Math.random() * this.totalCount);
      if (idx < this.maxSamples) this.samples[idx] = val;
    }
  }

  summarize() {
    if (this.totalCount === 0) {
      return { count: 0, avg: 0, min: 0, p50: 0, p95: 0, p99: 0, max: 0 };
    }
    const sorted = [...this.samples].sort((a, b) => a - b);
    const pct = (p) => {
      const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
      return Number(sorted[idx].toFixed(2));
    };
    return {
      count: this.totalCount,
      avg: Number((this.sum / this.totalCount).toFixed(2)),
      min: Number(this.min.toFixed(2)),
      p50: pct(50),
      p95: pct(95),
      p99: pct(99),
      max: Number(this.max.toFixed(2)),
    };
  }
}

const metrics = {
  connectMs: new MetricBucket(),
  watchMs: new MetricBucket(),
  previewE2eMs: new MetricBucket(),
  updateAckMs: new MetricBucket(),
  updateE2eMs: new MetricBucket(),
  syncOfflineMs: new MetricBucket(),
  connectErrors: 0,
  disconnects: 0,
  rateLimited: 0,
  ackErrors: 0,
  previewsSent: 0,
  previewsReceived: 0,
  updatesSent: 0,
  updatesAcked: 0,
  updatesReceived: 0,
  chatsSent: 0,
  chatsReceived: 0,
};

// ---------------- SERVER /health TELEMETRY POLLER ----------------
const serverTelemetry = {
  polls: 0,
  healthFailures: 0,
  hasDetailedMetrics: false,
  rssStartMB: null,
  rssEndMB: null,
  rssPeakMB: 0,
  heapStartMB: null,
  heapEndMB: null,
  heapPeakMB: 0,
  peakActiveSockets: 0,
  peakLoopLagP95Ms: 0,
  peakLoopLagMaxMs: 0,
};

async function pollHealthOnce() {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    const res = await fetch(`${TARGET_URL}/health`, { signal: controller.signal });
    clearTimeout(timer);
    if (!res.ok) {
      serverTelemetry.healthFailures++;
      return;
    }
    const data = await res.json();
    serverTelemetry.polls++;
    if (data && data.metrics && typeof data.metrics === 'object') {
      serverTelemetry.hasDetailedMetrics = true;
      const m = data.metrics;
      if (typeof m.rssMB === 'number') {
        if (serverTelemetry.rssStartMB === null) serverTelemetry.rssStartMB = m.rssMB;
        serverTelemetry.rssEndMB = m.rssMB;
        serverTelemetry.rssPeakMB = Math.max(serverTelemetry.rssPeakMB, m.rssMB);
      }
      if (typeof m.heapUsedMB === 'number') {
        if (serverTelemetry.heapStartMB === null) serverTelemetry.heapStartMB = m.heapUsedMB;
        serverTelemetry.heapEndMB = m.heapUsedMB;
        serverTelemetry.heapPeakMB = Math.max(serverTelemetry.heapPeakMB, m.heapUsedMB);
      }
      if (typeof m.activeSockets === 'number') {
        serverTelemetry.peakActiveSockets = Math.max(serverTelemetry.peakActiveSockets, m.activeSockets);
      }
      if (typeof m.eventLoopLagP95Ms === 'number') {
        serverTelemetry.peakLoopLagP95Ms = Math.max(serverTelemetry.peakLoopLagP95Ms, m.eventLoopLagP95Ms);
      }
      if (typeof m.eventLoopLagMaxMs === 'number') {
        serverTelemetry.peakLoopLagMaxMs = Math.max(serverTelemetry.peakLoopLagMaxMs, m.eventLoopLagMaxMs);
      }
    }
  } catch (_) {
    serverTelemetry.healthFailures++;
  }
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// ---------------- TEST DESCRIPTION GENERATOR ----------------
function describeTestScenario() {
  const activeCount = Math.max(1, Math.round(VUS * ACTIVE_RATIO));
  switch (MODE) {
    case 'baseline':
      return `FYP Proposal Compliance Baseline: ${VUS} concurrent users collaborating on 1 shared board (all ${activeCount} actively editing at ${PREVIEW_HZ} previews/s + ${UPDATE_HZ} CRDT commits/s for ${DURATION_SEC}s) to verify Page 11's <= 1,000 ms latency and 100% CRDT convergence criteria.`;
    case 'fanout':
      return `Single-Board O(N^2) Fan-Out Stress: ${VUS} concurrent users inside 1 shared board (${activeCount} actively drawing at ${PREVIEW_HZ} previews/s + ${UPDATE_HZ} CRDT commits/s for ${DURATION_SEC}s) to test Socket.IO broadcast amplification and Node.js single-core CPU limits.`;
    case 'previewonly':
      return `Pure WebSocket Fan-Out Ceiling (Zero Redis/DB Cost): ${VUS} users on 1 board (${activeCount} emitting ${PREVIEW_HZ} ephemeral crdt_preview frames/s for ${DURATION_SEC}s) to isolate NGINX + Socket.IO single-core throughput without touching Upstash Redis or Firestore.`;
    case 'multiboard':
      return `Multi-Board Horizontal Concurrency: ${VUS} users distributed across ${EFFECTIVE_BOARDS.length} boards (~${Math.round(VUS / EFFECTIVE_BOARDS.length)} users/board, ${activeCount} active writers at ${PREVIEW_HZ} previews/s + ${UPDATE_HZ} commits/s for ${DURATION_SEC}s) to evaluate memory stability and multi-room scaling.`;
    case 'offline':
      return `Offline Catch-Up & Thundering Herd: ${VUS} users join 1 board, 60% disconnect while the remaining online users commit ${OFFLINE_OPS} CRDT updates to Redis Streams, then all offline users reconnect simultaneously and invoke sync_offline to verify catch-up latency and zero-conflict convergence.`;
    default:
      return `Custom load test (${MODE}): ${VUS} VUs across ${EFFECTIVE_BOARDS.length} board(s) for ${DURATION_SEC}s.`;
  }
}

// ---------------- VIRTUAL USER ----------------
function createVU(index, boardId, existingDoc = null) {
  const token = TOKENS[index % TOKENS.length];
  const doc = existingDoc || new Y.Doc();
  const elements = doc.getMap('elements');
  let lastVersion = 0;

  return new Promise((resolve) => {
    const t0 = performance.now();
    const socket = io(TARGET_URL, {
      transports: ['websocket'],
      auth: { token },
      reconnection: false,
      timeout: 15000,
    });

    const vu = {
      index,
      boardId,
      socket,
      doc,
      elements,
      connected: false,
      getLastVersion: () => lastVersion,
    };

    socket.on('connect', () => {
      metrics.connectMs.add(performance.now() - t0);
      vu.connected = true;

      const tw = performance.now();
      socket.emit('watch_board', boardId, (ack) => {
        metrics.watchMs.add(performance.now() - tw);
        if (!ack || ack.status !== 'success') {
          metrics.ackErrors++;
          console.warn(`[VU ${index}] watch_board failed:`, ack);
        } else {
          lastVersion = ack.currentVersion || 0;
        }
        resolve(vu);
      });
    });

    socket.on('connect_error', (err) => {
      metrics.connectErrors++;
      console.warn(`[VU ${index}] connect_error: ${err.message}`);
      resolve(vu);
    });

    socket.on('disconnect', (reason) => {
      if (vu.connected && reason !== 'io client disconnect') {
        metrics.disconnects++;
      }
      vu.connected = false;
    });

    socket.on('crdt_preview', ({ preview } = {}) => {
      metrics.previewsReceived++;
      if (preview && typeof preview.sentAt === 'number') {
        metrics.previewE2eMs.add(performance.now() - preview.sentAt);
      }
    });

    socket.on('crdt_update', ({ update } = {}) => {
      metrics.updatesReceived++;
      if (update && typeof update._stressSentAt === 'number') {
        metrics.updateE2eMs.add(performance.now() - update._stressSentAt);
      }
      if (update && typeof update.version === 'number' && update.version > lastVersion) {
        lastVersion = update.version;
      }
      if (update && update.payloadBase64) {
        try {
          Y.applyUpdate(doc, Buffer.from(update.payloadBase64, 'base64'));
        } catch (_) {}
      }
    });

    socket.on('board_chat_message', () => {
      metrics.chatsReceived++;
    });
  });
}

function sendPreview(vu) {
  if (!vu.connected) return;
  metrics.previewsSent++;
  vu.socket.emit('crdt_preview', {
    boardId: vu.boardId,
    preview: {
      previewId: `prev_${vu.index}_${Date.now()}`,
      elementId: `stress_el_${vu.index % ELEMENT_POOL}`,
      type: 'stroke',
      x: Math.round(Math.random() * 1000),
      y: Math.round(Math.random() * 1000),
      sentAt: performance.now(),
    },
  });
}

function sendCrdtUpdate(vu, seq) {
  if (!vu.connected) return Promise.resolve();
  const elementId = `stress_el_${(vu.index + seq) % ELEMENT_POOL}`;
  const svBefore = Y.encodeStateVector(vu.doc);

  vu.doc.transact(() => {
    vu.elements.set(elementId, {
      id: elementId,
      type: 'stickyNote',
      x: Math.round(Math.random() * 1200),
      y: Math.round(Math.random() * 800),
      width: 160,
      height: 120,
      color: '#FFE066',
      text: `vu${vu.index}-op${seq}`,
    });
  });

  const delta = Y.encodeStateAsUpdate(vu.doc, svBefore);
  const updateId = `stress_${crypto.randomUUID()}`;
  const sentAt = performance.now();
  metrics.updatesSent++;

  return new Promise((resolve) => {
    vu.socket.emit(
      'crdt_update',
      {
        boardId: vu.boardId,
        update: {
          updateId,
          payloadBase64: Buffer.from(delta).toString('base64'),
          elementId,
          action: 'upsert',
          _stressSentAt: sentAt,
        },
      },
      (ack) => {
        metrics.updateAckMs.add(performance.now() - sentAt);
        if (ack && ack.status === 'success') {
          metrics.updatesAcked++;
        } else if (ack && ack.message === 'rate_limited') {
          metrics.rateLimited++;
        } else {
          metrics.ackErrors++;
        }
        resolve(ack);
      },
    );
  });
}

// ---------------- CONVERGENCE CHECK ----------------
function checkConvergence(vus) {
  const byBoard = new Map();
  for (const vu of vus.filter(v => v.connected)) {
    const json = vu.elements.toJSON();
    const sorted = Object.keys(json).sort().reduce((acc, k) => {
      acc[k] = json[k];
      return acc;
    }, {});
    const hash = crypto.createHash('sha256').update(JSON.stringify(sorted)).digest('hex').slice(0, 12);
    if (!byBoard.has(vu.boardId)) byBoard.set(vu.boardId, { clients: 0, hashes: new Set(), elements: Object.keys(json).length });
    const entry = byBoard.get(vu.boardId);
    entry.clients++;
    entry.hashes.add(hash);
    entry.elements = Math.max(entry.elements, Object.keys(json).length);
  }
  const results = {};
  let allConverged = true;
  for (const [bId, info] of byBoard.entries()) {
    const converged = info.hashes.size <= 1;
    if (!converged) allConverged = false;
    results[bId] = {
      clientsChecked: info.clients,
      elementsCount: info.elements,
      uniqueStateHashes: info.hashes.size,
      converged,
      sampleHash: [...info.hashes][0] || 'n/a',
    };
  }
  return { allConverged, byBoard: results };
}

// ---------------- EVALUATION & REPORT WRITER ----------------
function evaluateResults(summary) {
  const checks = [];
  const totalOps = summary.counts.previewsSent + summary.counts.updatesSent + summary.counts.chatsSent;
  const totalErrors = summary.counts.connectErrors + summary.counts.ackErrors;
  const errorRatePct = totalOps > 0 ? Number(((totalErrors / totalOps) * 100).toFixed(3)) : (totalErrors > 0 ? 100 : 0);

  // Pick the primary latency metric for SLA check
  const primaryP95 = summary.updateE2eMs.count > 0
    ? summary.updateE2eMs.p95
    : (summary.previewE2eMs.count > 0 ? summary.previewE2eMs.p95 : summary.syncOfflineMs.p95);

  const primaryLabel = summary.updateE2eMs.count > 0
    ? 'crdt_update E2E p95'
    : (summary.previewE2eMs.count > 0 ? 'crdt_preview E2E p95' : 'sync_offline p95');

  checks.push({
    criterion: 'Connection Success',
    target: '100% of VUs connect & join board',
    actual: `${summary.connected}/${summary.vus} connected (${summary.counts.connectErrors} errors)`,
    passed: summary.connected === summary.vus && summary.counts.connectErrors === 0,
  });

  checks.push({
    criterion: 'Sync Latency SLA (Proposal Page 11)',
    target: `<= ${FYP_LATENCY_SLA_MS} ms (${primaryLabel})`,
    actual: `${primaryP95} ms`,
    passed: primaryP95 > 0 && primaryP95 <= FYP_LATENCY_SLA_MS,
  });

  checks.push({
    criterion: 'Stability & Error Rate',
    target: '< 1% errors & 0 unexpected disconnects',
    actual: `${errorRatePct}% errors (${totalErrors}), ${summary.counts.disconnects} unexpected disconnects`,
    passed: errorRatePct < 1 && summary.counts.disconnects === 0,
  });

  if (summary.counts.updatesSent > 0 || MODE === 'offline') {
    checks.push({
      criterion: 'CRDT Eventual Consistency (Proposal Page 11)',
      target: '100% identical final Yjs element state across all board peers',
      actual: summary.convergence.allConverged ? '100% converged (1 unique state hash/board)' : 'MISMATCH detected',
      passed: summary.convergence.allConverged,
    });
  }

  const overallPassed = checks.every(c => c.passed);

  // Plain-English takeaways
  const insights = [];
  if (primaryP95 > 0 && primaryP95 <= FYP_LATENCY_SLA_MS) {
    const headroom = (FYP_LATENCY_SLA_MS / Math.max(primaryP95, 0.1)).toFixed(1);
    insights.push(`**SLA Headroom:** Primary sync latency (${primaryLabel} = **${primaryP95} ms**) beat the FYP Proposal's 1,000 ms requirement by **${headroom}x**.`);
  } else if (primaryP95 > FYP_LATENCY_SLA_MS) {
    insights.push(`**SLA Breached (Breaking Point Reached):** ${primaryLabel} reached **${primaryP95} ms**, exceeding the 1,000 ms FYP threshold. This marks the server's practical saturation boundary for this workload.`);
  }

  if (summary.updateE2eMs.count > 0 && summary.updateE2eMs.p99 > summary.updateE2eMs.p50 * 4 && summary.updateE2eMs.p99 > 200) {
    insights.push(`**Tail-Latency Spike Detected:** \`crdt_update\` p99 (**${summary.updateE2eMs.p99} ms**) is >4x higher than p50 (**${summary.updateE2eMs.p50} ms**). Common causes: periodic 100-op \`runSnapshot()\` CPU stalls or Upstash/network jitter.`);
  }

  if (summary.serverTelemetry.hasDetailedMetrics) {
    const rssDelta = Number((summary.serverTelemetry.rssEndMB - summary.serverTelemetry.rssStartMB).toFixed(1));
    insights.push(`**Server Memory:** EC2 Node RSS went from **${summary.serverTelemetry.rssStartMB} MB** → **${summary.serverTelemetry.rssEndMB} MB** (peak **${summary.serverTelemetry.rssPeakMB} MB**, net change **${rssDelta >= 0 ? '+' : ''}${rssDelta} MB**).`);
    if (summary.serverTelemetry.peakLoopLagP95Ms > 50) {
      insights.push(`**Event-Loop Saturation Warning:** Peak Node event-loop lag p95 hit **${summary.serverTelemetry.peakLoopLagP95Ms} ms** (max **${summary.serverTelemetry.peakLoopLagMaxMs} ms**), confirming single-core CPU contention.`);
    } else {
      insights.push(`**Event-Loop Healthy:** Peak Node event-loop lag p95 stayed low at **${summary.serverTelemetry.peakLoopLagP95Ms} ms** (well under the 50 ms warning line).`);
    }
  } else {
    insights.push(`**Tip:** Deploy Fix 5 on \`GET /health\` to automatically record EC2 RAM and Node Event Loop Lag inside this report.`);
  }

  if (summary.counts.rateLimited > 0) {
    insights.push(`**Rate Limiter Triggered:** ${summary.counts.rateLimited} events hit the server's 120 events/sec/socket abuse guard.`);
  }

  return { overallPassed, errorRatePct, primaryP95, primaryLabel, checks, insights };
}

function csvEscape(val) {
  const s = String(val ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function buildMarkdownReport(summary, evaluation, timestampTag) {
  const statusBadge = evaluation.overallPassed ? '✅ PASS' : '❌ FAIL / LIMIT REACHED';
  const rows = [
    ['Socket.IO Connect', 'Time to complete TLS + WebSocket handshake + Firebase token verification', summary.connectMs],
    ['`watch_board` ACK', 'Time to verify board permission & join Socket.IO room', summary.watchMs],
    ['`crdt_preview` E2E', 'Sender → Server → Peer broadcast latency for live strokes (0 Redis cost)', summary.previewE2eMs],
    ['`crdt_update` ACK', 'Sender → Server → Redis Lua append → ACK latency for durable CRDT ops', summary.updateAckMs],
    ['`crdt_update` E2E', 'Sender → Server → Redis → Peer broadcast latency for durable CRDT ops', summary.updateE2eMs],
    ['`sync_offline` Catch-Up', 'Total time for a reconnecting offline user to fetch & apply missed ops', summary.syncOfflineMs],
  ];

  let md = `# InkLink Stress Test Report — \`${summary.label}\` (${statusBadge})\n\n`;
  md += `**Timestamp:** ${summary.timestamp}  \n`;
  md += `**Target Server:** \`${summary.targetUrl}\`  \n`;
  md += `**Mode:** \`${summary.mode}\` | **VUs:** ${summary.vus} | **Boards:** ${summary.boards} | **Elapsed:** ${summary.elapsedSec}s  \n`;
  if (summary.notes) md += `**Notes:** ${summary.notes}  \n`;
  md += `\n## 1. What This Test Simulated\n\n${summary.description}\n\n`;

  md += `## 2. FYP Proposal Pass/Fail Scorecard\n\n`;
  md += `| Criterion | Target | Observed Result | Status |\n`;
  md += `| :--- | :--- | :--- | :---: |\n`;
  for (const c of evaluation.checks) {
    md += `| **${c.criterion}** | ${c.target} | ${c.actual} | ${c.passed ? '✅ PASS' : '❌ FAIL'} |\n`;
  }

  md += `\n## 3. Latency Breakdown (milliseconds)\n\n`;
  md += `| Metric | What It Measures | Samples | Avg | p50 (Median) | p95 | p99 | Max |\n`;
  md += `| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: |\n`;
  for (const [name, desc, m] of rows) {
    if (m.count === 0) continue;
    md += `| ${name} | ${desc} | ${m.count.toLocaleString()} | ${m.avg} | ${m.p50} | **${m.p95}** | ${m.p99} | ${m.max} |\n`;
  }

  const dur = Math.max(summary.elapsedSec, 0.1);
  md += `\n## 4. Throughput, Reliability & Resource Impact\n\n`;
  md += `| Counter | Value | Rate / Notes |\n`;
  md += `| :--- | ---: | :--- |\n`;
  md += `| Live Previews Sent / Received | ${summary.counts.previewsSent.toLocaleString()} / ${summary.counts.previewsReceived.toLocaleString()} | ${(summary.counts.previewsReceived / dur).toFixed(1)} delivered frames/sec |\n`;
  md += `| Durable CRDT Updates Sent / Acked / Received | ${summary.counts.updatesSent.toLocaleString()} / ${summary.counts.updatesAcked.toLocaleString()} / ${summary.counts.updatesReceived.toLocaleString()} | ${(summary.counts.updatesAcked / dur).toFixed(1)} commits/sec |\n`;
  if (summary.counts.chatsSent > 0) {
    md += `| Board Chat Messages Sent / Received | ${summary.counts.chatsSent.toLocaleString()} / ${summary.counts.chatsReceived.toLocaleString()} | Redis 90-day chat log |\n`;
  }
  md += `| Connect Errors / ACK Errors / Rate-Limited | ${summary.counts.connectErrors} / ${summary.counts.ackErrors} / ${summary.counts.rateLimited} | Overall error rate: **${evaluation.errorRatePct}%** |\n`;
  md += `| Unexpected Socket Disconnects | ${summary.counts.disconnects} | Target: 0 |\n`;
  md += `| Estimated Upstash Redis Commands | ~${summary.counts.estUpstashCmds.toLocaleString()} | Budget check vs. 500K/mo Free Tier |\n`;

  if (summary.serverTelemetry.hasDetailedMetrics) {
    const t = summary.serverTelemetry;
    md += `\n## 5. EC2 Server Runtime Telemetry (Polled from \`/health\`)\n\n`;
    md += `| Metric | Start | Peak | End |\n`;
    md += `| :--- | ---: | ---: | ---: |\n`;
    md += `| Node.js RSS Memory (MB) | ${t.rssStartMB} | **${t.rssPeakMB}** | ${t.rssEndMB} |\n`;
    md += `| Node.js V8 Heap Used (MB) | ${t.heapStartMB} | **${t.heapPeakMB}** | ${t.heapEndMB} |\n`;
    md += `| Active WebSockets | — | **${t.peakActiveSockets}** | — |\n`;
    md += `| Node Event Loop Lag p95 / Max (ms) | — | **${t.peakLoopLagP95Ms} / ${t.peakLoopLagMaxMs}** | — |\n`;
  }

  if (Object.keys(summary.convergence.byBoard).length > 0 && (summary.counts.updatesSent > 0 || MODE === 'offline')) {
    md += `\n## 6. CRDT State Convergence Check\n\n`;
    md += `| Board ID | Connected Peers Checked | Elements | Unique State Hashes | Converged? |\n`;
    md += `| :--- | ---: | ---: | ---: | :---: |\n`;
    for (const [bId, info] of Object.entries(summary.convergence.byBoard)) {
      md += `| \`${bId}\` | ${info.clientsChecked} | ${info.elementsCount} | ${info.uniqueStateHashes} (\`${info.sampleHash}\`) | ${info.converged ? '✅ Yes' : '❌ No'} |\n`;
    }
  }

  md += `\n## 7. Key Takeaways & Interpretation\n\n`;
  for (const line of evaluation.insights) {
    md += `- ${line}\n`;
  }
  md += `\n---\n*Raw JSON saved as \`raw_${timestampTag}_${summary.label}.json\`*\n`;
  return md;
}

function updateMasterSummary(csvPath) {
  if (!fs.existsSync(csvPath)) return;
  const lines = fs.readFileSync(csvPath, 'utf8').trim().split('\n');
  if (lines.length < 2) return;

  // Simple CSV parser supporting quoted strings
  const parseLine = (line) => {
    const out = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
      else if (ch === '"') { inQuotes = !inQuotes; }
      else if (ch === ',' && !inQuotes) { out.push(cur); cur = ''; }
      else { cur += ch; }
    }
    out.push(cur);
    return out;
  };

  const rows = lines.slice(1).map(parseLine);
  let md = `# InkLink Stress Test Master Summary\n\n`;
  md += `Auto-updated after every run. Each row maps a specific test scenario directly to its observed latency, server resource usage, and FYP Proposal pass/fail verdict.\n\n`;
  md += `| # | Label | Mode | VUs (Boards) | Preview E2E p95 | Update E2E p50 / p95 / p99 | Offline Sync p95 | Errors / Disc. | Peak RAM / Loop Lag | Result | What Was Tested |\n`;
  md += `| :-: | :--- | :--- | :---: | ---: | :---: | ---: | :---: | :---: | :---: | :--- |\n`;

  rows.forEach((r, idx) => {
    const [
      , label, mode, vus, boards, , prevP95, , , updP50, updP95, updP99,
      syncP95, , errors, disc, , peakRss, peakLag, verdict, reportFile, desc,
    ] = r;
    const prevStr = Number(prevP95) > 0 ? `${prevP95} ms` : '—';
    const updStr = Number(updP95) > 0 ? `${updP50} / **${updP95}** / ${updP99} ms` : '—';
    const syncStr = Number(syncP95) > 0 ? `${syncP95} ms` : '—';
    const srvStr = Number(peakRss) > 0 ? `${peakRss} MB / ${peakLag} ms` : '—';
    const badge = verdict === 'PASS' ? '✅ PASS' : '❌ FAIL';
    md += `| ${idx + 1} | [\`${label}\`](./${reportFile}) | \`${mode}\` | ${vus} (${boards}) | ${prevStr} | ${updStr} | ${syncStr} | ${errors} / ${disc} | ${srvStr} | ${badge} | ${desc} |\n`;
  });

  fs.writeFileSync(path.join(REPORTS_DIR, 'MASTER_SUMMARY.md'), md);
}

// ---------------- MAIN EXECUTION ----------------
async function main() {
  fs.mkdirSync(REPORTS_DIR, { recursive: true });
  const description = describeTestScenario();

  console.log('\n============================================================');
  console.log(` InkLink Stress Test | label="${LABEL}" | mode="${MODE}"`);
  console.log('============================================================');
  console.log(`Target:   ${TARGET_URL}`);
  console.log(`Scenario: ${description}`);
  if (NOTES) console.log(`Notes:    ${NOTES}`);
  console.log('');

  // Start /health telemetry poller
  await pollHealthOnce();
  const healthTimer = setInterval(pollHealthOnce, 2000);

  // 1. Spawn VUs
  const vus = [];
  for (let i = 0; i < VUS; i++) {
    const boardId = EFFECTIVE_BOARDS[i % EFFECTIVE_BOARDS.length];
    vus.push(await createVU(i, boardId));
    if (RAMP_DELAY_MS > 0) await sleep(RAMP_DELAY_MS);
  }

  const connectedVus = vus.filter(v => v.connected);
  console.log(`Connected: ${connectedVus.length}/${VUS} (connect errors: ${metrics.connectErrors})`);
  if (!connectedVus.length) {
    clearInterval(healthTimer);
    console.error('No clients connected. Check TARGET_URL, FIREBASE_TOKENS, and BOARD_IDS.');
    process.exit(1);
  }

  // Allow server's async edit-permission cache warmup on watch_board to settle
  await sleep(500);
  const testStart = performance.now();

  if (MODE === 'offline') {
    const offlineCount = Math.max(1, Math.floor(connectedVus.length * 0.6));
    const offlineVus = connectedVus.slice(0, offlineCount);
    const onlineVus = connectedVus.slice(offlineCount);
    const savedVersions = offlineVus.map(v => v.getLastVersion());

    console.log(`Offline phase: disconnecting ${offlineVus.length} VUs; ${onlineVus.length} online VUs will commit ${OFFLINE_OPS} ops...`);
    for (const v of offlineVus) v.socket.disconnect();
    await sleep(400);

    for (let op = 0; op < OFFLINE_OPS; op++) {
      await sendCrdtUpdate(onlineVus[op % onlineVus.length], op);
      await sleep(25);
    }

    console.log(`Reconnecting ${offlineVus.length} VUs simultaneously (thundering herd)...`);
    const reconnected = await Promise.all(
      offlineVus.map(async (oldVu, idx) => {
        const fresh = await createVU(oldVu.index, oldVu.boardId, oldVu.doc);
        if (fresh.connected) {
          const ts = performance.now();
          let cursor = null;
          let sinceVersion = savedVersions[idx];
          let hasMore = true;
          let pages = 0;
          while (hasMore && pages < 50) {
            pages++;
            const resp = await new Promise(res =>
              fresh.socket.emit('sync_offline', { boardId: fresh.boardId, lastSeenCursor: cursor, sinceVersion }, res)
            );
            if (!resp || resp.status !== 'success') {
              metrics.ackErrors++;
              break;
            }
            if (resp.snapshot?.stateUpdate) {
              Y.applyUpdate(fresh.doc, Buffer.from(resp.snapshot.stateUpdate, 'base64'));
            }
            for (const u of (resp.updates || [])) {
              if (u.payloadBase64) Y.applyUpdate(fresh.doc, Buffer.from(u.payloadBase64, 'base64'));
            }
            cursor = resp.cursor;
            hasMore = Boolean(resp.hasMore);
          }
          metrics.syncOfflineMs.add(performance.now() - ts);
        }
        return fresh;
      }),
    );

    vus.splice(0, offlineCount, ...reconnected);
  } else {
    const activeCount = Math.max(1, Math.round(connectedVus.length * ACTIVE_RATIO));
    const activeVus = connectedVus.slice(0, activeCount);
    console.log(`Running active load (${activeVus.length}/${connectedVus.length} writers) for ${DURATION_SEC}s...`);

    const timers = [];
    for (const vu of activeVus) {
      let seq = 0;
      if (PREVIEW_HZ > 0) {
        timers.push(setInterval(() => sendPreview(vu), Math.max(10, Math.round(1000 / PREVIEW_HZ))));
      }
      if (UPDATE_HZ > 0) {
        timers.push(setInterval(() => { sendCrdtUpdate(vu, seq++); }, Math.max(50, Math.round(1000 / UPDATE_HZ))));
      }
      if (CHAT_EVERY_SEC > 0) {
        timers.push(setInterval(() => {
          if (!vu.connected) return;
          metrics.chatsSent++;
          vu.socket.emit('board_chat_message', {
            boardId: vu.boardId,
            text: `Stress chat from VU ${vu.index}`,
            senderName: `StressVU-${vu.index}`,
          });
        }, Math.round(CHAT_EVERY_SEC * 1000)));
      }
    }

    await sleep(DURATION_SEC * 1000);
    for (const t of timers) clearInterval(t);
  }

  // Drain final broadcasts & capture final /health snapshot
  await sleep(2000);
  await pollHealthOnce();
  clearInterval(healthTimer);

  const elapsedSec = Number(((performance.now() - testStart) / 1000).toFixed(1));
  const convergence = checkConvergence(vus);
  const estUpstashCmds = metrics.updatesSent * 7 + metrics.chatsSent * 2 + VUS * 3;

  const summary = {
    timestamp: new Date().toISOString(),
    label: LABEL,
    mode: MODE,
    notes: NOTES,
    description,
    targetUrl: TARGET_URL,
    vus: VUS,
    connected: connectedVus.length,
    boards: EFFECTIVE_BOARDS.length,
    elapsedSec,
    connectMs: metrics.connectMs.summarize(),
    watchMs: metrics.watchMs.summarize(),
    previewE2eMs: metrics.previewE2eMs.summarize(),
    updateAckMs: metrics.updateAckMs.summarize(),
    updateE2eMs: metrics.updateE2eMs.summarize(),
    syncOfflineMs: metrics.syncOfflineMs.summarize(),
    counts: {
      previewsSent: metrics.previewsSent,
      previewsReceived: metrics.previewsReceived,
      updatesSent: metrics.updatesSent,
      updatesAcked: metrics.updatesAcked,
      updatesReceived: metrics.updatesReceived,
      chatsSent: metrics.chatsSent,
      chatsReceived: metrics.chatsReceived,
      connectErrors: metrics.connectErrors,
      disconnects: metrics.disconnects,
      rateLimited: metrics.rateLimited,
      ackErrors: metrics.ackErrors,
      estUpstashCmds,
    },
    serverTelemetry,
    convergence,
  };

  const evaluation = evaluateResults(summary);
  const timestampTag = summary.timestamp.replace(/[:.]/g, '-').slice(0, 19);
  const reportFile = `REPORT_${timestampTag}_${LABEL}.md`;
  const jsonFile = `raw_${timestampTag}_${LABEL}.json`;
  const csvPath = path.join(REPORTS_DIR, 'all-runs-summary.csv');

  // Write individual Markdown report & Raw JSON
  fs.writeFileSync(path.join(REPORTS_DIR, reportFile), buildMarkdownReport(summary, evaluation, timestampTag));
  fs.writeFileSync(path.join(REPORTS_DIR, jsonFile), JSON.stringify({ summary, evaluation }, null, 2));

  // Append to cumulative CSV
  const csvHeader = [
    'timestamp', 'label', 'mode', 'vus', 'boards',
    'preview_p50_ms', 'preview_p95_ms', 'preview_p99_ms',
    'update_ack_p95_ms', 'update_e2e_p50_ms', 'update_e2e_p95_ms', 'update_e2e_p99_ms',
    'sync_offline_p95_ms', 'updates_sent', 'errors', 'disconnects', 'est_redis_cmds',
    'server_peak_rss_mb', 'server_peak_loop_lag_p95_ms', 'verdict', 'report_file', 'description',
  ].join(',') + '\n';
  if (!fs.existsSync(csvPath)) fs.writeFileSync(csvPath, csvHeader);

  const csvRow = [
    summary.timestamp, LABEL, MODE, VUS, EFFECTIVE_BOARDS.length,
    summary.previewE2eMs.p50, summary.previewE2eMs.p95, summary.previewE2eMs.p99,
    summary.updateAckMs.p95, summary.updateE2eMs.p50, summary.updateE2eMs.p95, summary.updateE2eMs.p99,
    summary.syncOfflineMs.p95, metrics.updatesSent,
    metrics.connectErrors + metrics.ackErrors, metrics.disconnects, estUpstashCmds,
    serverTelemetry.rssPeakMB, serverTelemetry.peakLoopLagP95Ms,
    evaluation.overallPassed ? 'PASS' : 'FAIL',
    reportFile,
    description,
  ].map(csvEscape).join(',') + '\n';
  fs.appendFileSync(csvPath, csvRow);

  // Rebuild MASTER_SUMMARY.md comparing all runs
  updateMasterSummary(csvPath);

  // Clean terminal printout
  console.log('\n==================== TEST SUMMARY ====================');
  console.log(`Verdict:      ${evaluation.overallPassed ? 'PASS' : 'FAIL / LIMIT REACHED'}`);
  console.log(`Primary SLA:  ${evaluation.primaryLabel} = ${evaluation.primaryP95} ms (Target <= ${FYP_LATENCY_SLA_MS} ms)`);
  if (summary.previewE2eMs.count) {
    console.log(`Preview E2E:  p50=${summary.previewE2eMs.p50}ms | p95=${summary.previewE2eMs.p95}ms | p99=${summary.previewE2eMs.p99}ms (${summary.counts.previewsReceived} delivered)`);
  }
  if (summary.updateE2eMs.count) {
    console.log(`Update E2E:   p50=${summary.updateE2eMs.p50}ms | p95=${summary.updateE2eMs.p95}ms | p99=${summary.updateE2eMs.p99}ms (${summary.counts.updatesAcked} committed)`);
  }
  if (summary.syncOfflineMs.count) {
    console.log(`Offline Sync: p50=${summary.syncOfflineMs.p50}ms | p95=${summary.syncOfflineMs.p95}ms | max=${summary.syncOfflineMs.max}ms`);
  }
  console.log(`Errors/Disc:  errors=${metrics.connectErrors + metrics.ackErrors} | disconnects=${metrics.disconnects} | estRedisCmds=~${estUpstashCmds}`);
  if (serverTelemetry.hasDetailedMetrics) {
    console.log(`EC2 Server:   Peak RSS=${serverTelemetry.rssPeakMB}MB | Peak Loop Lag p95=${serverTelemetry.peakLoopLagP95Ms}ms | Peak Sockets=${serverTelemetry.peakActiveSockets}`);
  }
  console.log('------------------------------------------------------');
  console.log(`Saved Report: ./reports/${reportFile}`);
  console.log(`Master Table: ./reports/MASTER_SUMMARY.md`);
  console.log(`Chart CSV:    ./reports/all-runs-summary.csv`);
  console.log('======================================================\n');

  for (const vu of vus) {
    try { vu.socket.disconnect(); } catch (_) {}
  }
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
