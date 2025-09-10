import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String? _last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan UID QR'), actions: [
        IconButton(
          tooltip: 'Manual input',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final controller = TextEditingController();
            final result = await showDialog<String?>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('Enter UID or raw QR payload'),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'uid or JSON payload'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dctx).pop(null), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.of(dctx).pop(controller.text.trim()), child: const Text('OK')),
                ],
              ),
            );
            if (result != null && result.isNotEmpty) {
              if (mounted) Navigator.of(context).pop(result);
            }
          },
        ),
      ]),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              try {
                if (capture.barcodes.isEmpty) return;
                final barcode = capture.barcodes.first;
                final String? raw = barcode.rawValue;
                if (raw == null) return;
                if (_last == raw) return;
                _last = raw;
                if (mounted) Navigator.of(context).pop(raw);
              } catch (_) {}
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
              child: const Text('Point the camera at a user QR code', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
