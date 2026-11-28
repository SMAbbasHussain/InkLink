/**
 * InkLink Stress Test Safe Teardown
 *
 * Reads load-test/.stress-state.json, verifies each Firestore board has
 * `_isStressTest === true` before recursively deleting it, and optionally
 * deletes the 4 @inklink.test Firebase Auth users when --delete-users is set.
 *
 * Usage:
 *   node cleanup.js
 *   node cleanup.js --delete-users
 */

const fs = require('fs');
const { STATE_PATH, initFirebaseAdmin, loadState } = require('./setup-env');

const DELETE_USERS = process.argv.includes('--delete-users');

async function main() {
  const state = loadState();
  const { auth, db } = initFirebaseAdmin();

  console.log('\n============================================================');
  console.log(' InkLink Stress Environment Cleanup');
  console.log('============================================================');

  let deletedBoards = 0;
  let skippedBoards = 0;

  for (const boardId of (state.boardIds || [])) {
    const boardRef = db.collection('boards').doc(boardId);
    const snap = await boardRef.get();
    if (!snap.exists) {
      console.log(`  [board] ${boardId} — already deleted`);
      continue;
    }
    const data = snap.data() || {};
    if (data._isStressTest !== true) {
      console.warn(`  [board] SKIPPED ${boardId} — missing _isStressTest: true safety marker!`);
      skippedBoards++;
      continue;
    }
    await db.recursiveDelete(boardRef);
    deletedBoards++;
    console.log(`  [board] Deleted ${boardId} (recursive)`);
  }

  let deletedUsers = 0;
  if (DELETE_USERS) {
    for (const [role, user] of Object.entries(state.users || {})) {
      if (!user?.uid || !user?.email || !user.email.endsWith('@inklink.test')) {
        console.warn(`  [user]  SKIPPED ${role} (${user?.email || 'unknown'}) — not an @inklink.test account`);
        continue;
      }
      try {
        await auth.deleteUser(user.uid);
        deletedUsers++;
        console.log(`  [user]  Deleted ${role}: ${user.email} (${user.uid})`);
      } catch (err) {
        if (err.code === 'auth/user-not-found') {
          console.log(`  [user]  ${role}: ${user.email} — already deleted`);
        } else {
          console.warn(`  [user]  Failed deleting ${user.email}: ${err.message}`);
        }
      }
    }
  } else {
    console.log('  [users] Kept the 4 @inklink.test Auth accounts (pass --delete-users to remove them).');
  }

  if (DELETE_USERS && skippedBoards === 0 && fs.existsSync(STATE_PATH)) {
    fs.unlinkSync(STATE_PATH);
    console.log(`  [state] Removed ${STATE_PATH}`);
  }

  console.log('------------------------------------------------------------');
  console.log(` Summary: ${deletedBoards} board(s) deleted, ${skippedBoards} skipped, ${deletedUsers} user(s) deleted.`);
  console.log(' Note: Temporary Redis keys (board:stress_test_board_*, dedup,');
  console.log('       lastActivity) carry TTLs and auto-expire automatically,');
  console.log('       or can be flushed manually in Upstash if desired.');
  console.log('============================================================\n');
}

main().catch((err) => {
  console.error('\n[cleanup] FAILED:', err.message);
  process.exit(1);
});
