import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../state.dart';
// Removed scanner page import as the scan button is no longer present on this screen.

class VoucherTab extends StatelessWidget {
  const VoucherTab({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _voucherStream(String userId) {
  return FirebaseFirestore.instance
    .collection('vouchers')
    .where('userId', isEqualTo: userId)
    .where('claimed', isEqualTo: false)
    .snapshots();
  }

  Future<void> generateAndSaveVoucher() async {
    final uuid = Uuid();
    final voucherId = uuid.v4();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');
    final voucherRef = FirebaseFirestore.instance.collection('vouchers').doc(voucherId);
    await voucherRef.set({
      'id': voucherId,
      'userId': user.uid,
      'issuedAt': FieldValue.serverTimestamp(),
      'claimed': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: userId == null ? null : _voucherStream(userId),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return Row(
                        children: [
                          const Text('Vouchers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (userId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$count', style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.w700)),
                            ),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // DEBUG: Delete all vouchers button
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'DEBUG: Delete All Vouchers',
                        onPressed: () async {
                          final controller = context.read<GameController>();
                          try {
                            await controller.deleteAllVouchers();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All vouchers deleted!'))
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'))
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Generate Voucher',
                        onPressed: () async {
                          try {
                            await generateAndSaveVoucher();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher generated!')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (userId == null)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: const [
                    Icon(Icons.card_giftcard, size: 48, color: Colors.black26),
                    SizedBox(height: 12),
                    Text('Not logged in.', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              )
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _voucherStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: const [
                          Icon(Icons.card_giftcard, size: 64, color: Colors.black26),
                          SizedBox(height: 12),
                          Text('No vouchers yet. Visit the Market to redeem some!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  }
                  final vouchers = snapshot.data!.docs;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vouchers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemBuilder: (context, i) {
                      final doc = vouchers[i];
                      final voucherId = doc.id;
                      final data = doc.data();
                      final title = (data['title'] as String?)?.trim().isNotEmpty == true ? (data['title'] as String).trim() : 'Free drink';
                      // For now, map all to the freedrink art until we add more assets
                      const art = 'assets/images/vouchers/freedrink.png';
                      return _VoucherCard(
                        id: voucherId,
                        title: title,
                        artAsset: art,
                      );
                    },
                  );
                },
              ),
          ],
        ),
        // Scan button removed per request; scanning is not accessible from this screen anymore.
      ],
    );
// Add import for scanner page

  }
}

class _VoucherCard extends StatelessWidget {
  final String id;
  final String title;
  final String artAsset;
  const _VoucherCard({required this.id, required this.title, required this.artAsset});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDialog(context),
      child: Hero(
        tag: 'voucher_$id',
          child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.30), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(artAsset, fit: BoxFit.cover),
              ),
              // Gradient title bar at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.6)],
                    ),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Unclaimed chip
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Unclaimed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'voucher_$id',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.35), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(artAsset, width: 260, height: 140, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.30), width: 1),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(data: id, version: QrVersions.auto),
                  ),
                ),
                const SizedBox(height: 8),
                Text(id, style: const TextStyle(fontSize: 11, color: Colors.black38), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
