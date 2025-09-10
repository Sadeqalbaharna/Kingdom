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
// growth_tab.dart removed / not present in repo; using an inline placeholder below

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
  // We have 6 tabs visually but GrowthTab is not present as a file; keep 6 and use a placeholder
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
                    child: const CastleHeaderCard(),
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
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        const ArmyTab(),
                        const EnemiesTab(),
                        const HeroTab(),
                        const ScandalsTab(),
                        const ArmorsTab(),
                        // GrowthTab file missing; use inline placeholder to avoid missing import
                        const _GrowthPlaceholder(),
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

// KingdomClickZoom is now placed directly in the Card above; chooser is rendered in the Column

class _GrowthPlaceholder extends StatelessWidget {
  const _GrowthPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.eco, size: 48, color: Colors.green),
            SizedBox(height: 12),
            Text('Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Growth details are not available in this build.'),
          ],
        ),
      ),
    );
  }
}
