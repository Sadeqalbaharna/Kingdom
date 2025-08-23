@override
Widget build(BuildContext context) {
  final ctrl = context.watch<GameController>();
  final unlocked = ctrl.unlocked.map((k){
    final parts = k.split(',');
    return Axial(int.parse(parts[0]), int.parse(parts[1]));
  }).toSet();

  final painterReady = _grass!=null && _grassActive!=null && _keep!=null;

  // Responsive board: square that fits the screen width, capped for tablets/desktop
  final w = MediaQuery.of(context).size.width;
  final isSmall = w < 420;
  final boardSide = w.clamp(280.0, 640.0); // mobile-friendly square
  final canvasSize = Size(boardSide, boardSide);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Icon(Icons.fort_outlined),
        const SizedBox(width: 8),
        const Text('Kingdom Map', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          tooltip: 'Toggle grid',
          onPressed: () => setState(() => _showGrid = !_showGrid),
          icon: Icon(_showGrid ? Icons.grid_off : Icons.grid_on),
        ),
        const SizedBox(width: 8),
        Text('${unlocked.length} tiles'),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => context.read<GameController>().resetUnlocked(), child: const Text('Reset')),
      ]),
      const SizedBox(height: 8),

      // Zoom + pan
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          // give a little breathing room on small phones
          height: boardSide + (isSmall ? 24 : 48),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
          child: InteractiveViewer(
            minScale: 0.6,
            maxScale: 3.6,
            boundaryMargin: const EdgeInsets.all(320),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                if (!painterReady) return;
                // account for padding below
                final local = d.localPosition - const Offset(16, 16);
                final ax = pixelToAxial(local, canvasSize);
                context.read<GameController>().unlock(ax.x, ax.y);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                // IMPORTANT: don’t build CustomPaint with a null painter
                child: painterReady
                    ? CustomPaint(
                        isComplex: true,
                        willChange: true,
                        painter: KingdomMapPainter(
                          unlocked: unlocked,
                          tileSize: _tileSize,
                          maxRadius: 10,
                          showGrid: _showGrid,
                          grass: _grass!,
                          grassActive: _grassActive!,
                          keep: _keep!,
                        ),
                        size: canvasSize,
                      )
                    : SizedBox( // placeholder avoids the assertion
                        width: canvasSize.width,
                        height: canvasSize.height,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 8),
      Row(children: [
        const Text('Tile size'),
        Expanded(
          child: Slider(
            min: 16, max: 36,
            value: _tileSize,
            onChanged: (v) => setState(() => _tileSize = v),
          ),
        ),
      ]),
      Text('Tap tiles to unlock. Keep stays perfectly centered.',
          style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
