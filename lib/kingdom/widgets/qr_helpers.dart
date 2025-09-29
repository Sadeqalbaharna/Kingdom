import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart' as qr_pkg;
import 'package:flutter/foundation.dart';

// Render a QrPainter to an offscreen image and show it via Image.memory.
Widget buildQrPainterImage(String payload, double size) {
  return FutureBuilder<Uint8List?>(
    future: () async {
      try {
        final painter = QrPainter(
          data: payload,
          version: QrVersions.auto,
          gapless: true,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
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
      if (data == null) return buildQrGridFallback(payload, size);
      return Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.memory(data, width: size, height: size, gaplessPlayback: true),
      );
    },
  );
}

// Build the QR matrix and render as a grid of Containers.
Widget buildQrGridFallback(String payload, double size) {
  try {
    final q = qr_pkg.QrCode.fromData(data: payload, errorCorrectLevel: qr_pkg.QrErrorCorrectLevel.M);
    final count = q.moduleCount;
    final cell = size / count;
    List<List<int>> matrix = List.generate(count, (r) => List.generate(count, (c) => 0));
    try {
      final qd = q as dynamic;
      var darkCount = 0;
      var usedOrientation = -1;
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
              // Fallback to alternative module access
              try {
                final modules = qd.modules;
                if (orientation == 0) {
                  dark = (modules[r][c] == true || modules[r][c] == 1);
                } else {
                  dark = (modules[c][r] == true || modules[c][r] == 1);
                }
              } catch (e) {
                debugPrint('qr_helpers: failed to read modules via dynamic path: $e');
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
      if (usedOrientation == -1) {
        final altNames = ['_modules', 'moduleData', 'moduleMatrix', 'data'];
        for (final name in altNames) {
          try {
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
              break;
            }
          } catch (e) {
            debugPrint('qr_helpers: alternative module field $name failed: $e');
          }
        }
      }
      if (darkCount == 0) {
        try {
          final url = 'https://api.qrserver.com/v1/create-qr-code/?size=${size.toInt()}x${size.toInt()}&data=${Uri.encodeComponent(payload)}';
          return Image.network(url, width: size, height: size, fit: BoxFit.contain);
        } catch (e) {
          debugPrint('qr_helpers: remote QR fallback failed: $e');
        }
      }
    } catch (e) {
      debugPrint('qr_helpers: failed to build matrix: $e');
      return Center(child: SelectableText(payload));
    }
    if (cell < 1.0) {
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
    return Center(child: SelectableText(payload));
  }
}

class _QrGridPainter extends CustomPainter {
  final List<List<int>> matrix;
  final int count;
  _QrGridPainter(this.matrix, this.count);
  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = Colors.black;
    final paintLight = Paint()..color = Colors.white;
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
