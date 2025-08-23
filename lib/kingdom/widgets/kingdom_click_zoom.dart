// lib/kingdom/widgets/kingdom_click_zoom.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kingdom/kingdom/state.dart';           // GameController, GameState
import 'package:kingdom/kingdom/controller_shims.dart'; // adds pointsRemaining/unlock/unown

/// A bounded, pinch-zoomable map with a full hex grid overlay.
/// - Underlay: assets/images/map_underlay.png
/// - Full black grid across the image
/// - Owned tiles outlined in teal (no fill)
/// - Tap empty + have points => unlock
/// - Tap owned => confirm unown (refund)
///
/// No constructor args: it reads state from Provider.
class KingdomClickZoom extends StatelessWidget {
  const KingdomClickZoom({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final game = controller.state;

    return AspectRatio(
      aspectRatio: 3 / 4, // phone-ish area; parent scrollable can size as needed
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // We'll render the image at full box size (cover).
            return _BoundedInteractive(
              minScale: 1.0,
              maxScale: 2.6,
              childSize: Size(w, h),
              child: _HexMap(
                size: Size(w, h),
                unlocked: game.unlocked,
                onTapHex: (key, isOwned) async {
                  if (isOwned) {
                    final yes = await _confirmUnown(context);
                    if (yes == true) controller.unownTile(key);
                  } else {
                    if (controller.pointsRemaining > 0) {
                      controller.unlockTile(key);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No points left. 1 point per 10k BHD.')),
                      );
                    }
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<bool?> _confirmUnown(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Unown this tile?'),
      content: const Text('You’ll reclaim 1 point.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unown')),
      ],
    ),
  );
}

/// Simple InteractiveViewer wrapper that clamps panning to the child size.
class _BoundedInteractive extends StatelessWidget {
  const _BoundedInteractive({
    required this.child,
    required this.childSize,
    this.minScale = 1,
    this.maxScale = 3,
  });

  final Widget child;
  final Size childSize;
  final double minScale;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: minScale,
      maxScale: maxScale,
      constrained: true,
      boundaryMargin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: childSize.width,
        height: childSize.height,
        child: child,
      ),
    );
  }
}

/// Core map stack: image underlay + hex painter + tap handling.
class _HexMap extends StatefulWidget {
  const _HexMap({
    required this.size,
    required this.unlocked,
    required this.onTapHex,
  });

  final Size size;
  final Set<String> unlocked;
  final void Function(String key, bool isOwned) onTapHex;

  @override
  State<_HexMap> createState() => _HexMapState();
}

class _HexMapState extends State<_HexMap> {
  late final ImageProvider _image = const AssetImage('assets/images/map_underlay.png');

  // Hex layout numbers (pointy-top)
  // r = outer radius (center -> vertex). Side length = r.
  // w = width of hex = sqrt(3) * r ; vertical step = 1.5 * r.
  double r = 32; // base radius; real on-screen size depends on container

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Scale radius so hexes look nice for this canvas size
    r = math.max(22, math.min(size.width, size.height) / 18);

    // Precompute grid bounds so we cover the entire image area.
    final cols = (size.width / (math.sqrt(3) * r)).ceil() + 4;  // pad to ensure coverage
    final rows = (size.height / (1.5 * r)).ceil() + 4;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _handleTap(d.localPosition, size),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _image,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Hex grid + owned outlines
          CustomPaint(
            painter: _HexPainter(
              size: size,
              r: r,
              cols: cols,
              rows: rows,
              unlocked: widget.unlocked,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(Offset p, Size size) {
    final axial = _pixelToAxial(p, r);
    final key = '${axial.q},${axial.r}';
    final isOwned = widget.unlocked.contains(key);
    widget.onTapHex(key, isOwned);
  }
}

/// Axial hex coordinate
class _Axial {
  const _Axial(this.q, this.r);
  final int q;
  final int r;
}

/// Convert pixel -> axial (pointy-top)
_Axial _pixelToAxial(Offset p, double r) {
  final q = ( (math.sqrt(3)/3 * p.dx - 1/3 * p.dy) / r );
  final rAx = ( (2/3 * p.dy) / r );
  // cube round
  final x = q;
  final z = rAx;
  final y = -x - z;

  int rx = x.round();
  int ry = y.round();
  int rz = z.round();

  final xDiff = (rx - x).abs();
  final yDiff = (ry - y).abs();
  final zDiff = (rz - z).abs();

  if (xDiff > yDiff && xDiff > zDiff) {
    rx = -ry - rz;
  } else if (yDiff > zDiff) {
    ry = -rx - rz;
  } else {
    rz = -rx - ry;
  }
  return _Axial(rx, rz);
}

/// Convert axial -> polygon points
List<Offset> _hexPolygon(_Axial a, double r) {
  final cx = r * math.sqrt(3) * (a.q + a.r/2);
  final cy = r * 1.5 * a.r;
  final pts = <Offset>[];
  for (int i = 0; i < 6; i++) {
    final angle = math.pi / 180 * (60 * i - 30); // pointy-top
    pts.add(Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)));
  }
  return pts;
}

class _HexPainter extends CustomPainter {
  _HexPainter({
    required this.size,
    required this.r,
    required this.cols,
    required this.rows,
    required this.unlocked,
  });

  final Size size;
  final double r;
  final int cols;
  final int rows;
  final Set<String> unlocked;

  @override
  void paint(Canvas canvas, Size s) {
    // Base grid (black outline)
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withOpacity(0.35);

    // Owned outline (teal)
    final ownedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF12D2C5); // teal-ish

    // Draw full-coverage grid
    // We'll center slightly so the grid starts nicely inside the image.
    final startQ = -cols ~/ 2;
    final startR = -rows ~/ 3; // slight bias to cover top

    for (int rIdx = 0; rIdx < rows; rIdx++) {
      for (int qIdx = 0; qIdx < cols; qIdx++) {
        final a = _Axial(startQ + qIdx, startR + rIdx);
        final poly = _hexPolygon(a, r);

        // Skip if the hex is fully outside our visible rect (fast reject)
        final bounds = _polygonBounds(poly);
        if (!bounds.overlaps(Offset.zero & size)) continue;

        // Base grid outline
        final path = Path()..addPolygon(poly, true);
        canvas.drawPath(path, gridPaint);

        // Owned outline
        final key = '${a.q},${a.r}';
        if (unlocked.contains(key)) {
          canvas.drawPath(path, ownedPaint);
        }
      }
    }
  }

  Rect _polygonBounds(List<Offset> pts) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) {
    return old.r != r ||
        old.cols != cols ||
        old.rows != rows ||
        old.size != size ||
        old.unlocked.length != unlocked.length;
  }
}
