const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
// Function region can be set via environment variable FUNCTIONS_REGION or default to 'us-central1'
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || process.env.GCLOUD_PROJECT_REGION || 'us-central1';

/**
 * Callable function to grant points to a target user.
 * Expects data: { targetUid: string, points: number, issuerUid?: string }
 * Security: verifies caller is authenticated and has role 'staff' or 'admin'.
 */
exports.grantPoints = functions.region(FUNCTIONS_REGION).https.onCall(async (data, context) => {
  console.log('grantPoints invoked. context.auth=', JSON.stringify(context.auth), 'data=', JSON.stringify(data));
  if (!context.auth) {
    console.warn('grantPoints: unauthenticated call — context.auth is null');
    throw new functions.https.HttpsError('unauthenticated', 'Caller must be authenticated.');
  }

  const issuerUid = context.auth.uid;
  const targetUid = data.targetUid;
  const points = Number(data.points || 0);

  if (!targetUid || typeof targetUid !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid targetUid');
  }
  if (!Number.isInteger(points) || points <= 0 || points > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid points value');
  }

  // Check issuer role
  const issuerDoc = await db.collection('users').doc(issuerUid).get();
  const issuerData = issuerDoc.exists ? issuerDoc.data() : null;
  console.log('grantPoints: issuerDoc.exists=', issuerDoc.exists, 'issuerData=', JSON.stringify(issuerData));
  const role = issuerData && issuerData.role ? issuerData.role : null;
  console.log('grantPoints: computed role=', role);
  if (!role || (role !== 'staff' && role !== 'admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Caller not authorized to grant points');
  }

  const targetRef = db.collection('users').doc(targetUid);

  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(targetRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'Target user not found');
      }
      // Increment the simple `points` field used by the UI and update totals
      // so UI fields like `totalPointsObtained` and `totalPointsRemaining` stay in sync.
      tx.set(
        targetRef,
        {
          points: admin.firestore.FieldValue.increment(points),
          totalPointsObtained: admin.firestore.FieldValue.increment(points),
          totalPointsRemaining: admin.firestore.FieldValue.increment(points),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      // audit log
      const auditRef = db.collection('grant_audit').doc();
      tx.set(auditRef, {
        issuer: issuerUid,
        target: targetUid,
        points: points,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    console.log(`grantPoints: issuer=${issuerUid} target=${targetUid} points=${points} region=${FUNCTIONS_REGION}`);
    return { success: true };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    console.error('grantPoints error', e);
    throw new functions.https.HttpsError('internal', 'Grant failed');
  }
});

// HTTP version of the grantPoints function which accepts an Authorization
// Bearer token. This is provided as a fallback for web clients that may hit
// CORS preflight issues with callable endpoints in some environments.
const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors({ origin: true })); // allow all origins; tighten for production
app.use(express.json());

app.post('/', async (req, res) => {
  try {
    const authHeader = req.headers.authorization || '';
    const match = authHeader.match(/^Bearer (.+)$/);
    if (!match) return res.status(401).json({ error: 'missing-auth' });
    const idToken = match[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    if (!decoded || !decoded.uid) return res.status(401).json({ error: 'invalid-token' });
    const issuerUid = decoded.uid;
    const { targetUid, points } = req.body || {};
    const pts = Number(points || 0);
    if (!targetUid || typeof targetUid !== 'string') return res.status(400).json({ error: 'invalid-target' });
    if (!Number.isInteger(pts) || pts <= 0 || pts > 1000) return res.status(400).json({ error: 'invalid-points' });

    const issuerDoc = await db.collection('users').doc(issuerUid).get();
    const issuerData = issuerDoc.exists ? issuerDoc.data() : null;
    const role = issuerData && issuerData.role ? issuerData.role : null;
    if (!role || (role !== 'staff' && role !== 'admin')) {
      return res.status(403).json({ error: 'not-authorized' });
    }

    const targetRef = db.collection('users').doc(targetUid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(targetRef);
      if (!snap.exists) {
        throw new Error('target-not-found');
      }
      tx.set(targetRef, {
        points: admin.firestore.FieldValue.increment(pts),
        totalPointsObtained: admin.firestore.FieldValue.increment(pts),
        totalPointsRemaining: admin.firestore.FieldValue.increment(pts),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      const auditRef = db.collection('grant_audit').doc();
      tx.set(auditRef, {
        issuer: issuerUid,
        target: targetUid,
        points: pts,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return res.json({ success: true });
  } catch (err) {
    console.error('grantPointsHttp error', err);
    return res.status(500).json({ error: 'internal', message: err.message || String(err) });
  }
});

exports.grantPointsHttp = functions.region(FUNCTIONS_REGION).https.onRequest(app);
