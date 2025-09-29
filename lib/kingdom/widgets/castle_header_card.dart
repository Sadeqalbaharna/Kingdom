
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert' as convert;
import 'package:provider/provider.dart';
import 'dart:async';
import '../state.dart';
import '../models.dart';
import '../rewards.dart';
import 'account_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
// MapProgressBar import removed; progress bar is shown under unlock buttons in AppShell

class CastleHeaderCard extends StatefulWidget {
  final GameState state;
  const CastleHeaderCard({super.key, required this.state});

  @override
  State<CastleHeaderCard> createState() => _CastleHeaderCardState();
}

class _CastleHeaderCardState extends State<CastleHeaderCard> {
  // No amount input needed
  // No longer needed: portrait is now in GameState

  @override
  void initState() {
  super.initState();
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

  // Resolve faction -> sigil asset path
  final factionKey = ctrl.state.faction.trim().toLowerCase();
  const Map<String, String> sigilPaths = {
    'north': 'assets/images/Sigils/north.png',
    'east': 'assets/images/Sigils/east.png',
    'south': 'assets/images/Sigils/south.png',
    'west': 'assets/images/Sigils/west.png',
  };
  final String? factionSigilPath = sigilPaths[factionKey];

  // Use portrait from GameState if available
  final portrait = s.portraitAsset;

  // Removed unused totalEarnedPoints

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0), // moved dashboard up by reducing vertical margin
      child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0), // reduced vertical padding to fix overflow
          child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Portrait and QR code row
            // Removed duplicate Portrait/QR row that caused double header
            // Title row (map unlock buttons and related controls)
            Row(
              children: [
                // Account icon at top left
                AccountWidget(),
                const SizedBox(width: 1),
                const SizedBox(width: 1),
                // Map ownership button (moved left)
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
                const Spacer(),
                // Points counter: remaining / total earned
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
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
                // Move + and - buttons up here (debug only) with red dot indicator
                if (kDebugMode) ...[
                  const SizedBox(width: 6),
                  // tiny red dot to mark debug feature
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Add',
                    child: FilledButton(
                      onPressed: () => _apply(context, 1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(30, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
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
                        minimumSize: const Size(30, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ),
                ],
                const SizedBox(width: 0),
                if (kDebugMode) ...[
                  const SizedBox(width: 0),
                  // Reset all claims button (dev-only)
                  Tooltip(
                    message: 'Reset all claims',
                    child: Transform.translate(
                      offset: const Offset(-2, 0),
                      child: IconButton(
                        icon: const Icon(Icons.autorenew_outlined),
                        splashRadius: 20,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
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
                              if (!mounted) return;
                              messenger.showSnackBar(const SnackBar(content: Text('All claims reset and points refunded')));
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text('Reset failed: $e')));
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
                // Removed 'Keep' button
              ],
            ),

            // (Reverted) Centered faction sigil row removed

            Row(
              children: [
                Builder(builder: (ctx) {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final payload = convert.jsonEncode({'uid': uid.isEmpty ? 'no-uid' : uid, 'name': ctrl.currentUserDisplayName});
                  // Determine earned permanent discount using reward path definition
                  int discount = 0;
                  final completed = ctrl.totalClaimedTiles();
                  final rewards = rewardPath60();
                  for (final r in rewards) {
                    if (r.step <= completed && r.discountPercent != null) {
                      discount = r.discountPercent!;
                    }
                  }

                  Widget inner;
                  if (uid.isEmpty) {
                    inner = Center(
                      child: Text(
                        'No UID',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    );
                  } else {
                    inner = QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                    );
                  }

                  final qrBox = InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dctx) {
                          Widget big;
                          if (uid.isEmpty) {
                            big = SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(child: Text('UID not available', style: TextStyle(color: Colors.black54))),
                            );
                          } else {
                            big = SizedBox(
                              width: 200,
                              height: 200,
                              child: QrImageView(
                                data: payload,
                                version: QrVersions.auto,
                              ),
                            );
                          }
                          return AlertDialog(
                            content: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: big,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close')),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: inner,
                    ),
                  );

                  // Return QR with optional discount badge under it
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      qrBox,
                      const SizedBox(height: 6),
                      if (discount > 0)
                        Transform.translate(
                          offset: const Offset(0, 4), // move badge slightly lower
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '$discount% discount',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(width: 16),
                // If no sigil, keep info here; otherwise push portrait to the right
                (factionSigilPath == null)
                    ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctrl.currentUserDisplayName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4), // add a couple pixels of space
                            Text(
                              'Hero Level: ${s.fitness.level}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : const Spacer(),
                const SizedBox(width: 12),
                // Portrait on the right (opposite QR code) - larger
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(left: 8),
                      child: (portrait != null && portrait.isNotEmpty)
                          ? CircleAvatar(backgroundImage: AssetImage(portrait), radius: 32)
                          : const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                    ),
                    const SizedBox(height: 6),
                    // Coin counter under the portrait
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE4A3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: Color(0xFFDAA520)),
                          const SizedBox(width: 6),
                          Builder(builder: (ctx) {
                            final gold = ctrl.goldAvailable;
                            return Text('$gold Gold', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12));
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Centered faction sigil (chosen in onboarding)
            if (factionSigilPath != null) ...[
              const SizedBox(height: 1),
              Center(
                child: Transform.translate(
                  // Raise the sigil (and info) a little more
                  offset: const Offset(0, -118),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -6), // nudge sigil a few pixels higher
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            factionSigilPath,
                            width: 90,
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Transform.translate(
                        offset: const Offset(0, -10), // nudge info slightly further up
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ctrl.currentUserDisplayName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4), // small extra spacing between name and level
                            // Move hero level text up a touch more
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Text(
                                'Hero Level: ${s.fitness.level}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 12), // trimmed to keep layout tight
                          ],
                        ),
                      ),
                      // Progress bar moved under map unlock buttons (in AppShell)
                    ],
                  ),
                ),
              ),
            ],

            // Add a little bottom space so the card box extends below the info
            const SizedBox(height: 20),

            // Map label is now displayed above the map in AppShell
          ],
            ),
          ),
      ),
    );
  }

  /// Builds a faction sigil widget for the given faction string.
  // Removed unused _buildFactionSigil function
}
