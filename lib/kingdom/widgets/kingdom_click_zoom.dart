// lib/kingdom/widgets/kingdom_click_zoom.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:async';

import '../state.dart' show GameController;
import '../widgets/kingdom_map_painter.dart' show KingdomMapPainter;

class KingdomClickZoom extends StatefulWidget {
  final int mapUnderlayIndex;
  const KingdomClickZoom({super.key, this.mapUnderlayIndex = 0});
  @override
  State<KingdomClickZoom> createState() => _KingdomClickZoomState();
}

class _KingdomClickZoomState extends State<KingdomClickZoom> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _loadAll();
  _overlayController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  _overlayAnimation = CurvedAnimation(parent: _overlayController!, curve: Curves.easeOut);
  _scaleAnimation = Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: _overlayController!, curve: Curves.easeOutBack));
    // Ensure faction cache is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gc = Provider.of<GameController>(context, listen: false);
      gc.updateFactionCache();
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayController?.dispose();
    super.dispose();
  }
  static const _kUnderlay = 'assets/images/map_underlay.png';
  static const _kUnderlay2 = 'assets/images/map_underlay2.png';
  static const _kUnderlay3 = 'assets/images/map_underlay3.png';
  static const _kKeep = 'assets/images/keep.png';
  static const _kShack = 'assets/images/shack.png';

  ui.Image? _underlay;
  ui.Image? _underlay2;
  ui.Image? _underlay3;
  ui.Image? _keep;
  ui.Image? _shack;

  // Hover state for displaying per-faction claim counts
  String? _hoveredKey;
  Map<String, int>? _hoveredCounts;
  Timer? _hoverTimer;
  OverlayEntry? _overlayEntry;
  Offset? _lastPointerGlobal;
  AnimationController? _overlayController;
  Animation<double>? _overlayAnimation;
  Animation<double>? _scaleAnimation;

  bool _showGrid = true;
  bool _showLabels = true;
  final double _tileSize = 26;
  // Per-underlay tweakable transforms (dev adjustments)
  final Map<int, Offset> _underlayOffsets = {0: Offset.zero, 1: Offset.zero, 2: Offset.zero};
  final Map<int, double> _underlayScales = {0: 1.0, 1: 1.0, 2: 1.0};

  Future<ui.Image> _load(String asset) async {
    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _loadAll() async {
    _load(_kUnderlay).then((img) {
      if (mounted) setState(() => _underlay = img);
    });
    _load(_kUnderlay2).then((img) {
      if (mounted) setState(() => _underlay2 = img);
    });
    _load(_kUnderlay3).then((img) {
      if (mounted) setState(() => _underlay3 = img);
    });
    _load(_kKeep).then((img) {
      if (mounted) setState(() => _keep = img);
    });
    _load(_kShack).then((img) {
      if (mounted) setState(() => _shack = img);
    });
  }

  ui.Image? getSelectedUnderlay() {
    switch (widget.mapUnderlayIndex) {
      case 1:
        return _underlay2;
      case 2:
        return _underlay3;
      default:
        return _underlay;
    }
  }

  String _getHexLabelPrefix(int index) {
    switch (index) {
      case 1:
        return 'B';
      case 2:
        return 'C';
      default:
        return 'A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<GameController>();
  final unlocked = gc.unlocked;
    final Map<String, ui.Image> hexIcons = {};
    if (widget.mapUnderlayIndex == 0) {
      if (_shack != null) hexIcons['0,0'] = _shack!;
    }
    // Always show grid and labels for restoration
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _showGrid,
              onChanged: (val) => setState(() => _showGrid = val ?? true),
            ),
            const Text('Show Grid'),
            Checkbox(
              value: _showLabels,
              onChanged: (val) => setState(() => _showLabels = val ?? true),
            ),
            const Text('Show Labels'),
          ],
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final canvasSize = Size(c.maxWidth, c.maxHeight);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.05).round()),
                child: MouseRegion(
                  onHover: (ev) {
                    final localPos = ev.localPosition;
                    _lastPointerGlobal = ev.position;
                    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
                    final r = _tileSize;
                    String? foundKey;
                    for (int q = -10; q <= 10; q++) {
                      for (int r_ = -10; r_ <= 10; r_++) {
                        if ((q).abs() + (r_).abs() + (-q - r_).abs() > 20) continue;
                        final hexCenter = Offset(center.dx + r * (3.0 / 2.0 * q),
                            center.dy + r * (sqrt(3) / 2.0 * q + sqrt(3) * r_));
                        final hexBounds = Rect.fromCircle(center: hexCenter, radius: r);
                        if (hexBounds.contains(localPos)) {
                          foundKey = '$q,$r_';
                          break;
                        }
                      }
                      if (foundKey != null) break;
                    }
                    if (foundKey != _hoveredKey) {
                      _hoverTimer?.cancel();
                      _removeOverlay();
                      _hoveredKey = foundKey;
                      _hoveredCounts = null;
                      if (foundKey != null) {
                        final keyNonNull = foundKey;
                        _hoverTimer = Timer(const Duration(seconds: 2), () async {
                          try {
                            final counts = await gc.fetchTileCounts(widget.mapUnderlayIndex, keyNonNull);
                            if (!mounted) return;
                            _hoveredCounts = Map<String, int>.from(counts);
                            // show floating tooltip near cursor
                            if (_lastPointerGlobal != null) {
                              _insertOverlay(_lastPointerGlobal!, keyNonNull, _hoveredCounts!);
                            }
                          } catch (_) {}
                        });
                      }
                    }
                  },
                  onExit: (_) {
                    _hoverTimer?.cancel();
                    _removeOverlay();
                    setState(() {
                      _hoveredKey = null;
                      _hoveredCounts = null;
                    });
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (details) {
                      // start a 2s timer for long-press tooltip
                      _lastPointerGlobal = details.globalPosition;
                      _hoverTimer?.cancel();
                      _hoverTimer = Timer(const Duration(seconds: 2), () async {
                        // determine tile under the long-press
                        final local = details.localPosition;
                        final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
                        final r = _tileSize;
                        String? foundKey;
                        for (int q = -10; q <= 10; q++) {
                          for (int r_ = -10; r_ <= 10; r_++) {
                            if ((q).abs() + (r_).abs() + (-q - r_).abs() > 20) continue;
                            final hexCenter = Offset(
                              center.dx + r * (3.0 / 2.0 * q),
                              center.dy + r * (sqrt(3) / 2.0 * q + sqrt(3) * r_),
                            );
                            final hexBounds = Rect.fromCircle(center: hexCenter, radius: r);
                            if (hexBounds.contains(local)) {
                              foundKey = '$q,$r_';
                              break;
                            }
                          }
                          if (foundKey != null) break;
                        }
                        if (foundKey != null) {
                          try {
                            final counts = await gc.fetchTileCounts(widget.mapUnderlayIndex, foundKey);
                            if (!mounted) return;
                            _insertOverlay(_lastPointerGlobal!, foundKey, counts);
                          } catch (_) {}
                        }
                      });
                    },
                    onLongPressEnd: (_) {
                      _hoverTimer?.cancel();
                      _removeOverlay();
                    },
                    onTapDown: (details) {
                      _hoverTimer?.cancel();
                      _removeOverlay();
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(details.globalPosition);
                      final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
                      final r = _tileSize;
                      for (int q = -10; q <= 10; q++) {
                        for (int r_ = -10; r_ <= 10; r_++) {
                          if ((q).abs() + (r_).abs() + (-q - r_).abs() > 20) continue;
                          final x = r * (3.0 / 2.0 * q);
                          final y = r * (sqrt(3) / 2.0 * q + sqrt(3) * r_);
                          final hexCenter = Offset(center.dx + x, center.dy + y);
                          final hexBounds = Rect.fromCircle(center: hexCenter, radius: r);
                          if (hexBounds.contains(localPos)) {
                            final key = '$q,$r_';
                            if (unlocked.contains(key)) {
                              // Developer-only unclaim prompt
                              if (kDebugMode) {
                                showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('Unclaim tile?'),
                                    content: Text('Return 1 point and unclaim tile $key?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Unclaim')),
                                    ],
                                  ),
                                ).then((confirmed) {
                                  if (confirmed == true) {
                                    gc.unown(q, r_);
                                    setState(() {});
                                  }
                                });
                              }
                              return;
                            }
                            gc.unlock(q, r_);
                            setState(() {});
                            return;
                          }
                        }
                      }
                    },
                    child: CustomPaint(
                      isComplex: true,
                      willChange: true,
                      size: canvasSize,
                      painter: KingdomMapPainter(
                        unlocked: unlocked,
                        tileSize: _tileSize,
                        maxRadius: 10,
                        showGrid: _showGrid,
                        showLabels: _showLabels,
                        underlay: getSelectedUnderlay(),
                        underlayOffset: _underlayOffsets[widget.mapUnderlayIndex] ?? Offset.zero,
                        underlayScale: _underlayScales[widget.mapUnderlayIndex] ?? 1.0,
                        keep: _keep,
                        shack: null,
                        hexIcons: hexIcons,
                        hexLabelPrefix: _getHexLabelPrefix(widget.mapUnderlayIndex),
                        faction: gc.state.faction.trim().toLowerCase(),
                        hexClaimCounts: const {},
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        // Dev-only underlay tuner
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Tweak underlay'),
                  onPressed: () async {
                    final i = widget.mapUnderlayIndex;
                    final currentOffset = _underlayOffsets[i] ?? Offset.zero;
                    final currentScale = _underlayScales[i] ?? 1.0;
                    await showDialog<void>(
                      context: context,
                      builder: (dctx) {
                        double sx = currentScale;
                        double ox = currentOffset.dx;
                        double oy = currentOffset.dy;
                        return StatefulBuilder(builder: (ctx, setDlgState) {
                          return AlertDialog(
                            title: Text('Tweak underlay $i'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [Text('Scale:'), Expanded(child: Slider(value: sx, min: 0.6, max: 1.6, onChanged: (v) => setDlgState(() => sx = v)))]),
                                Row(children: [Text('Offset X:'), Expanded(child: Slider(value: ox, min: -120, max: 120, onChanged: (v) => setDlgState(() => ox = v)))]),
                                Row(children: [Text('Offset Y:'), Expanded(child: Slider(value: oy, min: -120, max: 120, onChanged: (v) => setDlgState(() => oy = v)))]),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  _underlayOffsets[i] = Offset(ox, oy);
                                  _underlayScales[i] = sx;
                                  setState(() {});
                                  Navigator.of(dctx).pop();
                                },
                                child: const Text('Apply'),
                              ),
                            ],
                          );
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _insertOverlay(Offset globalPos, String tileKey, Map<String, int> counts) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final screen = MediaQuery.of(context).size;
    final boxSize = 104.0;
    double left = globalPos.dx + 12;
    double top = globalPos.dy + 12;
    left = left.clamp(6.0, screen.width - 6.0 - boxSize);
    top = top.clamp(6.0, screen.height - 6.0 - boxSize);

    final entry = OverlayEntry(builder: (ctx) {
      return Positioned(
        left: left,
        top: top,
        child: FadeTransition(
          opacity: _overlayAnimation ?? const AlwaysStoppedAnimation(1.0),
          child: ScaleTransition(
            scale: _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
            child: Material(
              color: Colors.transparent,
              elevation: 12,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: CustomPaint(
                  painter: _DiamondTooltipPainter(counts),
                ),
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(entry);
    _overlayEntry = entry;
    // trigger fade-in
    try {
      _overlayController?.forward(from: 0.0);
    } catch (_) {}
  }

  void _removeOverlay() {
    if (_overlayEntry == null) return;
    final entry = _overlayEntry!;
    // If we have an animation controller, reverse and remove when dismissed
    if (_overlayController != null) {
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          try {
            entry.remove();
          } catch (_) {}
          _overlayEntry = null;
          _overlayController?.removeStatusListener(listener);
        }
      }

      _overlayController!.addStatusListener(listener);
      try {
        _overlayController!.reverse();
      } catch (_) {
        try {
          entry.remove();
        } catch (_) {}
        _overlayEntry = null;
      }
    } else {
      try {
        entry.remove();
      } catch (_) {}
      _overlayEntry = null;
    }
  }
}

class _DiamondTooltipPainter extends CustomPainter {
  final Map<String, int> counts;
  _DiamondTooltipPainter(this.counts);

  static const Map<String, Color> factionColors = {
    'north': Color(0xFF34D399), // teal/green
    'east': Color(0xFFEF4444), // red
    'south': Color(0xFF1565C0), // blue
    'west': Color(0xFFF59E0B), // yellow/orange
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.42; // main diamond half-size
    // ——— Outer beveled diamond (gold frame) ———
    final mainPath = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s, cy)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - s, cy)
      ..close();

    // stronger outer shadow for deeper pop
    canvas.drawShadow(mainPath, Colors.black.withOpacity(0.42), 10.0, false);

    // richer gold frame: multi-stop gradient for warm metallic look
    final framePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - s, cy - s),
        Offset(cx + s, cy + s),
        [Color(0xFF8B5C1A), Color(0xFFFFD27B), Color(0xFFFFF1C9)],
        [0.0, 0.62, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(mainPath, framePaint);

    // inner inset (slightly larger) to enhance rim/bevel
    final inset = s * 0.16;
    final innerPath = Path()
      ..moveTo(cx, cy - (s - inset))
      ..lineTo(cx + (s - inset), cy)
      ..lineTo(cx, cy + (s - inset))
      ..lineTo(cx - (s - inset), cy)
      ..close();

    // light parchment background inside the rim
    final innerBgRect = Rect.fromCenter(center: Offset(cx, cy), width: (s - inset) * 2, height: (s - inset) * 2);
    final innerBgPaint = Paint()
      ..shader = ui.Gradient.linear(innerBgRect.topCenter, innerBgRect.bottomCenter, [Color(0xFFF3EBDC), Color(0xFFFBF7F1)]);
    canvas.drawPath(innerPath, innerBgPaint);

    // subtle inner rim highlight
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(innerPath, rimPaint);

    // subtle inner bevel overlay (light top-left, slight dark bottom-right)
    final bevelPaint = Paint()
      ..shader = ui.Gradient.linear(innerBgRect.topLeft, innerBgRect.bottomRight, [Colors.white.withOpacity(0.08), Colors.black.withOpacity(0.04)])
      ..blendMode = BlendMode.overlay;
    canvas.drawPath(innerPath, bevelPaint);

    // thin separators between quadrants (vertical + horizontal axes) for clearer tile boundaries
    final sepPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    // vertical separator (shorter than full inset to avoid touching rim)
    canvas.drawLine(Offset(cx, cy - (s - inset) + 3.0), Offset(cx, cy + (s - inset) - 3.0), sepPaint);
    // horizontal separator
    canvas.drawLine(Offset(cx - (s - inset) + 3.0, cy), Offset(cx + (s - inset) - 3.0, cy), sepPaint);

    // Draw four inset quadrant tiles (beveled diamonds)
  final innerScale = 0.66; // relative to main diamond (slightly larger tiles)
  final innerSide = s * innerScale; // half-diagonal of inner diamond
  final offsetDist = s * 0.56; // distance from center to inner centers (push out slightly)

  // outlined numbers are painted by drawing a stroked TextPainter first, then the filled one on top.

    void drawInnerDiamond(String factionKey, Offset centerOffset) {
      final color = factionColors[factionKey] ?? Colors.grey;
      final center = Offset(cx + centerOffset.dx, cy + centerOffset.dy);
      final rectSide = innerSide * sqrt(2); // side length of the rounded rect before rotation
      final rect = Rect.fromCenter(center: Offset(0, 0), width: rectSide, height: rectSide);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rectSide * 0.16));

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(pi / 4);

      // deeper drop shadow for each tile
      final shadowRrect = rrect.shift(Offset(2.4, 3.6));
      final shadowPaint = Paint()..color = Colors.black.withOpacity(0.22);
      canvas.drawRRect(shadowRrect, shadowPaint);

      // stronger beveled fill: slightly higher contrast on gradient
      final grad = ui.Gradient.linear(
        Offset(-rectSide / 2, -rectSide / 2),
        Offset(rectSide / 2, rectSide / 2),
        [color.withOpacity(1.0), color.withOpacity(0.70)],
      );
      final fill = Paint()..shader = grad;
      canvas.drawRRect(rrect, fill);

      // pronounced bevel highlight
      final highlight = Paint()
        ..shader = ui.Gradient.linear(Offset(-rectSide / 2, -rectSide / 2), Offset(rectSide / 4, rectSide / 4), [Colors.white.withOpacity(0.36), Colors.white.withOpacity(0.04)])
        ..blendMode = BlendMode.overlay;
      canvas.drawRRect(rrect.deflate(rectSide * 0.02), highlight);

      // dark trim border
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawRRect(rrect, borderPaint);

      // draw the count centered: paint stroke then fill for an engraved look
      final count = counts[factionKey] ?? 0;
      final fontSize = rectSide * 0.40; // slightly larger numbers
      // stroke painter (stronger for engraved contrast)
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, fontSize * 0.14)
        ..color = Colors.black.withOpacity(0.72)
        ..strokeJoin = StrokeJoin.round;
      final spanStroke = TextSpan(text: '$count', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, foreground: strokePaint));
      final tpStroke = TextPainter(text: spanStroke, textDirection: TextDirection.ltr);
      tpStroke.layout();
      tpStroke.paint(canvas, Offset(-tpStroke.width / 2, -tpStroke.height / 2 + rectSide * 0.02));

      // fill painter on top with a tiny drop-shadow translate to suggest depth
      final tpFill = TextPainter(text: TextSpan(text: '$count', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)), textDirection: TextDirection.ltr);
      tpFill.layout();
      // subtle shadow behind number (drawn by painting slightly offset translucent black)
      final shadowOffset = Offset(0.8, 1.0);
      tpFill.paint(canvas, Offset(-tpFill.width / 2 + shadowOffset.dx, -tpFill.height / 2 + rectSide * 0.02 + shadowOffset.dy));
      // main fill
      tpFill.paint(canvas, Offset(-tpFill.width / 2, -tpFill.height / 2 + rectSide * 0.02));

      canvas.restore();
    }

    // north, east, south, west inner centers
    drawInnerDiamond('north', Offset(0, -offsetDist));
    drawInnerDiamond('east', Offset(offsetDist, 0));
    drawInnerDiamond('south', Offset(0, offsetDist));
    drawInnerDiamond('west', Offset(-offsetDist, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
