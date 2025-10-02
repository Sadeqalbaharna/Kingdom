// import 'dart:html' as html; // Removed for cross-platform compatibility
import '../../main.dart' show forceAppRebuild;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'screens/google_sign_in_screen.dart';
import 'screens/username_screen.dart';
import 'screens/faction_screen.dart';
import 'screens/password_screen.dart';

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
  @override
  void initState() {
    super.initState();
    // If we're already signed in (common after the first attempt on web),
    // auto-continue after the first frame so the user doesn't have to tap again.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        await _continueAfterSignIn(context);
      }
    });
  }
  Future<void> _continueAfterSignIn(BuildContext context) async {
    // Capture a navigator before any async gaps. Be resilient on web where
    // the local context may not have a Navigator in rare timing cases.
    NavigatorState? navigator = Navigator.maybeOf(context);
    navigator ??= Navigator.maybeOf(this.context);
    // As a last resort, attempt the root navigator; wrap to avoid throwing.
    if (navigator == null) {
      try {
        navigator = Navigator.of(context, rootNavigator: true);
      } catch (_) {
        // Keep null; we'll fallback to forceAppRebuild without popping.
      }
    }
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Ensure providerData is fresh (especially on web) before deciding which steps to show.
    try {
      await user.reload();
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (_) {}
  user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Determine if email/password is already linked.
  final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');

    // Fetch profile data once to check username/faction
    Map<String, dynamic> data = {};
    try {
  final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      data = snap.data() ?? {};
    } catch (_) {
      data = {};
    }

  // Require an in-app username stored in Firestore; do NOT treat Google
  // account displayName as our username to avoid skipping the step.
  final hasUsername =
      (data['username'] is String && (data['username'] as String).trim().isNotEmpty) ||
      (data['name'] is String && (data['name'] as String).trim().isNotEmpty);
    final hasFaction = data['faction'] is String && (data['faction'] as String).trim().isNotEmpty;

    Future<void> goToApp() async {
      if (!mounted) return;
      // Pop only if we have a navigator and there is a stack to clean up.
      if (navigator != null) {
        try {
          if (navigator.canPop()) {
            navigator.popUntil((r) => r.isFirst);
          }
        } catch (_) {
          // Ignore pop errors; we'll still rebuild the app below.
        }
      }
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
      if (navigator != null) {
        await navigator.push(MaterialPageRoute(
          builder: (_) => UsernameScreen(onComplete: () {}),
        ));
      } else {
        try {
          await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => UsernameScreen(onComplete: () {}),
          ));
        } catch (_) {
          // As a last fallback, just rebuild app (may re-enter onboarding).
          await goToApp();
          return;
        }
      }
    }

    // If the account is not linked with a password provider yet, offer to set
    // one so the user can log in via email later. Skip if already linked.
    if (!hasPasswordProvider) {
      if (!mounted) return;
      final push = navigator ?? Navigator.of(context, rootNavigator: true);
      try {
        await push.push(MaterialPageRoute(
          builder: (_) => PasswordScreen(onComplete: () {}),
        ));
      } catch (_) {
        // Non-fatal; continue to next step
      }
    }

    if (!hasFaction) {
      if (!mounted) return;
      if (navigator != null) {
        await navigator.push(MaterialPageRoute(
          builder: (_) => FactionScreen(onComplete: () {}),
        ));
      } else {
        try {
          await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => FactionScreen(onComplete: () {}),
          ));
        } catch (_) {
          await goToApp();
          return;
        }
      }
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
