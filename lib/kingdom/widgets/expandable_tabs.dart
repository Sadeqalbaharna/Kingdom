import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import 'enemies_tab.dart';
import 'hero_tab.dart';
import 'armors_tab.dart';
import 'voucher_tab.dart';

class ExpandableTabs extends StatefulWidget {
  const ExpandableTabs({super.key});

  @override
  State<ExpandableTabs> createState() => _ExpandableTabsState();
}

class _ExpandableTabsState extends State<ExpandableTabs> with TickerProviderStateMixin {
  final _dragCtrl = DraggableScrollableController();
  late final TabController _tabCtrl;

  // sizes as fractions of screen height
  static const double kMin = 0.05;  // collapsed (even lower)
  static const double kInit = 0.07; // initial
  static const double kMax = 0.8;  // expanded (tweak to taste)

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this); // PATCH: Match number of tabs/children
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    try {
      await _dragCtrl.animateTo(kMax,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    } catch (_) {}
  }

  Future<void> _collapse() async {
    try {
      await _dragCtrl.animateTo(kMin,
          duration: const Duration(milliseconds: 220), curve: Curves.easeInCubic);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // ensure GameController exists above (AppShell provides it)
    context.watch<GameController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardMaxWidth = screenWidth < 420 ? screenWidth - 16 : 400.0;
    return DraggableScrollableSheet(
      controller: _dragCtrl,
      initialChildSize: kInit,
      minChildSize: kMin,
      maxChildSize: kMax,
      snap: false,
      expand: true,
      builder: (ctx, scrollCtrl) {
        return Center(
          child: Container(
            width: cardMaxWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Tab labels (acts like the “bottom bar” when collapsed)
                    Builder(
                      builder: (tabContext) => TabBar(
                        controller: _tabCtrl,
                        isScrollable: false,
                        labelColor: Colors.teal[700],
                        unselectedLabelColor: Colors.teal[200],
                        indicatorColor: Colors.tealAccent,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        onTap: (i) {
                          debugPrint('Tab tapped: $i');
                          // Ensure the tab actually switches
                          if (_tabCtrl.index != i) {
                            _tabCtrl.animateTo(i);
                          }
                          // tapping a tab expands the sheet
                          _expand();
                        },
                        tabs: const [
                          Tab(text: 'Vouchers'),
                          Tab(text: 'Enemies'),
                          Tab(text: 'Hero'),
                          Tab(text: 'Armor'),
                        ],
                      ),
                    ),
                    // Tab content (scrollable with the sheet)
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: const [
                          VoucherTab(),
                          EnemiesTab(),
                          HeroTab(),
                          ArmorsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
                // Compact floating expand/collapse button at top right
                Positioned(
                  top: 8,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (_dragCtrl.isAttached) {
                          final isCollapsed = _dragCtrl.size <= kMin + 0.01;
                          if (isCollapsed) {
                            _expand();
                          } else {
                            _collapse();
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          (!_dragCtrl.isAttached || _dragCtrl.size <= kMin + 0.01)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.teal[300],
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Makes tab content cooperate with DraggableScrollableSheet scrolling.
