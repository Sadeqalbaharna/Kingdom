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

/**
 * Callable function for staff to claim points for a student using an explicit claimId.
 * Input: { claimId: string, studentUid: string, points: number, targetId?: string }
 * Ensures idempotency by using `grant_audit/{claimId}` as the canonical guard.
 */
exports.claimPointByTeacher = functions.region(FUNCTIONS_REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Caller must be authenticated.');
  }

  const issuerUid = context.auth.uid;
  const claimId = data && data.claimId;
  const studentUid = data && data.studentUid;
  const points = Number(data && data.points || 0);
  const targetId = data && data.targetId ? data.targetId : null;

  if (!claimId || typeof claimId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid claimId');
  }
  if (!studentUid || typeof studentUid !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid studentUid');
  }
  if (!Number.isInteger(points) || points <= 0 || points > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid points value');
  }

  // Try to read role from token first (faster). Fall back to users/{uid} if absent.
  let role = null;
  try {
    role = context.auth.token && context.auth.token.role ? context.auth.token.role : null;
  } catch (e) {
    role = null;
  }
  if (!role) {
    const issuerDoc = await db.collection('users').doc(issuerUid).get();
    const issuerData = issuerDoc.exists ? issuerDoc.data() : null;
    role = issuerData && issuerData.role ? issuerData.role : null;
  }
  if (!role || (role !== 'staff' && role !== 'admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Caller not authorized to grant points');
  }

  const auditRef = db.collection('grant_audit').doc(claimId);
  const userRef = db.collection('users').doc(studentUid);

  let alreadyProcessed = false;
  let resultingPoints = null;
  let resultingTotalObtained = null;
  let resultingTotalRemaining = null;

  try {
    await db.runTransaction(async (tx) => {
      const auditSnap = await tx.get(auditRef);
      if (auditSnap.exists) {
        // Already processed: read current points and return
        const userSnap2 = await tx.get(userRef);
        resultingPoints = (userSnap2.exists && userSnap2.data() && typeof userSnap2.data().points === 'number') ? userSnap2.data().points : 0;
        alreadyProcessed = true;
        return;
      }
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Target user not found');
      }

  const userData = userSnap.data() || {};
  const currentPoints = (typeof userData.points === 'number') ? userData.points : 0;
  const currentTotalObtained = (typeof userData.totalPointsObtained === 'number') ? userData.totalPointsObtained : 0;
  const currentTotalRemaining = (typeof userData.totalPointsRemaining === 'number') ? userData.totalPointsRemaining : 0;
  const newPoints = currentPoints + points;
  const newTotalObtained = currentTotalObtained + points;
  const newTotalRemaining = currentTotalRemaining + points;

      // Create canonical audit record (idempotency key)
      tx.set(auditRef, {
        issuer: issuerUid,
        target: studentUid,
        points: points,
        targetId: targetId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update user points atomically
      tx.set(userRef, {
        points: admin.firestore.FieldValue.increment(points),
        totalPointsObtained: admin.firestore.FieldValue.increment(points),
        totalPointsRemaining: admin.firestore.FieldValue.increment(points),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      resultingPoints = newPoints;
      // store totals for response
      // Note: we compute them locally here based on current values rather than reading again
      resultingTotalObtained = newTotalObtained;
      resultingTotalRemaining = newTotalRemaining;
    });

    return { success: true, alreadyProcessed: alreadyProcessed, auditId: claimId, newPoints: resultingPoints, totalPointsObtained: resultingTotalObtained, totalPointsRemaining: resultingTotalRemaining };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    console.error('claimPointByTeacher error', e && e.stack ? e.stack : e);
    throw new functions.https.HttpsError('internal', 'Claim failed');
  }
});

// HTTP CORS-enabled version of claimPointByTeacher for web clients that may
// encounter callable-related CORS/preflight issues. Accepts Authorization: Bearer <idToken>
const claimApp = express();
claimApp.use(cors({ origin: true }));
claimApp.use(express.json());

claimApp.post('/', async (req, res) => {
  try {
    const authHeader = req.headers.authorization || '';
    const match = authHeader.match(/^Bearer (.+)$/);
    if (!match) return res.status(401).json({ error: 'missing-auth' });
    const idToken = match[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    if (!decoded || !decoded.uid) return res.status(401).json({ error: 'invalid-token' });
    const issuerUid = decoded.uid;

    const { claimId, studentUid, points, targetId } = req.body || {};
    const pts = Number(points || 0);
    if (!claimId || typeof claimId !== 'string') return res.status(400).json({ error: 'invalid-claimId' });
    if (!studentUid || typeof studentUid !== 'string') return res.status(400).json({ error: 'invalid-student' });
    if (!Number.isInteger(pts) || pts <= 0 || pts > 1000) return res.status(400).json({ error: 'invalid-points' });

    const issuerDoc = await db.collection('users').doc(issuerUid).get();
    const issuerData = issuerDoc.exists ? issuerDoc.data() : null;
    const role = issuerData && issuerData.role ? issuerData.role : null;
    if (!role || (role !== 'staff' && role !== 'admin')) {
      return res.status(403).json({ error: 'not-authorized' });
    }

    const auditRef = db.collection('grant_audit').doc(claimId);
    const userRef = db.collection('users').doc(studentUid);

    let alreadyProcessed = false;
    let resultingPoints = null;
    let resultingTotalObtained = null;
    let resultingTotalRemaining = null;

    await db.runTransaction(async (tx) => {
      const auditSnap = await tx.get(auditRef);
      if (auditSnap.exists) {
        const userSnap2 = await tx.get(userRef);
        resultingPoints = (userSnap2.exists && userSnap2.data() && typeof userSnap2.data().points === 'number') ? userSnap2.data().points : 0;
        alreadyProcessed = true;
        return;
      }
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new Error('target-not-found');
      }

      const userData = userSnap.data() || {};
      const currentPoints = (typeof userData.points === 'number') ? userData.points : 0;
      const currentTotalObtained = (typeof userData.totalPointsObtained === 'number') ? userData.totalPointsObtained : 0;
      const currentTotalRemaining = (typeof userData.totalPointsRemaining === 'number') ? userData.totalPointsRemaining : 0;
      const newPoints = currentPoints + pts;
      const newTotalObtained = currentTotalObtained + pts;
      const newTotalRemaining = currentTotalRemaining + pts;

      tx.set(auditRef, {
        issuer: issuerUid,
        target: studentUid,
        points: pts,
        targetId: targetId || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        points: admin.firestore.FieldValue.increment(pts),
        totalPointsObtained: admin.firestore.FieldValue.increment(pts),
        totalPointsRemaining: admin.firestore.FieldValue.increment(pts),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      resultingPoints = newPoints;
      resultingTotalObtained = newTotalObtained;
      resultingTotalRemaining = newTotalRemaining;
    });

    return res.json({ success: true, alreadyProcessed: alreadyProcessed, auditId: claimId, newPoints: resultingPoints, totalPointsObtained: resultingTotalObtained, totalPointsRemaining: resultingTotalRemaining });
  } catch (err) {
    console.error('claimPointByTeacherHttp error', err);
    return res.status(500).json({ error: 'internal', message: err.message || String(err) });
  }
});

exports.claimPointByTeacherHttp = functions.region(FUNCTIONS_REGION).https.onRequest(claimApp);
