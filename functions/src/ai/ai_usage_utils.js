/**
 * Per-user daily limit for AI image requests.
 *
 * A slot is reserved in `ai_usage/{uid}_{YYYYMMDD}` (UTC day) BEFORE the
 * provider is called and refunded if the request fails, so only successful
 * generations count.
 *
 * Ends in `_utils.js` so functions/index.js does not export it.
 */

const { HttpsError } = require('firebase-functions/v2/https');

const AI_USAGE_COLLECTION = 'ai_usage';
const DEFAULT_DAILY_LIMIT = 20;

function getDailyLimit(env = process.env) {
  const parsed = Number.parseInt(env.AI_DAILY_LIMIT, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_DAILY_LIMIT;
}

function usageDocId(uid, now = new Date()) {
  const day = now.toISOString().slice(0, 10).replace(/-/g, '');
  return `${uid}_${day}`;
}

function readCount(snapshot) {
  const value = snapshot.exists ? snapshot.data()?.count : 0;
  return typeof value === 'number' && Number.isFinite(value) && value > 0
    ? Math.trunc(value)
    : 0;
}

async function reserveDailySlot(firestore, uid, { limit, now = new Date() } = {}) {
  const dailyLimit = limit || getDailyLimit();
  const docId = usageDocId(uid, now);
  const ref = firestore.collection(AI_USAGE_COLLECTION).doc(docId);

  const count = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = readCount(snapshot);
    if (current >= dailyLimit) {
      throw new HttpsError(
        'resource-exhausted',
        `You have reached today's limit of ${dailyLimit} AI images. Try again tomorrow.`,
      );
    }
    transaction.set(
      ref,
      { uid, day: docId.slice(uid.length + 1), count: current + 1, updatedAt: now },
      { merge: true },
    );
    return current + 1;
  });

  return { docId, count, limit: dailyLimit };
}

async function refundDailySlot(firestore, docId) {
  const ref = firestore.collection(AI_USAGE_COLLECTION).doc(docId);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = readCount(snapshot);
    if (current <= 0) return;
    transaction.set(ref, { count: current - 1, updatedAt: new Date() }, { merge: true });
  });
}

module.exports = {
  AI_USAGE_COLLECTION,
  DEFAULT_DAILY_LIMIT,
  getDailyLimit,
  usageDocId,
  reserveDailySlot,
  refundDailySlot,
};
