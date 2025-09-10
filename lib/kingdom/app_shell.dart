import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state.dart';
import 'widgets/castle_header_card.dart';
import 'widgets/kingdom_click_zoom.dart';
import 'widgets/expandable_tabs.dart';
import 'widgets/special_popup_overlay.dart';
// map_progress_bar removed in favor of header-mounted ProgressNodes

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ChangeNotifierProvider<GameController>(
      create: (_) => GameController(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 183, 231, 163),
            body: SafeArea(
              child: Stack(
                children: [
                  // Main content
                  Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 366.0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                            child: CastleHeaderCard(),
                          ),
                        ),
                      ),
                      // Map underlay chooser placed above the map (left-to-right)
                      Builder(builder: (ctx) {
                        ],
                      ),
                    ),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: MapUnderlayChooser(
                            selectedIndex: gc.mapUnderlayIndex,
                            unlockedCount: totalClaimed,
                            onChoose: (i) => gc.setMapUnderlayIndex(i),
                          ),
                        );
                      }),
                      Expanded(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: KingdomClickZoom(mapUnderlayIndex: Provider.of<GameController>(context).mapUnderlayIndex),
                        ),
                      ),
                    ],
                  ),
                  // Special popup overlay
                  const SpecialPopupOverlay(),
                  // ExpandableTabs overlays at the bottom
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: const ExpandableTabs(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    /// Wrap whole app in a phone-like frame
    return Center(
      child: SizedBox(
        width: 390, // typical phone width
        height: 844, // typical phone height
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.black,
            child: app,
          ),
        ),
      ),
    );
  }
}

// KingdomClickZoom is now placed directly in the Card above; chooser is rendered in the Column
