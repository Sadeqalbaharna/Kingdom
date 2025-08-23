import 'package:flutter/material.dart';
import 'kingdom/app_shell.dart';

void main() {
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

    return MaterialApp(
      title: 'Unfuckwithable Kingdom',
      theme: theme,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
