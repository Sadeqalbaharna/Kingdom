import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'kingdom/app_shell.dart';
import 'kingdom/onboarding/onboarding_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'kingdom/state.dart';

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  await _init();
  runApp(const KingdomApp());
}

class KingdomApp extends StatelessWidget {
  const KingdomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A4)),
      useMaterial3: true,
      textTheme: const TextTheme().apply(bodyColor: const Color(0xFF073B3A)),
    );

    return ChangeNotifierProvider<GameController>(
      create: (_) => GameController(),
      child: MaterialApp(
        title: 'Kingdom',
        theme: theme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final user = snapshot.data;
            if (user == null) {
              return const OnboardingFlow();
            }
            // Check profile completeness
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, profSnap) {
                if (profSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final data = profSnap.data?.data() ?? {};
                final hasUsername = (user.displayName != null && user.displayName!.trim().isNotEmpty) ||
                  (data['username'] is String && (data['username'] as String).trim().isNotEmpty) ||
                  (data['name'] is String && (data['name'] as String).trim().isNotEmpty);
                final hasFaction = data['faction'] is String && (data['faction'] as String).trim().isNotEmpty;
                if (!hasUsername || !hasFaction) {
                  return const OnboardingFlow();
                }
                // Load unlocked tiles before showing AppShell
                return FutureBuilder<void>(
                  future: _loadTilesOnce(context),
                  builder: (context, tileSnap) {
                    if (tileSnap.connectionState != ConnectionState.done) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    return const AppShell();
                  },
                );
              },
            );
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  // Helper to load tiles only once per login session
  static bool _tilesLoaded = false;
  static Future<void> _loadTilesOnce(BuildContext context) async {
    if (_tilesLoaded) return;
    // Wait for the widget tree to build and Provider to be available
    await Future.delayed(const Duration(milliseconds: 10));
    try {
      final gc = Provider.of<GameController>(context, listen: false);
      await gc.loadUnlockedTilesFromCloud();
      _tilesLoaded = true;
    } catch (_) {}
  }
}
