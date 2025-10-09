

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'widgets/voucher_tab.dart';
import 'widgets/hero_tab.dart';
// import 'widgets/armors_tab.dart';
import 'widgets/marketplace_tab.dart';
import 'widgets/castle_header_card.dart';
import 'widgets/kingdom_click_zoom.dart';
import 'widgets/special_popup_overlay.dart';
// progress_nodes import removed; using MapProgressBar now
import 'widgets/map_progress_bar.dart';
import 'state.dart';
import 'package:provider/provider.dart';
// map_progress_bar removed in favor of header-mounted ProgressNodes

// Row with Show Grid, map selector, Show Labels
class _MapAndCheckboxRow extends StatefulWidget {
  @override
  State<_MapAndCheckboxRow> createState() => _MapAndCheckboxRowState();
}

class _MapAndCheckboxRowState extends State<_MapAndCheckboxRow> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map selector and checkboxes stacked below
          Row(
            children: [
              // Show Grid checkbox (left)
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 2),
                child: SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Consumer<GameController>(
                        builder: (context, ctrl, _) => Checkbox(
                          value: ctrl.showGrid,
                          onChanged: (v) => ctrl.setShowGrid(v ?? true),
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Text('Show Grid', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              // Map selector (center)
              Expanded(
                child: Center(
                  child: Consumer<GameController>(
                    builder: (context, ctrl, _) {
                    // Re-enable gating: 20 tiles for map 1, 40 for map 2
                    final totalClaimed = ctrl.totalClaimedTiles();
                    final maps = [
                      {
                        'label': 'Town of Departure',
                        'img': 'assets/images/map_underlay.png',
                        'unlocked': true,
                        'lockMsg': '',
                      },
                      {
                        'label': 'The Coast',
                        'img': 'assets/images/map_underlay2.png',
                        'unlocked': totalClaimed >= 20,
                        'lockMsg': 'Unlocks at 20 tiles',
                      },
                      {
                        'label': 'Arid Wilderness',
                        'img': 'assets/images/map_underlay3.png',
                        'unlocked': totalClaimed >= 40,
                        'lockMsg': 'Unlocks at 40 tiles',
                      },
                    ];
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F8F6),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(maps.length, (i) {
                                final m = maps[i];
                                final isSelected = ctrl.mapUnderlayIndex == i;
                                final unlocked = m['unlocked'] as bool;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (unlocked) {
                                        ctrl.setMapUnderlayIndex(i);
                                      } else {
                                        final msg = (m['lockMsg'] as String?)?.trim();
                                        if (msg != null && msg.isNotEmpty) {
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
                                          );
                                        }
                                      }
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isSelected ? Colors.teal : Colors.grey[300]!,
                                              width: isSelected ? 1.0 : 0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            color: unlocked ? Colors.white : Colors.grey[200],
                      boxShadow: isSelected
                        ? [BoxShadow(color: Colors.teal.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                        : [],
                                          ),
                                          child: unlocked
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Image.asset(m['img'] as String, fit: BoxFit.cover),
                                                )
                                              : Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Image.asset(
                                                        m['img'] as String,
                                                        fit: BoxFit.cover,
                                                        color: Colors.white.withValues(alpha: 0.7),
                                                        colorBlendMode: BlendMode.modulate,
                                                      ),
                                                    ),
                                                    const Center(
                                                      child: Icon(Icons.lock, size: 10, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                        const SizedBox(height: 0),
                                        SizedBox(
                                          width: 44,
                                          child: Text(
                                            m['label'] as String,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                              color: unlocked ? (isSelected ? Colors.teal[900] : Colors.black87) : Colors.grey[400],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ),
              ),
              // Show Labels checkbox (right) - debug only with red dot indicator
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2),
                  child: SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // tiny red dot to mark debug feature
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Consumer<GameController>(
                          builder: (context, ctrl, _) => Checkbox(
                            value: ctrl.showHexLabels,
                            onChanged: (v) => ctrl.setShowHexLabels(v ?? true),
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Text('Show Labels', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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

  int _selectedIndex = 0;

  static Widget dashboardPage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardMaxWidth = screenWidth < 420 ? screenWidth - 16 : 400.0;
    return Column(
      children: [
        // Header with extra padding and shadow
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeaderHeight = constraints.maxHeight;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeaderHeight,
                    minWidth: cardMaxWidth - 8,
                    maxWidth: cardMaxWidth - 8,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: CastleHeaderCard(state: Provider.of<GameController>(context, listen: false).state),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
  // Map selector and checkboxes row (single instance)
  const SizedBox(height: 10),
  _MapAndCheckboxRow(),
        // Map progress bar under the unlock buttons and above the map
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: SizedBox(
            height: 36,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Consumer<GameController>(
                  builder: (context, ctrl, _) {
                    final total = ctrl.totalClaimedTiles();
                    final mapIndex = ctrl.mapUnderlayIndex; // 0,1,2
                    int segmentStart = 1;
                    if (mapIndex == 1) segmentStart = 21;
                    if (mapIndex == 2) segmentStart = 41;
                    // Compute filled nodes within this 20-step segment
                    int filled;
                    if (mapIndex == 0) {
                      filled = total.clamp(0, 20);
                    } else if (mapIndex == 1) {
                      filled = (total - 20).clamp(0, 20);
                    } else {
                      filled = (total - 40).clamp(0, 20);
                    }
                    return MapProgressBar(
                      totalNodes: 20,
                      filledNodes: filled,
                      startStep: segmentStart,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Map label centered right above the map
        Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Consumer<GameController>(
            builder: (context, ctrl, _) {
              final label = () {
                switch (ctrl.mapUnderlayIndex) {
                  case 1:
                    return 'The Coast';
                  case 2:
                    return 'Arid Wilderness';
                  default:
                    return 'Town of Departure';
                }
              }();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),
        // Map area: visually separated card with shadow
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.only(top: 0.0, bottom: 5, left: 5, right: 5),
            child: Consumer<GameController>(
              builder: (context, ctrl, _) => Container(
                key: ValueKey<String>('mapcard-${ctrl.mapUnderlayIndex}')
                ,decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  key: ValueKey<String>('iv-${ctrl.mapUnderlayIndex}')
                  ,minScale: 0.7,
                  maxScale: 2.5,
                  panEnabled: true,
                  child: KingdomClickZoom(
                    key: ValueKey<int>(ctrl.mapUnderlayIndex),
                    mapUnderlayIndex: ctrl.mapUnderlayIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> get _pages => [
    Builder(builder: dashboardPage),
    const VoucherTab(),
    const HeroTab(),
    const MarketplaceTab(),
  ];

  @override
  Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final cardMaxWidth = screenWidth < 420 ? screenWidth - 16 : 400.0;
     return Scaffold(
       // Subtle background gradient for a modern look
       body: Container(
         decoration: const BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [Color(0xFFD0F5C8), Color(0xFFE8F8F2), Color(0xFFD0F5C8)],
           ),
         ),
         child: SafeArea(
           child: Stack(
          children: [
            // Top content area (card with header + map), constrained above the bottom nav
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Leave room for BottomNavigationBar + margins so content has bounded height
              bottom: kBottomNavigationBarHeight + 16,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: cardMaxWidth,
                    height: double.infinity, // ensure bounded height for Column with Expanded
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 182, 255, 99).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: _pages[_selectedIndex],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom navigation bar constrained to card width
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: cardMaxWidth,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 182, 255, 99).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 0),
                    child: BottomNavigationBar(
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.dashboard, size: 26), label: 'Home'),
                      BottomNavigationBarItem(icon: Icon(Icons.card_giftcard, size: 26), label: 'Vouchers'),
                      BottomNavigationBarItem(icon: Icon(Icons.person, size: 26), label: 'Hero'),
                      BottomNavigationBarItem(icon: Icon(Icons.storefront, size: 26), label: 'Market'),
                    ],
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: Colors.teal[700],
                    unselectedItemColor: Colors.teal[200],
                    backgroundColor: Colors.white,
                    elevation: 0,
                    showUnselectedLabels: true,
                    selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: TextStyle(fontSize: 11),
                    iconSize: 22,
                    landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
                    ),
                  ),
                ),
              ),
            ),
            const SpecialPopupOverlay(),
          ],
        ),
      ),
    ),
  );
  }
}

// KingdomClickZoom is now placed directly in the Card above; chooser is rendered in the Column
