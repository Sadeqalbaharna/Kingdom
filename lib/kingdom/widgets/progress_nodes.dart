import 'package:flutter/material.dart';

/// A single node description.
class ProgressNode {
  final String id; // developer-friendly id or label
  final String tooltip; // text shown on hover / click
  final bool active; // visual state
  final VoidCallback? onTap; // optional click handler

  ProgressNode({required this.id, required this.tooltip, this.active = false, this.onTap});
}

/// A horizontal row of small circular nodes with a label above.
///
/// Usage: construct a list of [ProgressNode] where you can provide the tooltip text
/// for each node from the code side. Hover shows the tooltip (desktop/web) and
/// click will either call the node's [onTap] or show a dialog with the tooltip.
class ProgressNodes extends StatelessWidget {
  final String label;
  final List<ProgressNode> nodes;
  final double nodeSize; // base (small) node diameter
  final double spacing;
  final int bigEvery; // make every Nth node bigger
  final double bigScale; // scale multiplier for big node

  const ProgressNodes({
    super.key,
    required this.label,
    required this.nodes,
    this.nodeSize = 8.0,
    this.spacing = 8.0,
    this.bigEvery = 5,
    this.bigScale = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(nodes.length, (i) {
                final node = nodes[i];
                final isBig = bigEvery > 0 && ((i + 1) % bigEvery == 0);
                return Padding(
                  padding: EdgeInsets.only(right: i == nodes.length - 1 ? 0 : spacing),
                  child: Tooltip(
                    message: node.tooltip,
                    preferBelow: false,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (node.onTap != null) return node.onTap!();
                          // default behavior: show dialog with tooltip text
                          showDialog<void>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: Text(node.id),
                              content: Text(node.tooltip),
                              actions: [TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close'))],
                            ),
                          );
                        },
                        child: _buildNode(context, node, isBig),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNode(BuildContext context, ProgressNode node, bool isBig) {
    // base small diameter
    final base = nodeSize;
    final size = isBig ? base * bigScale : base;

    if (node.active) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.green[500],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: isBig ? 2.0 : 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: isBig ? 6 : 4, offset: const Offset(0, 2))],
        ),
      );
    }

    // Inactive big nodes have a subtle ring to indicate major milestone
    if (isBig) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[400]!, width: 1.6),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Center(
          child: Container(
            width: base * 0.8,
            height: base * 0.8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    // regular small inactive node
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}
