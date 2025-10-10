
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert' as convert;
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
  final ctrl = context.watch<GameController>();
  final s = widget.state;
  
  // Responsive sizing based on screen width
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final qrSize = isMobile ? 55.0 : 70.0;
  final sigilSize = isMobile ? 55.0 : 70.0;
  final portraitSize = isMobile ? 65.0 : 85.0;
  final iconSize = isMobile ? 14.0 : 16.0;
  final nameFontSize = isMobile ? 12.0 : 14.0;
  final levelFontSize = isMobile ? 8.0 : 13.0;
  final goldFontSize = isMobile ? 11.0 : 12.0;
  final badgePadding = isMobile ? 4.0 : 8.0;
  final elementSpacing = isMobile ? 8.0 : 12.0;

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
                const Spacer(),
                // Points counter: remaining / total earned
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: isMobile ? 2 : 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.teal, size: isMobile ? 12 : 16),
                      SizedBox(width: isMobile ? 2 : 4),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                                fontSize: isMobile ? 9 : 13,
                              ),
                            ),
                            if (!isMobile) ...[
                              SizedBox(width: 4),
                              Text(
                                'Adventure Points',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                // Move + and - buttons up here (debug only) with red dot indicator
                if (kDebugMode) ...[
                  SizedBox(width: isMobile ? 2 : 6),
                  // tiny red dot to mark debug feature
                  if (!isMobile) Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  if (!isMobile) const SizedBox(width: 6),
                  Tooltip(
                    message: 'Add',
                    child: FilledButton(
                      onPressed: () => _apply(context, 1),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(isMobile ? 24 : 30, isMobile ? 24 : 30),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 6),
                      ),
                      child: Icon(Icons.add, size: isMobile ? 14 : 20),
                    ),
                  ),
                  SizedBox(width: isMobile ? 1 : 4),
                  Tooltip(
                    message: 'Remove',
                    child: OutlinedButton(
                      onPressed: () => _apply(context, -1),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(isMobile ? 24 : 30, isMobile ? 24 : 30),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(Icons.remove, size: isMobile ? 14 : 20),
                    ),
                  ),
                ],
                if (!isMobile) const SizedBox(width: 0),
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
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: isMobile ? 2 : 6),
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
                          style: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 10 : 12),
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
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
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
                          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
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
                          SizedBox(height: isMobile ? 4 : 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: badgePadding, vertical: isMobile ? 2 : 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_offer, size: iconSize, color: Colors.green),
                                SizedBox(width: isMobile ? 3 : 4),
                                Text(
                                  '$discount% off',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 10 : 12,
                                    color: const Color(0xFF2E7D32),
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
                  
                  SizedBox(width: elementSpacing),
                  
                  // Center: Faction sigil with name and hero level
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (factionSigilPath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
                            child: Image.asset(
                              factionSigilPath,
                              width: sigilSize,
                              height: sigilSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: isMobile ? 0 : 6),
                        ],
                        Text(
                          ctrl.currentUserDisplayName,
                          style: GoogleFonts.cinzel(
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 0 : 2),
                        Text(
                          'Hero Level: Coming Soon',
                          style: GoogleFonts.cinzel(
                            fontSize: levelFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: elementSpacing),
                  
                  // Right: Portrait with gold counter
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: portraitSize,
                        height: portraitSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: isMobile ? 1.5 : 2),
                        ),
                        child: (portrait != null && portrait.isNotEmpty)
                            ? CircleAvatar(
                                backgroundImage: AssetImage(portrait),
                                radius: portraitSize / 2,
                              )
                            : CircleAvatar(
                                radius: portraitSize / 2,
                                child: Icon(Icons.person, size: portraitSize / 2),
                              ),
                      ),
                      SizedBox(height: isMobile ? 0 : 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: badgePadding, vertical: isMobile ? 2 : 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                          border: Border.all(color: const Color(0xFFFFE4A3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on, size: iconSize, color: const Color(0xFFDAA520)),
                            SizedBox(width: isMobile ? 3 : 4),
                            Builder(builder: (ctx) {
                              final gold = ctrl.goldAvailable;
                              return Text(
                                '$gold Gold',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: goldFontSize,
                                  color: const Color(0xFF8B7500),
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
