
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
import 'package:google_fonts/google_fonts.dart';
// MapProgressBar import removed; progress bar is shown under unlock buttons in AppShell

class CastleHeaderCard extends StatefulWidget {
  final GameState state;
  final bool compact;
  const CastleHeaderCard({super.key, required this.state, this.compact = false});

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
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.teal, size: 16),
                      const SizedBox(width: 4),
                      // Show remaining/total (e.g., 3/5)
                      Builder(builder: (ctx) {
                        final totalEarned = (s.portfolio ~/ 10000);
                        final totalUsed = ctrl.totalClaimedTiles();
                        final remaining = (totalEarned - totalUsed) < 0 ? 0 : (totalEarned - totalUsed);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$remaining/$totalEarned',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Adventure Points',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
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

            // Main content row with QR, sigil, and portrait
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: QR code with discount badge
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
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

                    final double qrSize = 70;
                    final qrBox = InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dctx) {
                            Widget big;
                            if (uid.isEmpty) {
                              big = const SizedBox(
                                width: 240,
                                height: 240,
                                child: Center(
                                  child: Text(
                                    'UID not available',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              );
                            } else {
                              big = SizedBox(
                                width: 240,
                                height: 240,
                                child: Center(
                                  child: QrImageView(
                                    data: payload,
                                    version: QrVersions.auto,
                                    size: 220,
                                  ),
                                ),
                              );
                            }
                            return AlertDialog(
                              contentPadding: const EdgeInsets.all(20),
                              content: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: big,
                              ),
                              actions: [
                                Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 28),
                                    onPressed: () => Navigator.of(dctx).pop(),
                                    tooltip: 'Close',
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        width: qrSize,
                        height: qrSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: inner,
                      ),
                    );

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        qrBox,
                        if (discount > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  '$discount% off',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                    ],
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Center: Faction sigil with name and hero level
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (factionSigilPath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              factionSigilPath,
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          ctrl.currentUserDisplayName,
                          style: GoogleFonts.cinzel(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hero Level: ${s.fitness.level}',
                          style: GoogleFonts.cinzel(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Right: Portrait with gold counter
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 2),
                        ),
                        child: (portrait != null && portrait.isNotEmpty)
                            ? CircleAvatar(
                                backgroundImage: AssetImage(portrait),
                                radius: 40,
                              )
                            : const CircleAvatar(
                                radius: 40,
                                child: Icon(Icons.person, size: 40),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE4A3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, size: 16, color: Color(0xFFDAA520)),
                            const SizedBox(width: 4),
                            Builder(builder: (ctx) {
                              final gold = ctrl.goldAvailable;
                              return Text(
                                '$gold Gold',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF8B7500),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Map label is now displayed above the map in AppShell
          ],
        ),
      ),
    );
  }

  /// Builds a faction sigil widget for the given faction string.
  // Removed unused _buildFactionSigil function
}
