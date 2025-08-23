import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../hex_types.dart';

class KingdomMapPainter extends CustomPainter {
  final Set<Axial> unlocked;
  final double tileSize;
  final ui.Image? keepImg;
  final ui.Image? mapUnderlay;
  // grass assets kept for compatibility (unused)
  final ui.Image? grass;
  final ui.Image? grassActive;

  KingdomMapPainter({
    required this.unlocked,
    required this.tileSize,
    required this.keepImg,
    required this.mapUnderlay,
    this.grass,
    this.grassActive,
  });

  // axial -> pixel (pointy-top)
  Offset axialToPixel(int q, int r, Offset center) {
    final x = tileSize * sqrt(3) * (q + r / 2);
    final y = tileSize * 1.5 * r;
    return center + Offset(x, y);
  }

  // pixel -> axial (fractional)
  Offset pixelToAxial(Offset p, Offset center) {
    final x = p.dx - center.dx;
    final y = p.dy - center.dy;
    final q = (sqrt(3) / 3 * x - 1 / 3 * y) / tileSize;
    final r = (2 / 3 * y) / tileSize;
    return Offset(q, r);
  }

  Path hexPath(Offset c, [double? radius]) {
    final r = radius ?? tileSize;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final ang = (pi / 180) * (60 * i - 30);
      final vx = c.dx + r * cos(ang);
      final vy = c.dy + r * sin(ang);
      if (i == 0) path.moveTo(vx, vy); else path.lineTo(vx, vy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final board = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);

    // Underlay
    if (mapUnderlay != null) {
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      final src = Rect.fromLTWH(0, 0, mapUnderlay!.width.toDouble(), mapUnderlay!.height.toDouble());
      canvas.drawImageRect(mapUnderlay!, src, dst, Paint());
    } else {
      final grad = const LinearGradient(
        colors: [Color(0xFFDFF8D9), Color(0xFFBFECC0)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
      canvas.drawRect(board, Paint()..shader = grad.createShader(board));
    }

    // Clip to map bounds
    canvas.save();
    canvas.clipRect(board);

    // Axial bounds from corners (bulletproof coverage)
    final corners = <Offset>[
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ].map((p) => pixelToAxial(p, center)).toList();

    double minQ = corners.map((o) => o.dx).reduce(min);
    double maxQ = corners.map((o) => o.dx).reduce(max);
    double minR = corners.map((o) => o.dy).reduce(min);
    double maxR = corners.map((o) => o.dy).reduce(max);

    const pad = 4;
    final qStart = minQ.floor() - pad;
    final qEnd   = maxQ.ceil()  + pad;
    final rStart = minR.floor() - pad;
    final rEnd   = maxR.ceil()  + pad;

    bool overlaps(Offset c) {
      final w = sqrt(3) * tileSize;
      final h = 2 * tileSize;
      final rect = Rect.fromCenter(center: c, width: w, height: h);
      return board.overlaps(rect);
    }

    // Styles
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withOpacity(0.45); // visible black grid

    final ownedBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = const Color(0xFF10B981); // emerald green

    final haloPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.12);

    for (int r = rStart; r <= rEnd; r++) {
      for (int q = qStart; q <= qEnd; q++) {
        final c = axialToPixel(q, r, center);
        if (!overlaps(c)) continue;

        // grid for every hex
        canvas.drawPath(hexPath(c), gridPaint);

        // owned = green border + soft inner halo, no fill
        final a = Axial(q, r);
        if (unlocked.contains(a)) {
          canvas.drawPath(hexPath(c, tileSize - 3), haloPaint);
          canvas.drawPath(hexPath(c), ownedBorder);
        }
      }
    }

    // Keep at center
    final keepCenter = axialToPixel(0, 0, center);
    final ks = tileSize * 1.6;
    final kdst = Rect.fromCenter(center: keepCenter, width: ks, height: ks);
    if (keepImg != null) {
      final ksrc = Rect.fromLTWH(0, 0, keepImg!.width.toDouble(), keepImg!.height.toDouble());
      canvas.drawImageRect(keepImg!, ksrc, kdst, Paint());
    } else {
      canvas.drawCircle(keepCenter, tileSize * 0.8, Paint()..color = Colors.grey);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KingdomMapPainter old) {
    return tileSize != old.tileSize ||
        unlocked.length != old.unlocked.length ||
        keepImg != old.keepImg || mapUnderlay != old.mapUnderlay;
  }
}
