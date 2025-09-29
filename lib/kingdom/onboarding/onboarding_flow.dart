// import 'dart:html' as html; // Removed for cross-platform compatibility
import '../../main.dart' show forceAppRebuild;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'screens/google_sign_in_screen.dart';
import 'screens/username_screen.dart';
import 'screens/faction_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (context) => _Entry(auth: _auth));
      },
    );
  }
}

class _Entry extends StatefulWidget {
  final AuthService auth;
  const _Entry({required this.auth});

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  Future<void> _continueAfterSignIn(BuildContext context) async {
    // Capture navigator before any async gaps to satisfy lints.
    final navigator = Navigator.of(context);
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Ensure providerData is fresh (especially on web) before deciding which steps to show.
    try {
      await user.reload();
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (_) {}
  user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Determine if email/password is already linked. If you signed in using
  // email+password, this will already be present and we can skip the step.
  // Password step removed: email/password users are fully handled by the sign-in action itself.

    // Fetch profile data once to check username/faction
    Map<String, dynamic> data = {};
    try {
  final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      data = snap.data() ?? {};
    } catch (_) {
      data = {};
    }

  final hasUsername = (user.displayName != null && user.displayName!.trim().isNotEmpty) ||
    (data['username'] is String && (data['username'] as String).trim().isNotEmpty) ||
    (data['name'] is String && (data['name'] as String).trim().isNotEmpty);
    final hasFaction = data['faction'] is String && (data['faction'] as String).trim().isNotEmpty;

    Future<void> goToApp() async {
      if (!mounted) return;
      navigator.popUntil((r) => r.isFirst);
      await Future.delayed(const Duration(milliseconds: 100));
      forceAppRebuild();
    }

    if (hasUsername && hasFaction) {
      await goToApp();
      return;
    }

    // Push only missing steps in order; each step returns to continue the sequence
    if (!hasUsername) {
      if (!mounted) return;
      await navigator.push(MaterialPageRoute(
        builder: (_) => UsernameScreen(onComplete: () {}),
      ));
    }

    if (!hasFaction) {
      if (!mounted) return;
      await navigator.push(MaterialPageRoute(
        builder: (_) => FactionScreen(onComplete: () {}),
      ));
    }

    await goToApp();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleSignInScreen(
      onSignedIn: () async {
        await _continueAfterSignIn(context);
      },
    );
  }
}
