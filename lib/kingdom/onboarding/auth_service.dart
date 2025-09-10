import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  Future<String?> getFaction() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    return data != null ? data['faction'] as String? : null;
  }
  /// Save unlocked tiles and points info for the current user (per underlay)
  Future<void> saveUnlockedTiles(
    Map<int, Set<String>> unlockedTilesByUnderlay, {
    int? totalPointsObtained,
    int? totalPointsUsed,
    int? totalPointsRemaining,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    // Convert Set<String> to List<String> for Firestore
    final data = <String, List<String>>{};
    unlockedTilesByUnderlay.forEach((k, v) {
      data[k.toString()] = v.toList();
    });
    final pointsData = <String, dynamic>{
      'unlockedTiles': data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (totalPointsObtained != null) pointsData['totalPointsObtained'] = totalPointsObtained;
    if (totalPointsUsed != null) pointsData['totalPointsUsed'] = totalPointsUsed;
    if (totalPointsRemaining != null) pointsData['totalPointsRemaining'] = totalPointsRemaining;
    await _db.collection('users').doc(user.uid).set(pointsData, SetOptions(merge: true));
  }

  /// Load unlocked tiles for the current user (per underlay)
  Future<Map<int, Set<String>>> loadUnlockedTiles() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    final result = <int, Set<String>>{};
    if (data != null && data['unlockedTiles'] is Map) {
      final tilesMap = data['unlockedTiles'] as Map;
      tilesMap.forEach((k, v) {
        if (v is List) {
          result[int.tryParse(k.toString()) ?? 0] = Set<String>.from(v);
        }
      });
    }
    return result;
  }
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureUserDoc(cred.user);
    return cred;
  }
  // Region used for Cloud Functions. Can be overridden at build time with:
  // flutter build --dart-define=FIREBASE_FUNCTIONS_REGION=us-central1
  static const String _functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Use a region-specific Functions instance so deploy region mismatches are explicit.
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: _functionsRegion,
  );

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle({bool silent = false}) async {
    GoogleSignInAccount? googleUser;
    if (silent) {
      googleUser = await GoogleSignIn().signInSilently();
    } else {
      googleUser = await GoogleSignIn().signIn();
    }
    if (googleUser == null) {
      throw Exception('Sign-in aborted');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(cred.user);
    return cred;
  }

  Future<void> linkEmailPassword({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final email = user.email;
    if (email == null) throw Exception('Google account has no email');
    final emailCred = EmailAuthProvider.credential(email: email, password: password);
    await user.linkWithCredential(emailCred);
  }

  Future<void> setUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    await user.updateDisplayName(username);
    await _db.collection('users').doc(user.uid).set({
      'username': username,
      'name': username,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Save selected portrait asset path (or identifier) to the user document.
  Future<void> setPortrait(String portraitAsset) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    await _db.collection('users').doc(user.uid).set({
      'portrait': portraitAsset,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setFaction(String faction) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    await _db.collection('users').doc(user.uid).set({
      'faction': faction,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Atomically increment claim count for a tile for [faction].
  /// Uses a top-level `tile_claims` collection where each doc id is '<underlay>_<q,r>'.
  Future<void> claimTile(int underlay, String tileKey, String faction) async {
    final id = '${underlay}_$tileKey';
    final ref = _db.collection('tile_claims').doc(id);
    // Use FieldValue.increment for atomic increments; set with merge ensures doc exists.
    await ref.set({
      'counts': {faction.trim().toLowerCase(): FieldValue.increment(1)}
    }, SetOptions(merge: true));
  }

  /// Atomically decrement claim count for a tile for [faction], but not below zero.
  Future<void> unclaimTile(int underlay, String tileKey, String faction) async {
    final id = '${underlay}_$tileKey';
    final ref = _db.collection('tile_claims').doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      final counts = <String, int>{};
      if (data != null && data['counts'] is Map) {
        (data['counts'] as Map).forEach((k, v) {
          counts[k.toString()] = (v is num) ? v.toInt() : 0;
        });
      }
      final f = faction.trim().toLowerCase();
      final current = counts[f] ?? 0;
      final toSet = (current <= 1) ? 0 : current - 1;
      tx.set(ref, {'counts': {f: toSet}}, SetOptions(merge: true));
    });
  }

  /// Read per-faction counts for a given tile (underlay + tileKey).
  Future<Map<String, int>> getTileCounts(int underlay, String tileKey) async {
    final id = '${underlay}_$tileKey';
    final ref = _db.collection('tile_claims').doc(id);
    final snap = await ref.get();
    final data = snap.data();
    final result = <String, int>{};
    if (data != null && data['counts'] is Map) {
      (data['counts'] as Map).forEach((k, v) {
        result[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }
    return result;
  }

  /// Aggregate counts for all tiles belonging to a given underlay (map index).
  /// Returns a map where each key is a faction (lowercased) and the value is the
  /// number of tiles on that underlay where that faction has a non-zero count.
  /// The special key 'total' contains the number of tiles on that underlay that
  /// are claimed by at least one faction.
  Future<Map<String, int>> getUnderlayCounts(int underlay) async {
    final col = _db.collection('tile_claims');
    final snap = await col.get();
    final Map<String, int> agg = {};
  // Sum raw claim counts for each faction across all tiles in this underlay.
    // This returns how many "claims" (points spent) each faction has on the map.
    // The special key 'total' will be the sum of all claim counts across factions.
    int totalClaims = 0;
    for (final doc in snap.docs) {
      final id = doc.id; // format is '<underlay>_<q,r>'
      if (!id.startsWith('${underlay}_')) continue;
      final data = doc.data();
      if (data['counts'] is! Map) continue;
      (data['counts'] as Map).forEach((k, v) {
        final fk = k.toString().trim().toLowerCase();
        final val = (v is num) ? v.toInt() : 0;
        if (val <= 0) return;
        agg[fk] = (agg[fk] ?? 0) + val;
        totalClaims += val;
      });
    }
    agg['total'] = totalClaims;
    return agg;
  }

  /// Request granting points to a target user UID. This calls a backend Cloud Function
  /// 'grantPoints' which must perform authentication and validation. The function
  /// should accept { targetUid: string, points: int, issuerUid: string }
  /// and return { success: bool, message?: string }.
  /// Request granting points to a target user UID.
  ///
  /// This will call the callable Cloud Function named `grantPoints` in
  /// the region configured by [_functionsRegion]. If the callable is not
  /// found and the app is running in debug mode, a local Firestore-based
  /// fallback will apply the points to `users/{targetUid}` and write a
  /// debug grant record under `debug_grants` so development/testing can proceed
  /// without a deployed function. In production the callable should exist.
  Future<Map<String, dynamic>> requestGrantPoints(String targetUid, int points, {bool allowDebugFallback = false}) async {
    // Ensure we have a fresh ID token and user before calling the callable.
    final caller = _auth.currentUser;
    if (caller == null) throw Exception('Not authenticated');
    // Force token refresh to avoid expired-token UNAUTHENTICATED errors.
    try {
      await caller.getIdToken(true);
    } catch (_) {
      // If token refresh fails, sign the user out to force a fresh sign-in flow.
      // Caller code should handle sign-in. We throw a clear exception for UI.
      throw Exception('Failed to refresh auth token. Please sign in again.');
    }

    try {
      // Debug: print the fresh ID token claims so we can verify the client is sending
      // a valid token and whether custom claims (staff) are present.
      try {
        final idTokenRes = await caller.getIdTokenResult(true);
        debugPrint('requestGrantPoints: caller=${caller.uid} idTokenClaims=${idTokenRes.claims}');
      } catch (e) {
        debugPrint('requestGrantPoints: failed to read idTokenResult: $e');
      }

      final callable = _functions.httpsCallable('grantPoints');
      final res = await callable.call(<String, dynamic>{
        'targetUid': targetUid,
        'points': points,
        'issuerUid': caller.uid,
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      // Map unauthenticated errors to a clear, local exception for the UI.
      if (e.code == 'unauthenticated') {
        throw Exception('Grant error: unauthenticated — ensure the staff device is signed in');
      }
      // Surface the callable error (message and code) to the caller so the UI
      // can display it. We don't perform any client-side simulation here —
      // production must use the deployed Cloud Function.
      throw Exception('Grant failed: ${e.message} (code=${e.code})');
    }
  }

  /// Debug helper: call the grantPoints callable with a known test UID.
  /// Use this during development (hook to a button) to exercise the callable
  /// and quickly capture client-side errors in the browser/console.
  Future<void> testGrant({String targetUid = '0YzqiEbNYGfIJJtHDRXxxmkeZb12', int points = 10}) async {
    try {
      final res = await requestGrantPoints(targetUid, points, allowDebugFallback: true);
      debugPrint('testGrant: success -> $res');
    } catch (e, st) {
      debugPrint('testGrant: error -> $e\n$st');
      rethrow;
    }
  }
}
