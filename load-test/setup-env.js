/**
 * InkLink Stress Test Environment Setup
 *
 * Creates/ensures 4 dedicated Firebase Auth test users and N private Firestore
 * test boards matching server/src/index.js schemas, mints fresh ID tokens, and
 * writes load-test/.stress-state.json (gitignored).
 *
 * Usage:
 *   node setup-env.js --boards=10
 *   FIREBASE_WEB_API_KEY=... node setup-env.js --boards=10
 */

const fs = require('fs');
const path = require('path');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const STATE_PATH = path.resolve(__dirname, '.stress-state.json');
const DEFAULT_SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '../server/service-account.json');
const ROOT_ENV_PATH = path.resolve(__dirname, '../.env');
const FIREBASE_OPTIONS_PATH = path.resolve(__dirname, '../lib/firebase_options.dart');

const TEST_USERS = {
  owner: { email: 'stress-owner@inklink.test', displayName: 'Stress Owner' },
  editor: { email: 'stress-editor@inklink.test', displayName: 'Stress Editor' },
  viewer: { email: 'stress-viewer@inklink.test', displayName: 'Stress Viewer' },
  outsider: { email: 'stress-outsider@inklink.test', displayName: 'Stress Outsider' },
};

function getArg(name, fallback) {
  const prefix = `--${name}=`;
  const hit = process.argv.find(a => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function parseDotEnv(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const result = {};
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const eqIdx = line.indexOf('=');
    if (eqIdx === -1) continue;
    const key = line.slice(0, eqIdx).trim();
    let val = line.slice(eqIdx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    result[key] = val;
  }
  return result;
}

function resolveFirebaseWebApiKey() {
  if (process.env.FIREBASE_WEB_API_KEY) return process.env.FIREBASE_WEB_API_KEY.trim();
  if (process.env.WEB_FIREBASE_KEY) return process.env.WEB_FIREBASE_KEY.trim();

  // InkLink's lib/firebase_options.dart loads WEB_FIREBASE_KEY from the root .env file.
  const rootEnv = parseDotEnv(ROOT_ENV_PATH);
  for (const key of ['WEB_FIREBASE_KEY', 'FIREBASE_WEB_API_KEY', 'ANDROID_FIREBASE_KEY']) {
    if (rootEnv[key] && rootEnv[key].startsWith('AIza')) {
      return rootEnv[key].trim();
    }
  }

  // Fallback: check lib/firebase_options.dart for a literal apiKey string.
  if (fs.existsSync(FIREBASE_OPTIONS_PATH)) {
    const dartSrc = fs.readFileSync(FIREBASE_OPTIONS_PATH, 'utf8');
    const match = dartSrc.match(/apiKey\s*:\s*['"](AIza[0-9A-Za-z_-]+)['"]/);
    if (match) return match[1];
  }

  throw new Error(
    'Could not locate Firebase Web API key. Set FIREBASE_WEB_API_KEY in your environment ' +
    'or ensure WEB_FIREBASE_KEY is defined in ../.env.',
  );
}

function initFirebaseAdmin() {
  if (getApps().length > 0) {
    return { auth: getAuth(), db: getFirestore() };
  }

  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    process.env.SERVICE_ACCOUNT_PATH ||
    DEFAULT_SERVICE_ACCOUNT_PATH;

  if (!fs.existsSync(credPath)) {
    throw new Error(
      `Firebase service account file not found at ${credPath}. ` +
      'Place service-account.json in ../server/ or set SERVICE_ACCOUNT_PATH.',
    );
  }

  const serviceAccount = JSON.parse(fs.readFileSync(credPath, 'utf8'));
  initializeApp({ credential: cert(serviceAccount) });
  return { auth: getAuth(), db: getFirestore() };
}

function loadState() {
  if (!fs.existsSync(STATE_PATH)) {
    throw new Error(
      `State file not found at ${STATE_PATH}. Run "node setup-env.js --boards=10" first.`,
    );
  }
  return JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'));
}

async function ensureUser(auth, { email, displayName }) {
  try {
    const existing = await auth.getUserByEmail(email);
    return { uid: existing.uid, email: existing.email, created: false };
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await auth.createUser({
      email,
      displayName,
      emailVerified: true,
    });
    return { uid: created.uid, email: created.email, created: true };
  }
}

async function exchangeCustomTokenForIdToken(customToken, apiKey) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  });

  const data = await res.json();
  if (!res.ok || !data.idToken) {
    const msg = data?.error?.message || `HTTP ${res.status}`;
    throw new Error(`signInWithCustomToken failed: ${msg}`);
  }
  return {
    idToken: data.idToken,
    expiresIn: Number(data.expiresIn || 3600),
  };
}

/**
 * Mints fresh 1-hour Firebase ID tokens for the requested roles (defaults to all 4).
 * Reusable by run-suite.js and security-test.js to avoid token expiration.
 */
async function mintFreshTokens(state, roles = ['owner', 'editor', 'viewer', 'outsider']) {
  const { auth } = initFirebaseAdmin();
  const apiKey = state?.apiKey || resolveFirebaseWebApiKey();
  const tokens = {};

  for (const role of roles) {
    const user = state?.users?.[role];
    if (!user || !user.uid) {
      throw new Error(`Missing user "${role}" in .stress-state.json`);
    }
    const customToken = await auth.createCustomToken(user.uid);
    const exchanged = await exchangeCustomTokenForIdToken(customToken, apiKey);
    tokens[role] = exchanged.idToken;
  }

  return tokens;
}

async function main() {
  const boardCount = Math.max(1, parseInt(getArg('boards', '10'), 10));
  const apiKey = resolveFirebaseWebApiKey();
  const { auth, db } = initFirebaseAdmin();

  console.log('\n============================================================');
  console.log(` InkLink Stress Environment Setup (${boardCount} boards)`);
  console.log('============================================================');

  // 1. Ensure 4 dedicated test users
  const users = {};
  for (const [role, spec] of Object.entries(TEST_USERS)) {
    const u = await ensureUser(auth, spec);
    users[role] = { uid: u.uid, email: u.email };
    console.log(`  [user] ${role.padEnd(8)} : ${u.email} (${u.uid}) ${u.created ? '[CREATED]' : '[existing]'}`);
  }

  // 2. Ensure N private test boards matching server/src/index.js Firestore schema
  const boardIds = [];
  for (let i = 1; i <= boardCount; i++) {
    const boardId = `stress_test_board_${i}`;
    boardIds.push(boardId);

    const boardRef = db.collection('boards').doc(boardId);
    const members = i === 1
      ? [users.owner.uid, users.editor.uid, users.viewer.uid]
      : [users.owner.uid, users.editor.uid];

    const batch = db.batch();
    batch.set(boardRef, {
      title: `Stress Test Board ${i}`,
      ownerId: users.owner.uid,
      visibility: 'private',
      isPaused: false,
      members,
      _isStressTest: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    batch.set(boardRef.collection('members').doc(users.owner.uid), {
      role: 'owner',
      email: users.owner.email,
      displayName: TEST_USERS.owner.displayName,
      _isStressTest: true,
    }, { merge: true });

    batch.set(boardRef.collection('members').doc(users.editor.uid), {
      role: 'editor',
      email: users.editor.email,
      displayName: TEST_USERS.editor.displayName,
      _isStressTest: true,
    }, { merge: true });

    if (i === 1) {
      batch.set(boardRef.collection('members').doc(users.viewer.uid), {
        role: 'viewer',
        email: users.viewer.email,
        displayName: TEST_USERS.viewer.displayName,
        _isStressTest: true,
      }, { merge: true });
    }

    await batch.commit();
  }
  console.log(`  [boards] Provisioned ${boardIds.length} private test boards (${boardIds[0]} .. ${boardIds[boardIds.length - 1]})`);

  // 3. Verify token minting works for all 4 test users
  const state = {
    apiKey,
    createdAt: new Date().toISOString(),
    users,
    boardIds,
  };
  const freshTokens = await mintFreshTokens(state);
  console.log(`  [tokens] Verified fresh 1h ID token minting for ${Object.keys(freshTokens).length}/4 users`);

  // 4. Persist gitignored state file (tokens are minted fresh on demand by runners)
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
  console.log(`  [state]  Saved to ${STATE_PATH}`);
  console.log('============================================================\n');
}

module.exports = {
  STATE_PATH,
  TEST_USERS,
  initFirebaseAdmin,
  loadState,
  resolveFirebaseWebApiKey,
  mintFreshTokens,
};

if (require.main === module) {
  main().catch((err) => {
    console.error('\n[setup-env] FAILED:', err.message);
    process.exit(1);
  });
}
