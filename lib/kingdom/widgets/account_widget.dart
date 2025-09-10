import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'dart:convert' as convert;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart' as qr_pkg;
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
  bool devForceStaff = false; // debug-only toggle
  bool loading = true;

  // Fallback: render a QrPainter to an offscreen image and show it via Image.memory.
  // If this fails, show raw payload text.
  Widget _buildQrPainterImage(String payload, double size) {
    return FutureBuilder<Uint8List?>(
      future: () async {
        try {
          final painter = QrPainter(
            data: payload,
            version: QrVersions.auto,
            gapless: true,
            color: Colors.black,
            emptyColor: Colors.white,
          );
          final bytes = await painter.toImageData(size);
          return bytes?.buffer.asUint8List();
        } catch (e) {
          debugPrint('QrPainter.toImageData failed: $e');
          return null;
        }
      }(),
      builder: (ctx, snap) {
  if (snap.connectionState != ConnectionState.done) return const SizedBox();
  final data = snap.data;
  if (data == null) return _buildQrGridFallback(payload, size);
  return Image.memory(data, width: size, height: size, gaplessPlayback: true);
      },
    );
  }

  // Pure-widget fallback: build the QR matrix and render as a grid of Containers.
  Widget _buildQrGridFallback(String payload, double size) {
    try {
      final q = qr_pkg.QrCode.fromData(data: payload, errorCorrectLevel: qr_pkg.QrErrorCorrectLevel.M);
      final count = q.moduleCount;
  final cell = size / count;
  debugPrint('Qr grid fallback start: moduleCount=$count, cellSize=$cell, payloadLen=${payload.length}');
      // Build the matrix by calling the stable API `isDark(r, c)` where available.
      // If that fails, fall back to trying dynamic `modules` access.
      List<List<int>> matrix = List.generate(count, (r) => List.generate(count, (c) => 0));
      try {
        final qd = q as dynamic;
        var darkCount = 0;
        var usedOrientation = -1;

        // Try two orientations: first (r,c) then (c,r). Some builds expect x,y vs y,x.
        for (var orientation = 0; orientation < 2; orientation++) {
          darkCount = 0;
          for (var r = 0; r < count; r++) {
            for (var c = 0; c < count; c++) {
              bool dark = false;
              try {
                if (orientation == 0) {
                  dark = qd.isDark(r, c);
                } else {
                  dark = qd.isDark(c, r);
                }
              } catch (_) {
                try {
                  final modules = qd.modules;
                  if (orientation == 0) {
                    dark = (modules[r][c] == true || modules[r][c] == 1);
                  } else {
                    dark = (modules[c][r] == true || modules[c][r] == 1);
                  }
                } catch (e) {
                  // leave dark = false
                }
              }
              matrix[r][c] = dark ? 1 : 0;
              if (dark) darkCount++;
            }
          }
          if (darkCount > 0) {
            usedOrientation = orientation;
            break;
          }
        }
        debugPrint('Qr grid built: moduleCount=$count, darkCells=$darkCount, usedOrientation=$usedOrientation');
        // If neither orientation produced dark cells, try reading common private/alternate field names
  if (usedOrientation == -1) {
          debugPrint('Orientation read failed; trying alternate module field names');
          final altNames = ['_modules', 'moduleData', 'moduleMatrix', 'data'];
          var found = false;
          for (final name in altNames) {
            try {
              // Attempt dynamic access
              final altModules = (qd as dynamic)[name];
              if (altModules != null) {
                darkCount = 0;
                for (var r = 0; r < count; r++) {
                  for (var c = 0; c < count; c++) {
                    final val = altModules[r][c];
                    final dark = (val == true || val == 1);
                    matrix[r][c] = dark ? 1 : 0;
                    if (dark) darkCount++;
                  }
                }
                debugPrint('Alternate modules field "$name" provided data: darkCells=$darkCount');
                found = true;
                break;
              }
            } catch (e) {
              // ignore and continue
            }
          }
          if (!found) debugPrint('No alternate module field produced data');
        }
        // If after all attempts we have no dark cells, fall back to a remote QR image
        if (darkCount == 0) {
          try {
            final url = 'https://api.qrserver.com/v1/create-qr-code/?size=${size.toInt()}x${size.toInt()}&data=${Uri.encodeComponent(payload)}';
            debugPrint('Using remote QR image fallback: $url');
            return Image.network(url, width: size, height: size, fit: BoxFit.contain);
          } catch (e) {
            debugPrint('Remote QR image fallback failed: $e');
          }
        }
      } catch (e) {
        debugPrint('QR grid fallback failure building matrix: $e');
        return Center(child: SelectableText(payload));
      }

      // If the computed cell size is very small (sub-pixel), a grid of Containers
      // will not render visibly. Use a CustomPaint to draw scaled rects in that case.
      if (cell < 1.0) {
        debugPrint('Using CustomPaint for dense QR (cell < 1.0)');
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            size: Size(size, size),
            painter: _QrGridPainter(matrix, count),
          ),
        );
      }

      return SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (r) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(count, (c) {
                final dark = matrix[r][c] == 1;
                return Container(width: cell, height: cell, color: dark ? Colors.black : Colors.white);
              }),
            );
          }),
        ),
      );
    } catch (e) {
      debugPrint('QR grid fallback failure: $e');
      return Center(child: SelectableText(payload));
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
        showDialog(
          context: context,
          builder: (context) {
            // Use StatefulBuilder so the debug toggle updates the dialog immediately
            return StatefulBuilder(builder: (dctx, dset) {
              return AlertDialog(
                title: const Text('Account Info'),
                content: loading
                    ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))
                    : SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 280, maxWidth: 520),
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
                              if (faction != null) Text('Faction: $faction'),
                              // Debug-only: allow forcing staff UI without changing Firestore
                              if (kDebugMode)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Simulate staff (dev only)'),
                                      const SizedBox(width: 8),
                                      Switch(
                                        value: devForceStaff,
                                        onChanged: (v) {
                                          // update both dialog-local and outer state
                                          dset(() {});
                                          setState(() => devForceStaff = v);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Center(
                                child: Column(
                                  children: [
                                    Text('Your UID QR', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 12),
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
                                      // Debug: print the payload so we can verify uid presence in logs
                                      debugPrint('Account QR payload: $payload');

                                      // Show the QR box and also render the raw JSON payload under it
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
                                                // Try to build the QR widget; if it throws or fails, show a readable fallback
                                                Widget inner;
                                                // Build the QR widget. Some environments or package versions
                                                // may throw when rendering; try a couple strategies and
                                                // log errors so we can diagnose why the QR is blank on-device.
                                                // On web HTML renderer CustomPaint (QrPainter) sometimes
                                                // throws during paint. Prefer the pure-widget grid fallback
                                                // on web to guarantee visibility.
                                                if (kIsWeb) {
                                                  debugPrint('QR path chosen: grid fallback (kIsWeb)');
                                                  inner = _buildQrGridFallback(payload, 200);
                                                } else {
                                                  // On Android some painter/custompaint paths can render blank in certain runtimes.
                                                  // Use a remote PNG QR fallback as the primary renderer on non-web to guarantee visibility.
                                                  final url = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(payload)}';
                                                  debugPrint('QR path chosen: remote image (non-web): $url');
                                                  inner = Image.network(
                                                    url,
                                                    width: 200,
                                                    height: 200,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (ctx, err, st) {
                                                      debugPrint('Remote QR image failed, falling back to painter: $err');
                                                      return _buildQrPainterImage(payload, 200);
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
                                          const SizedBox(height: 6),
                                          // Always-visible payload so the user can confirm the UID even if the QR is blank
                                          SizedBox(
                                            width: 200,
                                            child: SelectableText(
                                              payload,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.copy, size: 18),
                                          label: const Text('Copy UID'),
                                            onPressed: () {
                                            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                            Clipboard.setData(ClipboardData(text: uid));
                                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('UID copied')));
                                          },
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.copy_all, size: 18),
                                          label: const Text('Copy JSON'),
                                            onPressed: () {
                                            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                            final payload = convert.jsonEncode({'uid': uid, 'name': username ?? ''});
                                            Clipboard.setData(ClipboardData(text: payload));
                                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('QR payload copied')));
                                          },
                                        ),
                                        // Debug-only quick test to exercise the grantPoints callable
                                        if (kDebugMode)
                                          TextButton.icon(
                                            icon: const Icon(Icons.bug_report, size: 18),
                                            label: const Text('Test Grant'),
                                                onPressed: () async {
                                              try {
                                                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Running test grant...')));
                                                await AuthService().testGrant();
                                                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Test grant finished — check console/logs')));
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Test grant error: $e')));
                                                debugPrint('Test grant error: $e');
                                              }
                                            },
                                          ),
                                        // Staff-only: scan a QR to award points
                                        if ((faction == 'staff') || (role == 'staff') || devForceStaff)
                                          TextButton.icon(
                                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                                            label: const Text('Scan & Grant'),
                                            onPressed: () async {
                                              final raw = await Navigator.of(context).push<String?>(MaterialPageRoute(builder: (ctx) => const QRScannerPage()));
                                              if (!mounted) return;
                                              if (raw == null) return;
                                              // Attempt to extract uid from JSON payload, otherwise assume raw is uid
                                              String uid = raw;
                                              try {
                                                final parsed = convert.jsonDecode(raw);
                                                if (parsed is Map && parsed['uid'] is String) uid = parsed['uid'];
                                              } catch (_) {}

                                              final controller = TextEditingController(text: '1');
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
                                                  // Generate a proper UUID v4 claimId to use as idempotency key
                                                  final uuid = Uuid();
                                                  final claimId = uuid.v4();
                                                  final res = await auth.requestClaimPointsByTeacher(claimId, uid, pts);
                                                if (!mounted) return;
                                                  if (res['success'] == true) {
                                                  // Refresh account info in-dialog so updated points/role show immediately
                                                  try {
                                                    await _loadAccount();
                                                  } catch (_) {}
                                                  // Also refresh the app-wide GameController so map/header reflect new available points
                                                  try {
                                                    final gc = Provider.of<GameController>(context, listen: false);
                                                    await gc.loadUnlockedTilesFromCloud();
                                                  } catch (_) {}
                                                  // Use returned newPoints when available to confirm to the granter; avoids extra read
                                                  final newPoints = (res['newPoints'] is int) ? res['newPoints'] as int : null;
                                                  final msg = (newPoints != null) ? 'Points granted — target now has $newPoints points' : 'Points granted';
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grant failed: ${res['message'] ?? 'unknown'}')));
                                                }
                                              } catch (e) {
                                                final err = e.toString();
                                                if (err.contains('already-exists') || err.contains('already processed')) {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This claim was already processed')));
                                                } else {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grant error: $e')));
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Sign the user out using AuthService, then close the dialog
                      try {
                        await AuthService().signOut();
                      } catch (_) {}
                      if (mounted) Navigator.of(context).pop();
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

// Painter used for dense QR matrices where per-cell Widgets would be invisible.
class _QrGridPainter extends CustomPainter {
  final List<List<int>> matrix;
  final int count;

  _QrGridPainter(this.matrix, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = Colors.black;
    final paintLight = Paint()..color = Colors.white;
    // Fill background
    canvas.drawRect(Offset.zero & size, paintLight);

    final cell = size.width / count;
    for (var r = 0; r < count; r++) {
      for (var c = 0; c < count; c++) {
        if (matrix[r][c] == 1) {
          final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
          canvas.drawRect(rect, paintDark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrGridPainter oldDelegate) {
    if (oldDelegate.count != count) return true;
    for (var r = 0; r < count; r++) {
      for (var c = 0; c < count; c++) {
        if (oldDelegate.matrix[r][c] != matrix[r][c]) return true;
      }
    }
    return false;
  }
}