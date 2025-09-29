import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math';

class KingdomMapPainter extends CustomPainter {
  // Hexagon grid parameters for overlay
  final double hexRadius = 32.0; // Adjust as needed to fit 50 hexes

  Offset getHexCenter(int i, Size size) {
    // ...existing code...
    int cols = 10;
    int col = i % cols;
    int row = i ~/ cols;
    double xSpacing = hexRadius * 1.75;
    double ySpacing = hexRadius * 1.5;
    double x = hexRadius + col * xSpacing;
    double y = hexRadius + row * ySpacing;
    return Offset(x, y);
  }

  Path getHexPath(Offset center, double radius) {
    // ...existing code...
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (i * 60) * pi / 180.0;
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
  final ui.Image? underlay;
  final Offset underlayOffset;
  final double underlayScale;
  final ui.Image? keep;
  final ui.Image? shack;
  final Set unlocked;
  final double tileSize;
  final int maxRadius;
  final bool showGrid;
  final bool showLabels;
  final Map<String, ui.Image>? hexIcons;
  final String hexLabelPrefix;
  final String? faction;
  final Map<String, int> hexClaimCounts;

  // For dev-only legacy highlight (single special)
  final int specialHexQ;
  final int specialHexR;
  // For multi-special support (may include extra keys like 'kind')
  final List<Map<String, dynamic>>? specialTiles;
  final int currentUnderlay;
  final int painterUnderlay;
  final bool devHighlightSpecial;

  static const Map<String, Color> factionColors = {
    'north': ui.Color.fromARGB(255, 21, 255, 0),
    'east': Colors.red,
    'south': Color(0xFF1565C0), // Distinct blue (Blue 800)
    'west': Colors.yellow,
  };

  KingdomMapPainter({
    required this.underlay,
  this.underlayOffset = Offset.zero,
  this.underlayScale = 1.0,
    required this.keep,
    required this.shack,
    required this.unlocked,
    required this.tileSize,
    required this.maxRadius,
    required this.showGrid,
    required this.showLabels,
    this.hexIcons,
    this.hexLabelPrefix = 'A',
    this.faction,
    this.hexClaimCounts = const {},
  required this.specialHexQ,
  required this.specialHexR,
  this.specialTiles,
    required this.currentUnderlay,
    required this.painterUnderlay,
    this.devHighlightSpecial = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the map underlay FIRST so it is always visible
    if (underlay != null) {
      final paint = Paint();
      final srcW = underlay!.width.toDouble();
      final srcH = underlay!.height.toDouble();
      final src = Rect.fromLTWH(0, 0, srcW, srcH);

      // Compute a uniform scale that covers the canvas (BoxFit.cover) while preserving
      // the image aspect ratio, then apply the caller-provided underlayScale multiplier.
      final scaleCover = (size.width / srcW > size.height / srcH)
          ? (size.width / srcW)
          : (size.height / srcH);
      final uniform = scaleCover * underlayScale;
      final drawW = srcW * uniform;
      final drawH = srcH * uniform;
      final center = Offset(size.width / 2, size.height / 2) + underlayOffset;
      final dst = Rect.fromCenter(center: center, width: drawW, height: drawH);
      canvas.drawImageRect(underlay!, src, dst, paint);
    } else {
  final fallbackPaint = Paint()..color = Colors.grey.withValues(alpha: 0.05);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fallbackPaint);
    }

    // Draw hex grid overlay and labels ABOVE the underlay
    final center = Offset(size.width / 2, size.height / 2);
    final r = tileSize;
    for (int q = -maxRadius; q <= maxRadius; q++) {
      for (int r_ = -maxRadius; r_ <= maxRadius; r_++) {
        if ((q).abs() + (r_).abs() + (-q - r_).abs() > maxRadius * 2) continue;
        final hexCenter = _axialToPixel(q, r_, center, r);
        final hexBounds = Rect.fromCircle(center: hexCenter, radius: r);
        // Only draw hexes fully inside the canvas
        if (hexBounds.left < 0 || hexBounds.right > size.width || hexBounds.top < 0 || hexBounds.bottom > size.height) {
          continue;
        }
        final key = '$q,$r_';
        if (unlocked.contains(key)) {
          final normalizedFaction = (faction ?? '').trim().toLowerCase();
          final borderColor = factionColors[normalizedFaction] ?? Colors.teal;
          // No terminal logging here to avoid noisy output in console.
          final ownedPaint = Paint()
            ..color = borderColor.withValues(alpha: 0.7)
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          _drawHexagon(canvas, hexCenter, r, ownedPaint);
        } else if (showGrid) {
          final gridPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.7)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          _drawHexagon(canvas, hexCenter, r, gridPaint);
        }
        // Label all visible hexes if showLabels is true
        if (showLabels) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: '$hexLabelPrefix$q,$r_',
              style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, hexCenter - Offset(textPainter.width / 2, textPainter.height / 2));
        }

         // Draw icon if present for this hex
         if (hexIcons != null && hexIcons!.containsKey(key)) {
           final icon = hexIcons![key];
           if (icon != null) {
             // Draw icon at hex center, size smaller than hex
             final iconSize = r * 1.2; // slightly smaller than hex
             final dst = Rect.fromCenter(center: hexCenter, width: iconSize, height: iconSize);
             final src = Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble());
             canvas.drawImageRect(icon, src, dst, Paint());
           }
         }

        // Highlight all special tiles (multi)
        if (devHighlightSpecial && specialTiles != null && currentUnderlay == painterUnderlay) {
          for (int i = 0; i < specialTiles!.length; i++) {
            final tile = specialTiles![i];
            if (tile['q'] == q && tile['r'] == r_) {
              // Choose border color per kind for debug clarity
              final kind = (tile['kind'] as String?) ?? '';
              Color c;
              switch (kind) {
                case 'voucher':
                  c = Colors.amber; // gold/yellow
                  break;
                case 'lore':
                  c = Colors.cyan; // teal/cyan
                  break;
                case 'unfortunate':
                  c = Colors.pinkAccent; // red/pink
                  break;
                default:
                  c = (i == 0 ? Colors.amber : Colors.cyan);
              }
              final specialPaint = Paint()
                ..color = c.withValues(alpha: 0.85)
                ..strokeWidth = 5.0
                ..style = PaintingStyle.stroke;
              _drawHexagon(canvas, hexCenter, r * 1.10, specialPaint);
            }
          }
        }
      }
    }
    // ...existing code...
  }

  Offset _axialToPixel(int q, int r, Offset center, double tileSize) {
    final x = tileSize * (3.0 / 2.0 * q);
    final y = tileSize * (sqrt(3) / 2.0 * q + sqrt(3) * r);
    return Offset(center.dx + x, center.dy + y);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    // Only draw the outline, not a filled hex
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
