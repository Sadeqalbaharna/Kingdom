import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class SpecialPopupOverlay extends StatefulWidget {
  const SpecialPopupOverlay({super.key});

  @override
  State<SpecialPopupOverlay> createState() => _SpecialPopupOverlayState();
}

class _SpecialPopupOverlayState extends State<SpecialPopupOverlay> {
  Timer? _timer;
  DateTime? _lastShown;

  @override
  void didUpdateWidget(covariant SpecialPopupOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkPopup();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPopup();
  }

  void _checkPopup() {
    final controller = Provider.of<GameController>(context, listen: false);
    _checkPopupFor(controller);
  }

  void _checkPopupFor(GameController controller) {
    final hasPopup = controller.specialPopupAsset != null || controller.specialMessage != null;
    if (hasPopup) {
      final ts = controller.specialPopupTimestamp;
      final isNew = ts != null && ts != _lastShown;
      if (_timer == null || isNew) {
        // Restart the timer for a new popup
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          controller.clearSpecialPopup();
          if (!mounted) {
            _timer = null;
            return;
          }
          setState(() {
            _timer = null;
          });
        });
        _lastShown = ts;
      }
    } else {
      // No popup showing; ensure timer is cleared
      _timer?.cancel();
      _timer = null;
      _lastShown = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, controller, child) {
        // Start/refresh auto-dismiss timer whenever provider emits a new popup
        _checkPopupFor(controller);
        List<Widget> stackChildren = [];
        if (controller.specialPopupAsset != null || controller.specialMessage != null) {
          stackChildren.add(
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Stack(
                  children: [
                    // Close (X) button in the top-right corner
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            controller.clearSpecialPopup();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.close, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.specialPopupAsset != null)
                            Image.asset(
                              controller.specialPopupAsset!,
                              width: 360,
                              height: 360,
                              fit: BoxFit.contain,
                            ),
                          const SizedBox(height: 20),
                          if (controller.specialMessage != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black26,
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    controller.specialMessage!,
                                    style: const TextStyle(fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      controller.clearSpecialPopup();
                                    },
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // DEV: Show which hex is special
        if (controller.specialHexQ != null && controller.specialHexR != null) {
          String prefix;
          switch (controller.currentUnderlay) {
            case 1:
              prefix = 'B';
              break;
            case 2:
              prefix = 'C';
              break;
            default:
              prefix = 'A';
          }
          stackChildren.add(
            Positioned(
              top: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Special Hex: $prefix${controller.specialHexQ},${controller.specialHexR}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          );
        }
        return Stack(children: stackChildren);
      },
    );
  }
}

class MapUnderlayChooser extends StatelessWidget {
  final void Function(int) onChoose;
  final int selectedIndex;
  final int unlockedCount;
  const MapUnderlayChooser({super.key, required this.onChoose, required this.selectedIndex, required this.unlockedCount});

  @override
  Widget build(BuildContext context) {
    // Render the chooser left-to-right and centered horizontally above the map
    const List<String> titles = [
      'Town of Departure',
      'The Coast',
      'Arid Wilderness',
    ];

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final title = titles[i];
          bool isLocked = (i == 1 && unlockedCount < 20) || (i == 2 && unlockedCount < 40);
          return GestureDetector(
            onTap: isLocked ? null : () => onChoose(i),
            child: Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selectedIndex == i ? Colors.blueAccent : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/map_underlay${i == 0 ? '' : i + 1}.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                        if (isLocked)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: const Icon(Icons.lock, color: Colors.white, size: 20),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 110,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
