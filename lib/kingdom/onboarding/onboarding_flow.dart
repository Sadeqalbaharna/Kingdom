import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'screens/google_sign_in_screen.dart';
import 'screens/password_screen.dart';
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
  @override
  Widget build(BuildContext context) {
    return GoogleSignInScreen(
      onSignedIn: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        // Next step: set a password (optional, but requested)
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PasswordScreen(
            onComplete: () async {
              if (!mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UsernameScreen(
                  onComplete: () async {
                    if (!mounted) return;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FactionScreen(
                        onComplete: () async {
                          if (!mounted) return;
                          // Force rebuild to trigger StreamBuilder in main.dart
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          await Future.delayed(const Duration(milliseconds: 100));
                          // ignore: use_build_context_synchronously
                          (context as Element).reassemble();
                        },
                      ),
                    ));
                  },
                ),
              ));
            },
          ),
        ));
      },
    );
  }
}
