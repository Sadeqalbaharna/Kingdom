/**
 * Usage: node set_staff.js <USER_UID> [role]
 * Example: node set_staff.js 0YzqiEbNYGfIJJtHDRXxxmkeZb12 staff
 *
 * This script uses the Admin SDK and Application Default Credentials.
 * Ensure GOOGLE_APPLICATION_CREDENTIALS is set to a service account JSON
 * with Firestore permissions, or run this from an environment where
 * the gcloud SDK is authenticated (gcloud auth application-default login).
 */
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function main() {
  const uid = process.argv[2];
  const role = process.argv[3] || 'staff';
  if (!uid) {
    console.error('Usage: node set_staff.js <USER_UID> [role]');
    process.exit(2);
  }

  const ref = db.collection('users').doc(uid);
  try {
    await ref.set({ role: role, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    console.log(`Set users/${uid}.role = '${role}'`);
  } catch (err) {
    console.error('Failed to set role:', err);
    process.exit(1);
  }
}

main();
#!/usr/bin/env node
const admin = require('firebase-admin');
const path = require('path');

// The service-account JSON path can be provided either via the environment variable
// GOOGLE_APPLICATION_CREDENTIALS or as the optional third CLI argument.
let keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
// argv: [node, script, <UID>, [action], [serviceAccountPath]]
const cliPath = process.argv[4];
if (cliPath) {
  keyPath = cliPath;
}
if (!keyPath) {
  console.error('ERROR: Provide a service-account JSON path either via env var GOOGLE_APPLICATION_CREDENTIALS or as the third argument.');
  console.error('Example (PowerShell):');
  console.error("$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\\path\\to\\service-account.json' ; node .\\set_staff.js <UID> set");
  console.error("Or: node .\\set_staff.js <UID> set C:\\path\\to\\service-account.json");
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = require(path.resolve(keyPath));
} catch (e) {
  console.error('ERROR: Failed to load service account JSON from', keyPath);
  console.error(e.message || e);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
const action = (process.argv[3] || 'set').toLowerCase(); // 'set' or 'remove'

if (!uid) {
  console.error('Usage: node set_staff.js <UID> [set|remove]');
  process.exit(1);
}

(async () => {
  try {
    if (action === 'remove') {
      await admin.auth().setCustomUserClaims(uid, null);
      console.log(`Removed custom claims for ${uid}`);
    } else {
      await admin.auth().setCustomUserClaims(uid, { staff: true });
      console.log(`Set custom claim { staff: true } for ${uid}`);
    }
    console.log('Done. Note: the user will need to sign out and sign back in to refresh their ID token.');
    process.exit(0);
  } catch (err) {
    console.error('Error setting custom claim:', err);
    process.exit(2);
  }
})();
