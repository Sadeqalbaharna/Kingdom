
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
// Firebase packages are optional on CI; this file uses a lightweight stub when
// firebase_auth/cloud_firestore are not available. TODO: restore real
// Firestore portrait subscription when CI issues are resolved.
import 'dart:async';
import '../state.dart';
import '../models.dart';
import 'account_widget.dart';
import 'progress_nodes.dart';

class CastleHeaderCard extends StatefulWidget {
  final GameState state;
  const CastleHeaderCard({super.key, required this.state});

  @override
  State<CastleHeaderCard> createState() => _CastleHeaderCardState();
}

class _CastleHeaderCardState extends State<CastleHeaderCard> {
  // No amount input needed
  String? _portraitAsset;

  @override
  void initState() {
    super.initState();
  // Portrait subscription using Firestore is disabled in CI builds where
  // firebase packages may not be resolvable. Keep _portraitAsset null; UI
  // will show default avatar. Restore subscription when CI package issues
  // are fixed.
  }

  @override
  void dispose() {
  super.dispose();
  }

  void _apply(BuildContext context, int sign) {
  final ctrl = context.read<GameController>();
  ctrl.addPoints(sign);
  }

  /// Fetch percentages for underlays 0..2 and return a map underlay->(faction->percent)
  Future<Map<int, Map<String, double>>> _fetchAllUnderlayPercentages(GameController ctrl) async {
    final Map<int, Map<String, double>> out = {};
    for (int i = 0; i < 3; i++) {
      try {
        final p = await ctrl.fetchUnderlayPercentages(i);
        out[i] = p;
      } catch (e) {
        out[i] = {};
      }
    }
    return out;
  }

  String _prettyFaction(String f) {
    final s = f.trim();
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + (s.length > 1 ? s.substring(1) : '');
  }

  @override
  Widget build(BuildContext context) {
  final ctrl = context.watch<GameController>();
  final s = widget.state;

  final totalEarnedPoints = (s.portfolio ~/ 10000); // progress bar should show earned points

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Row(
              children: [
                // Account icon at top left
                const AccountWidget(),
                const SizedBox(width: 8),
                const Icon(Icons.castle_outlined, size: 20),
                const SizedBox(width: 6),
                const Spacer(),
                // Points counter: remaining / total earned
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.teal, size: 18),
                      const SizedBox(width: 6),
                      // Show remaining/total (e.g., 3/5)
                      Builder(builder: (ctx) {
                        final totalEarned = (s.portfolio ~/ 10000);
                        final totalUsed = ctrl.totalClaimedTiles();
                        final remaining = (totalEarned - totalUsed) < 0 ? 0 : (totalEarned - totalUsed);
                        return Text('$remaining/$totalEarned', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal));
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Map ownership button
                Tooltip(
                  message: 'Map ownership percentages',
                  child: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    splashRadius: 20,
                    onPressed: () async {
                      // Show dialog while we fetch percentages for each underlay
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (dctx) {
                          return FutureBuilder<Map<int, Map<String, double>>>(
                            future: _fetchAllUnderlayPercentages(ctrl),
                            builder: (ctx, snap) {
                              if (snap.connectionState != ConnectionState.done) {
                                return AlertDialog(
                                  title: const Text('Map ownership'),
                                  content: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                                );
                              }
                              final data = snap.data ?? {};
                              return AlertDialog(
                                title: const Text('Map ownership'),
                                content: SizedBox(
                                  width: 360,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: List.generate(3, (i) {
                                      final mapData = data[i] ?? {};
                                      if (mapData.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text('Map $i: No claimed tiles'),
                                        );
                                      }
                                      final rows = <Widget>[];
                                      mapData.forEach((faction, pct) {
                                        rows.add(Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [Text(_prettyFaction(faction)), Text('${pct.toStringAsFixed(1)}%')],
                                        ));
                                      });
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [Text('Map $i:'), const SizedBox(height: 6), ...rows],
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close')),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(width: 8),
                  // Reset all claims button (dev-only)
                  Tooltip(
                    message: 'Reset all claims',
                    child: IconButton(
                      icon: const Icon(Icons.autorenew_outlined),
                      splashRadius: 20,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Reset all claims?'),
                            content: const Text('This will unclaim every unlocked tile (except the center) and refund the points. This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Reset')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await ctrl.resetAllClaims();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All claims reset and points refunded')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ],
                // Removed 'Keep' button
              ],
            ),

            // QR code with user info row
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.qr_code, size: 48, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 16),
                // Allow the info column to take available space so avatar can sit to the right
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Username: ${ctrl.currentUserDisplayName}',
                      style: Theme.of(context).textTheme.bodyMedium),
                    Text('Hero Level: ${s.fitness.level}',
                        style: Theme.of(context).textTheme.bodyMedium),
          Text('Faction: ${ctrl.factionString.isNotEmpty ? ctrl.factionString : ctrl.state.faction}',
            style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                ),
                const SizedBox(width: 8),
                // Portrait on the right (opposite QR code) - larger
                Container(
                  width: 96,
                  height: 96,
                  margin: const EdgeInsets.only(left: 8),
                  child: _portraitAsset != null
                      ? CircleAvatar(backgroundImage: AssetImage(_portraitAsset!), radius: 48)
                      : CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
                ),
              ],
            ),

            // Dev-only points control row
            Row(
              children: [
                Tooltip(
                  message: 'Add',
                  child: FilledButton(
                    onPressed: () => _apply(context, 1),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(36, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Remove',
                  child: OutlinedButton(
                    onPressed: () => _apply(context, -1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(36, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Icon(Icons.remove, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // Compact progress nodes row labelled with current underlay prefix (A/B/C)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ProgressNodes(
                label: _getUnderlayLabel(ctrl),
                nodes: List.generate(20, (i) {
                  final isActive = i < totalEarnedPoints;
                  return ProgressNode(
                    id: '${_getUnderlayLabel(ctrl)}-${i + 1}',
                    tooltip: 'Node ${i + 1}: ${isActive ? 'Unlocked' : 'Locked'}',
                    active: isActive,
                    onTap: () {
                      // Default click: show a small snackbar with info — developers can override per-node creation
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clicked node ${i + 1}')));
                    },
                  );
                }),
              ),
            ),

            // ...progress nodes shown above (no textual summary beneath)
          ],
        ),
      ),
    );
  }

  String _getUnderlayLabel(GameController ctrl) {
    switch (ctrl.mapUnderlayIndex) {
      case 1:
        return 'The Coast';
      case 2:
        return 'Arrid Wilderness';
      default:
        return 'Town of Departure';
    }
  }
}
