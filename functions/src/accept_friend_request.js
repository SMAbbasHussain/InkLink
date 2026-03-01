const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("../server/firebase-admin");

module.exports = async (request) => {
  const { data, auth } = request;
  if (!auth) throw new HttpsError('unauthenticated', 'User must be logged in.');

  const { requestId } = data;
  const firestore = admin.firestore();

  try {
    return await firestore.runTransaction(async (transaction) => {
      const requestRef = firestore.collection("friend_requests").doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) throw new HttpsError('not-found', 'Request not found.');

      const { fromUid, toUid } = requestDoc.data();
      if (auth.uid !== toUid) throw new HttpsError('permission-denied', 'Unauthorized.');

      // ONLY store the UID and a timestamp. 
      // The profile data stays in the /users collection.
      transaction.set(firestore.doc(`users/${toUid}/friends/${fromUid}`), {
        uid: fromUid,
        since: admin.firestore.FieldValue.serverTimestamp()
      });

      transaction.set(firestore.doc(`users/${fromUid}/friends/${toUid}`), {
        uid: toUid,
        since: admin.firestore.FieldValue.serverTimestamp()
      });

      transaction.delete(requestRef);
      return { success: true };
    });
  } catch (error) {
    throw new HttpsError('internal', error.message);
  }
};