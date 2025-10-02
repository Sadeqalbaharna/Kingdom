// ...existing code...
import 'package:flutter/material.dart';
import '../auth_service.dart';
// Removed kIsWeb/html usage to keep this screen cross-platform

class FactionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const FactionScreen({super.key, required this.onComplete});

  @override
  State<FactionScreen> createState() => _FactionScreenState();
}

class _FactionScreenState extends State<FactionScreen> {
  final _auth = AuthService();
  String? _picked;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setFaction(_picked!);
      await Future.delayed(const Duration(milliseconds: 300));
      // Notify and pop this step to return control to the flow
      try { widget.onComplete(); } catch (_) {}
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final factions = [
      {
        'key': 'North',
        'name': 'Verdant Republic of Thornmere',
  'sigil': 'assets/images/Sigils/north.png',
        'blurb': 'Beyond the mists and ancient oaks lies Thornmere, a republic of druids, hunters, and mystics. Their council of circles rules by consensus under the whispering Heartwood, and every citizen is both guardian and guest of the forest. Those who choose Thornmere pledge to walk lightly, speak wisely, and carry secrets like treasures.'
      },
      {
        'key': 'East',
        'name': 'Emberborn Dominion of Drakos Forge',
  'sigil': 'assets/images/Sigils/east.png',
        'blurb': 'Among the mountains where dragons once roared, the Emberborn Dominion stands unbroken. Its clans unite under the Ashen Crown, hammering steel and spirit alike in the fires of their forges. Their rulers are chosen by trial, their strength proven in flame. To walk with Drakos is to wield loyalty like a weapon and laughter like a shield.'
      },
      {
        'key': 'South',
        'name': 'Seafaring Federation of Nerathis',
  'sigil': 'assets/images/Sigils/south.png',
        'blurb': 'Across the storm-swept isles lies Nerathis, a federation of captains, traders, and wanderers bound by the tides. Each island governs itself, yet all are tethered by the Compass—a relic that ensures no sailor is ever truly lost. Nerathians prize freedom, wit, and a daring spirit; fortune favors those bold enough to claim it.'
      },
      {
        'key': 'West',
        'name': 'Sun-Crowned Kingdom of Solvarra',
  'sigil': 'assets/images/Sigils/west.png',
        'blurb': 'Where the plains blaze beneath endless skies, the golden kingdom of Solvarra rises, radiant and unbowed. Its people are taught from birth to honor the cycle of dawn and dusk, their monarch crowned beneath the eternal sun. To stand with Solvarra is to lead with pride, shine with purpose, and defend the Solar Flame at all costs.'
      },
    ];
    final byKey = {for (var f in factions) f['key']: f};
    final size = 390.0;
    return Center(
      child: SizedBox(
        width: size,
        height: 844,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            appBar: AppBar(title: const Text('Choose Faction')),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: const Offset(0, -160), // Move up by 160px (2.5 inches)
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          const edgePad = 24.0;
                          const sigilWidth = 140.0;
                          final leftX = edgePad;
                          final rightX = width - edgePad - sigilWidth;
                          final centerX = (width - sigilWidth) / 2;
                          return SizedBox(
                            width: width,
                            height: 400, // Increased to 400 for even more space below
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: centerX,
                                  child: _FactionSigil(
                                    name: byKey['North']!['name'] as String,
                                    image: byKey['North']!['sigil'] as String,
                                    blurb: byKey['North']!['blurb'] as String,
                                    selected: _picked == 'North',
                                    onTap: () => setState(() => _picked = 'North'),
                                  ),
                                ),
                                Positioned(
                                  top: 120,
                                  left: rightX,
                                  child: _FactionSigil(
                                    name: byKey['East']!['name'] as String,
                                    image: byKey['East']!['sigil'] as String,
                                    blurb: byKey['East']!['blurb'] as String,
                                    selected: _picked == 'East',
                                    onTap: () => setState(() => _picked = 'East'),
                                  ),
                                ),
                                Positioned(
                                  top: 240,
                                  left: centerX,
                                  child: _FactionSigil(
                                    name: byKey['South']!['name'] as String,
                                    image: byKey['South']!['sigil'] as String,
                                    blurb: byKey['South']!['blurb'] as String,
                                    selected: _picked == 'South',
                                    onTap: () => setState(() => _picked = 'South'),
                                  ),
                                ),
                                Positioned(
                                  top: 120,
                                  left: leftX,
                                  child: _FactionSigil(
                                    name: byKey['West']!['name'] as String,
                                    image: byKey['West']!['sigil'] as String,
                                    blurb: byKey['West']!['blurb'] as String,
                                    selected: _picked == 'West',
                                    onTap: () => setState(() => _picked = 'West'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_error != null)
                    Positioned(
                      bottom: 90,
                      left: 0,
                      right: 0,
                      child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: ElevatedButton(
                      onPressed: _busy || _picked == null ? null : _save,
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}


// --- Faction Sigil Widget ---
class _FactionSigil extends StatefulWidget {
  final String name;
  final String image;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;
  const _FactionSigil({required this.name, required this.image, required this.blurb, required this.selected, required this.onTap});

  @override
  State<_FactionSigil> createState() => _FactionSigilState();
}

class _FactionSigilState extends State<_FactionSigil> {
  void _handleTap() {
    widget.onTap();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 390,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(widget.image, width: 96, height: 96, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 20),
                  Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Text(widget.blurb, style: const TextStyle(fontSize: 14, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sigil = Container(
      decoration: BoxDecoration(
        border: Border.all(color: widget.selected ? Colors.teal : Colors.grey[300]!, width: widget.selected ? 3 : 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.selected
            ? [BoxShadow(color: Colors.teal.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 2)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(widget.image, width: 72, height: 72, fit: BoxFit.contain),
      ),
    );

    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sigil,
            const SizedBox(height: 8),
            Text(widget.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.selected ? Colors.teal : Colors.black), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
