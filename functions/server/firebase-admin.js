const admin = require('firebase-admin');
const firestoreModule = require('firebase-admin/firestore');
const authModule = require('firebase-admin/auth');
const messagingModule = require('firebase-admin/messaging');

if (admin.getApps().length === 0) {
  admin.initializeApp();
}

// firebase-admin v14 removed the namespaced service getters. Keep the local
// facade used by the function modules so they can keep calling
// admin.firestore()/auth()/messaging() while the SDK migrates to the modular API.
function firestore(app) {
  return firestoreModule.getFirestore(app);
}
Object.assign(firestore, firestoreModule);

function auth(app) {
  return authModule.getAuth(app);
}
Object.assign(auth, authModule);

function messaging(app) {
  return messagingModule.getMessaging(app);
}
Object.assign(messaging, messagingModule);

module.exports = {
  ...admin,
  get apps() {
    return admin.getApps();
  },
  credential: {
    applicationDefault: admin.applicationDefault,
    cert: admin.cert,
    refreshToken: admin.refreshToken,
  },
  firestore,
  auth,
  messaging,
};
