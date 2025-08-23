import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state.dart';
import 'widgets/castle_header_card.dart';
import 'widgets/kingdom_click_zoom.dart';
import 'widgets/army_tab.dart';
import 'widgets/enemies_tab.dart';
import 'widgets/hero_tab.dart';
import 'widgets/scandals_tab.dart';
import 'widgets/armors_tab.dart';
import 'widgets/growth_tab.dart';

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
          final ctrl = context.watch<GameController>();

          return Scaffold(
            backgroundColor: const Color(0xFF0B1320),
            body: SafeArea(
              child: Column(
                children: [
                  /// Castle header card (needs GameState)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: CastleHeaderCard(state: ctrl.state),
                  ),

                  /// Map area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const KingdomClickZoom(), // reads from provider internally
                      ),
                    ),
                  ),

                  /// Tabs
                  Container(
                    color: Colors.black12,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: "Army"),
                        Tab(text: "Enemies"),
                        Tab(text: "Hero"),
                        Tab(text: "Scandals"),
                        Tab(text: "Armors"),
                        Tab(text: "Growth"),
                      ],
                    \] x ),
                  ),o
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        ArmyTab(),
                        EnemiesTab(),
                        HeroTab(),
                        ScandalsTab(),
                        ArmorsTab(),
                        GrowthTab(),
                      ],
                    ),
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
