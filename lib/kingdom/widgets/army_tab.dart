import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../utils.dart';

class ArmyTab extends StatelessWidget {
  const ArmyTab({super.key});

  Future<void> _editIncome(BuildContext context, int current) async {
    final ctrl = context.read<GameController>();
    final c = TextEditingController(text: current.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Monthly Income'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'BHD '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(c.text) ?? current),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) ctrl.setMonthlyIncome(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GameController>().state;
    const goal = 20000;
    final pct = (s.monthlyIncome / goal * 100).clamp(0, 100).round();

    // IMPORTANT:
    // This widget is embedded inside a SingleChildScrollView provided
    // by the ExpandableTabs sheet. So do NOT use ListView here.
    // Use a Column so the parent scroll view controls scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keep padding in the parent scroll view; cards just get inner padding.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Army Strength',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Chip(
                      avatar: const Icon(Icons.shield_outlined, size: 16),
                      label: Text('$pct%'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fmtInt(s.monthlyIncome)} BHD/mo',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap pencil to edit',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editIncome(context, s.monthlyIncome),
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: pct / 100),
                const SizedBox(height: 8),
                Text(
                  'Archers: rents • Cavalry: businesses • Engineers: portfolio',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.savings_outlined),
                    const SizedBox(width: 8),
                    const Text('Monthly Contribution'),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 20000,
                        divisions: 200,
                        value: s.monthlyContribution.toDouble(),
                        label: fmtInt(s.monthlyContribution),
                        onChanged: (v) => context
                            .read<GameController>()
                            .setContribution(v.round()),
                      ),
                    ),
                    FilledButton(
                      onPressed: () =>
                          context.read<GameController>().addContribution(500),
                      child: const Text('+500'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
