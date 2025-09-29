import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class VoucherScannerPage extends StatelessWidget {
  const VoucherScannerPage({super.key});

  void _onDetect(BuildContext context, BarcodeCapture capture) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = context.read<GameController>();
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    // Show debug dialog with scanned QR code's unique ID
    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Scanned Voucher QR'),
        content: Text('Voucher ID: $code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    // Try to find the voucher by ID and update its claimed field
    final voucherRef = FirebaseFirestore.instance.collection('vouchers').doc(code);
    final doc = await voucherRef.get();
    if (doc.exists && doc.data()?['claimed'] == false) {
      await voucherRef.update({'claimed': true});
      // Immediate feedback popup on grantee device
      ctrl.showSpecialMessage('YOU HAVE REDEEMED A DRINK VOUCHER');
      messenger.showSnackBar(const SnackBar(content: Text('Voucher claimed!')));
      navigator.pop();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Invalid or already claimed voucher.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Voucher QR')),
      body: MobileScanner(
        onDetect: (capture) => _onDetect(context, capture),
      ),
    );
  }
}
