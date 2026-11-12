// server/src/history/profiles.js
// Cached uid -> { displayName, photoURL } resolver. Attribution is always
// stamped server-side (D9), so the archive worker needs the human-readable
// name without adding a Firestore read per stroke.
const admin = require('firebase-admin');

const cache = new Map(); // uid -> { displayName, photoURL, expiresAt }
const TTL_MS = 10 * 60 * 1000;

async function getProfile(uid) {
  if (!uid) return { displayName: 'InkLink User', photoURL: null };
  const hit = cache.get(uid);
  if (hit && hit.expiresAt > Date.now()) return hit;

  let displayName = 'InkLink User';
  let photoURL = null;
  try {
    const db = admin.firestore();
    const snap = await db.collection('users').doc(uid).get();
    if (snap.exists) {
      const d = snap.data() || {};
      displayName = d.displayName || displayName;
      photoURL = d.photoURL || null;
    }
  } catch (_) {
    /* fall back to defaults */
  }

  const entry = { displayName, photoURL, expiresAt: Date.now() + TTL_MS };
  cache.set(uid, entry);
  return entry;
}

module.exports = { getProfile };
