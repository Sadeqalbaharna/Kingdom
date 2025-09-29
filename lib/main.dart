import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'kingdom/app_shell.dart';
import 'kingdom/onboarding/onboarding_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'kingdom/state.dart';
import 'kingdom/onboarding/auth_notifier.dart';

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}


final ValueNotifier<Key> appKeyNotifier = ValueNotifier<Key>(UniqueKey());

void forceAppRebuild() {
  appKeyNotifier.value = UniqueKey();
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

    return ValueListenableBuilder<Key>(
      valueListenable: appKeyNotifier,
      builder: (context, appKey, _) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<GameController>(create: (_) => GameController()),
            ChangeNotifierProvider<AuthNotifier>(create: (_) => AuthNotifier()),
          ],
          child: MaterialApp(
            key: appKey,
            title: 'Kingdom',
            theme: theme,
            home: Consumer<AuthNotifier>(
              builder: (context, authNotifier, _) {
                return StreamBuilder<User?>(
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
                        // Capture a local BuildContext-independent reference if needed
                        // Capture the controller before awaiting to avoid using context across the gap
                        final gc = Provider.of<GameController>(context, listen: false);
                        return FutureBuilder<void>(
                          future: _loadTilesOnceWith(gc),
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
                );
              },
            ),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }

  // Helper to load tiles only once per login session
  static bool _tilesLoaded = false;
  static Future<void> _loadTilesOnceWith(GameController gc) async {
    if (_tilesLoaded) return;
    // Wait for the widget tree to build and Provider to be available
    await Future.delayed(const Duration(milliseconds: 10));
    try {
      await gc.loadUnlockedTilesFromCloud();
      _tilesLoaded = true;
    } catch (_) {}
  }
}
