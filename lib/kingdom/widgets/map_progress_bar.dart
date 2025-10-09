import 'dart:async';
import 'package:flutter/material.dart';
import '../rewards.dart';

/// Simple model describing each progress node. The [active] field, if non-null,
/// overrides the filledNodes count; otherwise the MapProgressBar uses the
/// numeric [filledNodes] to determine active state.
class MapProgressNode {
  final String id;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool? active;

  MapProgressNode({required this.id, this.tooltip, this.onTap, this.active});
}

class MapProgressBar extends StatefulWidget {
  /// Number of nodes considered filled (used when individual nodes don't
  /// specify their own [active] value).
  final int filledNodes; // 0..totalNodes

  /// Total nodes to render when [nodes] is null. Ignored when [nodes] is provided.
  final int totalNodes;

  /// Optional per-node configuration. If provided, its length defines the total
  /// nodes and each node's tooltip/onTap/active can be set individually.
  final List<MapProgressNode>? nodes;

  /// 1-based starting step number to display and to pick tooltip content from
  /// the global reward map (e.g., 1 for steps 1–20, 21 for steps 21–40).
  final int startStep;

  const MapProgressBar({
    super.key,
    this.filledNodes = 0,
    this.totalNodes = 20,
    this.nodes,
    this.startStep = 1,
  });

  @override
  State<MapProgressBar> createState() => _MapProgressBarState();
}

class _MapProgressBarState extends State<MapProgressBar> {
  final List<GlobalKey> _keys = [];
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  List<MapProgressNode> _buildDefaultNodes(int count) {
    final List<String> rewards = List.generate(60, (i) => tooltipForStep(i + 1));

    // Determine slice based on startStep
    final int start = (widget.startStep <= 0) ? 1 : widget.startStep;
  final int maxIndex = rewards.length; // 60
    return List.generate(count, (i) {
      final globalStep = start + i; // absolute step number (1..60)
      String? tip;
      if (globalStep >= 1 && globalStep <= maxIndex) {
        tip = rewards[globalStep - 1];
      } else {
        tip = 'Progress $globalStep';
      }
      return MapProgressNode(id: 'node_$globalStep', tooltip: tip);
    });
  }

  void _hideOverlay({bool immediate = false}) {
    _hideTimer?.cancel();
    if (immediate) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      try {
        _overlayEntry?.remove();
      } catch (_) {}
      _overlayEntry = null;
    });
  }

  void _showOverlay(int index, String title, String message) {
    _hideTimer?.cancel();
    _overlayEntry?.remove();

    // Compute target rect in global coordinates
    final ctx = _keys[index].currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final targetRect = topLeft & box.size;

    _overlayEntry = OverlayEntry(
      builder: (bctx) {
        final screenSize = MediaQuery.of(bctx).size;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: CustomSingleChildLayout(
              delegate: _TooltipPositionDelegate(targetRect: targetRect, margin: 8.0),
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                child: Container(
                  constraints: BoxConstraints(
                    // Keep within screen with a margin
                    maxWidth: screenSize.width - 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(message, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide after a short delay
    _hideTimer = Timer(const Duration(seconds: 3), () => _hideOverlay(immediate: true));
  }

  @override
  Widget build(BuildContext context) {
  final int count = widget.nodes?.length ?? widget.totalNodes;
  final nodes = widget.nodes ?? _buildDefaultNodes(count);
  while (_keys.length < count) {
    _keys.add(GlobalKey());
  }

    List<Widget> children = List.generate(count, (i) {
  final nodeConfig = nodes[i];
      final bool isBig = ((i + 1) % 5 == 0);
      final bool isActive = nodeConfig.active ?? (i < widget.filledNodes);
  final int displayedStep = widget.startStep + i; // absolute step number

      Widget circle = Transform.rotate(
        angle: 3.14159 / 4, // 45 degrees in radians (π/4)
        child: Container(
          width: isBig ? 14 : 8,
          height: isBig ? 14 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.black26, width: isBig ? 2 : 1),
          ),
        ),
      );

      // Wrap with tooltip-like overlay using CompositedTransform
      final tooltipMsg = nodeConfig.tooltip;
      Widget wrapped = KeyedSubtree(
        key: _keys[i],
        child: MouseRegion(
          onEnter: (_) {
            if (tooltipMsg != null && tooltipMsg.isNotEmpty) {
              _showOverlay(i, 'Step $displayedStep', tooltipMsg);
            }
          },
          onExit: (_) => _hideOverlay(),
          cursor: (nodeConfig.onTap != null || (tooltipMsg != null && tooltipMsg.isNotEmpty))
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (nodeConfig.onTap != null) {
                nodeConfig.onTap!();
                return;
              }
              if (tooltipMsg != null && tooltipMsg.isNotEmpty) {
                _showOverlay(i, 'Step $displayedStep', tooltipMsg);
              }
            },
            child: circle,
          ),
        ),
      );

      return wrapped;
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  final Rect targetRect;
  final double margin;

  _TooltipPositionDelegate({required this.targetRect, this.margin = 8.0});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Child can be any size up to screen width minus margins; height unconstrained.
    return BoxConstraints.loose(Size(constraints.maxWidth - margin * 2, constraints.maxHeight - margin * 2));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Prefer placing the tooltip above the target; if not enough space, place below.
    final double aboveY = targetRect.top - childSize.height - margin;
    final bool fitsAbove = aboveY >= margin;
    final double belowY = targetRect.bottom + margin;
    final bool fitsBelow = belowY + childSize.height <= size.height - margin;
    double dy;
    if (fitsAbove) {
      dy = aboveY;
    } else if (fitsBelow) {
      dy = belowY;
    } else {
      // Clamp vertically centered around target if neither fully fits
      dy = (targetRect.center.dy - childSize.height / 2).clamp(margin, size.height - childSize.height - margin);
    }

    // Center horizontally over the target, clamped to screen bounds
    double dx = (targetRect.center.dx - childSize.width / 2).clamp(margin, size.width - childSize.width - margin);
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _TooltipPositionDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.margin != margin;
  }
}
