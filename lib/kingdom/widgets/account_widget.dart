import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert' as convert;
import 'qr_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../state.dart' show GameController;
import '../onboarding/auth_service.dart';
import 'qr_scanner_page.dart';
import 'package:uuid/uuid.dart';

class AccountWidget extends StatefulWidget {
  const AccountWidget({super.key});

  @override
  State<AccountWidget> createState() => _AccountWidgetState();
}

class _AccountWidgetState extends State<AccountWidget> {
  String? email;
  String? username;
  String? portraitAsset;
  String? faction;
  String? role;
  bool loading = true;

  String _factionDisplayName(String? key) {
    final k = (key ?? '').trim().toLowerCase();
    switch (k) {
      case 'north':
        return 'Verdant Republic of Thornmere';
      case 'east':
        return 'Emberborn Dominion of Drakos Forge';
      case 'south':
        return 'Seafaring Federation of Nerathis';
      case 'west':
        return 'Sun-Crowned Kingdom of Solvarra';
      default:
        return key ?? '';
    }
  }


  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      email = user?.email;
      username = user?.displayName;
    });
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        username = data?['username'] ?? data?['name'] ?? username;
  portraitAsset = data?['portrait'];
        faction = data?['faction'];
        role = data?['role'];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: portraitAsset != null
          ? CircleAvatar(backgroundImage: AssetImage(portraitAsset!), radius: 14)
          : const Icon(Icons.account_circle, size: 28),
      tooltip: 'Account',
      onPressed: () {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        showDialog(
          context: context,
          builder: (context) {
            // Use StatefulBuilder so the debug toggle updates the dialog immediately
            return StatefulBuilder(builder: (dctx, dset) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final dialogMaxWidth = screenWidth - 24;
              final dialogMaxHeight = screenHeight - 48;
              return AlertDialog(
                title: const Text('Account Info'),
                content: loading
                    ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))
                    : SizedBox(
                        width: dialogMaxWidth < 520 ? dialogMaxWidth : 520,
                        height: dialogMaxHeight < 600 ? dialogMaxHeight : 600,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (email != null) Text('Email: $email'),
                                const SizedBox(height: 8),
                                if (portraitAsset != null)
                                  Center(
                                    child: CircleAvatar(
                                      backgroundImage: AssetImage(portraitAsset!),
                                      radius: 40,
                                    ),
                                  ),
                                if (username != null) Text('Username: $username'),
                                if (faction != null) Text('Faction: ${_factionDisplayName(faction)}'),
                                // Debug-only staff simulation toggle removed
                                const SizedBox(height: 12),
                                Center(
                                  child: Column(
                                    children: [
                                      // Removed 'Your UID QR' label for a cleaner layout
                                      Builder(builder: (bctx) {
                                        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                        final payload = convert.jsonEncode({'uid': uid.isEmpty ? 'no-uid' : uid, 'name': username ?? ''});
                                        // If we don't have a real uid yet, show the text fallback instead of attempting a QR
                                        if (uid.isEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.black26),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: SizedBox(
                                              width: 200,
                                              height: 200,
                                              child: Center(
                                                child: SelectableText(
                                                  'UID not available',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        debugPrint('Account QR payload: $payload');
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: Colors.black26),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: SizedBox(
                                                width: 200,
                                                height: 200,
                                                child: Builder(builder: (ctx) {
                                                  Widget inner;
                                                  if (kIsWeb) {
                                                    debugPrint('QR path chosen: grid fallback (kIsWeb)');
                                                    inner = buildQrGridFallback(payload, 200);
                                                  } else {
                                                    final url = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(payload)}';
                                                    debugPrint('QR path chosen: remote image (non-web): $url');
                                                    inner = Image.network(
                                                      url,
                                                      width: 200,
                                                      height: 200,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (ctx, err, st) {
                                                        debugPrint('Remote QR image failed, falling back to painter: $err');
                                                        return buildQrPainterImage(payload, 200);
                                                      },
                                                    );
                                                  }
                                                  return Container(
                                                    color: Colors.white,
                                                    child: inner,
                                                  );
                                                }),
                                              ),
                                            ),
                                            // QR payload text removed
                                          ],
                                        );
                                      }),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          // Staff-only actions (visible only for real staff accounts)
                                          // Copy UID/JSON actions removed
                                          // Test Grant action removed
                                          if (((faction ?? '').trim().toLowerCase() == 'staff') || ((role ?? '').trim().toLowerCase() == 'staff'))
                                            TextButton.icon(
                                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                                              label: const Text('Scan & Grant'),
                                              onPressed: () async {
                                                // Capture dependencies before any async gaps
                                                final gc = Provider.of<GameController>(context, listen: false);
                                                final raw = await navigator.push<String?>(MaterialPageRoute(builder: (ctx) => const QRScannerPage()));
                                                if (!mounted) return;
                                                if (raw == null) return;
                                                // First, check if this is a Voucher QR (voucherId stored as the whole QR payload)
                                                try {
                                                  final voucherRef = FirebaseFirestore.instance.collection('vouchers').doc(raw);
                                                  final voucherDoc = await voucherRef.get();
                                                  if (voucherDoc.exists) {
                                                    final data = voucherDoc.data();
                                                    final alreadyClaimed = data != null && data['claimed'] == true;
                                                    if (alreadyClaimed) {
                                                      messenger.showSnackBar(const SnackBar(content: Text('Invalid or already claimed voucher.')));
                                                      return;
                                                    }
                                                    await voucherRef.update({
                                                      'claimed': true,
                                                      'claimedAt': FieldValue.serverTimestamp(),
                                                      'claimedBy': FirebaseAuth.instance.currentUser?.uid,
                                                    });
                                                    messenger.showSnackBar(const SnackBar(content: Text('Voucher claimed!')));
                                                    return; // Do not continue to point-grant flow
                                                  }
                                                } catch (_) {
                                                  // If Firestore check fails, fall through to point grant handling
                                                }

                                                String uid = raw;
                                                try {
                                                  final parsed = convert.jsonDecode(raw);
                                                  if (parsed is Map && parsed['uid'] is String) uid = parsed['uid'];
                                                } catch (_) {}
                                                final controller = TextEditingController(text: '1');
                                                if (!context.mounted) return;
                                                final ptsStr = await showDialog<String?>(
                                                  context: context,
                                                  builder: (dctx) {
                                                    return AlertDialog(
                                                      title: const Text('Grant points'),
                                                      content: TextField(
                                                        controller: controller,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(labelText: 'Points to grant'),
                                                      ),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(dctx).pop(null), child: const Text('Cancel')),
                                                        TextButton(onPressed: () => Navigator.of(dctx).pop(controller.text.trim()), child: const Text('Grant')),
                                                      ],
                                                    );
                                                  },
                                                );
                                                if (!mounted) return;
                                                if (ptsStr == null) return;
                                                final pts = int.tryParse(ptsStr) ?? 0;
                                                if (pts <= 0) return;
                                                try {
                                                  final auth = AuthService();
                                                  final uuid = Uuid();
                                                  final claimId = uuid.v4();
                                                  final res = await auth.requestClaimPointsByTeacher(claimId, uid, pts);
                                                  if (!mounted) return;
                                                  if (res['success'] == true) {
                                                    // Show congratulatory popup immediately
                                                    final congratsText = pts == 1
                                                        ? 'You gain an influance point'
                                                        : 'You gain $pts influance points';
                                                    if (!context.mounted) return;
                                                    await showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        content: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: const [
                                                            Text(
                                                              'CONGRATULATIONS!',
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(ctx).pop(),
                                                            child: const Text('OK'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    // Append the detail line under the title using a SnackBar and refresh state
                                                    try {
                                                      await _loadAccount();
                                                    } catch (_) {}
                                                    try {
                                                      await gc.loadUnlockedTilesFromCloud();
                                                    } catch (_) {}
                                                    final newPoints = (res['newPoints'] is int) ? res['newPoints'] as int : null;
                                                    final detail = (newPoints != null)
                                                        ? ' — target now has $newPoints points'
                                                        : '';
                                                    messenger.showSnackBar(
                                                      SnackBar(content: Text('$congratsText$detail')),
                                                    );
                                                  } else {
                                                    messenger.showSnackBar(SnackBar(content: Text('Grant failed: ${res['message'] ?? 'unknown'}')));
                                                  }
                                                } catch (e) {
                                                  final err = e.toString();
                                                  if (err.contains('already-exists') || err.contains('already processed')) {
                                                    if (mounted) messenger.showSnackBar(const SnackBar(content: Text('This claim was already processed')));
                                                  } else {
                                                    if (mounted) messenger.showSnackBar(SnackBar(content: Text('Grant error: $e')));
                                                  }
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ) ,
                actions: [
                  TextButton(
                    onPressed: () => navigator.pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await AuthService().signOut();
                      } catch (_) {}
                      if (mounted) navigator.pop();
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              );
                    });
                  },
                );
              },
            );
          }
        }
