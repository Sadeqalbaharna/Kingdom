import 'package:flutter/material.dart';
import '../auth_service.dart';

class FactionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const FactionScreen({super.key, required this.onComplete});

  @override
  State<FactionScreen> createState() => _FactionScreenState();
}

class _FactionScreenState extends State<FactionScreen> {
  final _auth = AuthService();
  String? _picked;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setFaction(_picked!);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        // Navigation and Firestore update will trigger StreamBuilder in main.dart
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final factions = const ['North', 'South', 'East', 'West'];
    return Center(
      child: SizedBox(
        width: 390,
        height: 844,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            appBar: AppBar(title: const Text('Choose Faction')),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pick your allegiance'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: factions.map((f) {
                      final selected = _picked == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        onSelected: (v) => setState(() => _picked = v ? f : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: _busy || _picked == null ? null : _save,
                      child: const Text('Finish'),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
