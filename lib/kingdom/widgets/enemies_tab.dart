import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../utils.dart';

class EnemiesTab extends StatelessWidget {
  const EnemiesTab({super.key});

  Future<void> _addDebt(BuildContext context) async {
    final ctrl = context.read<GameController>();
    final name = TextEditingController();
    final orig = TextEditingController();
    final bal = TextEditingController();

    final d = await showDialog<Debt>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Debt Monster'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: orig, decoration: const InputDecoration(labelText: 'Original'), keyboardType: TextInputType.number),
            TextField(controller: bal, decoration: const InputDecoration(labelText: 'Balance'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final o = int.tryParse(orig.text) ?? 0;
              final b = int.tryParse(bal.text) ?? 0;
              Navigator.pop(
                context,
                Debt(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name.text.isEmpty ? 'New Debt' : name.text,
                  original: o,
                  balance: b,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (d != null) ctrl.addDebt(d);
  }

  Future<void> _editBalance(BuildContext context, Debt d) async {
    final ctrl = context.read<GameController>();
    final c = TextEditingController(text: d.balance.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set Balance: ${d.name}'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'BHD '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? d.balance), child: const Text('Save')),
        ],
      ),
    );
    if (v != null) ctrl.setDebtBalance(d.id, v);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final s = ctrl.state;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_outlined),
              const SizedBox(width: 8),
              const Text('Debt Monsters', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _addDebt(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (s.debts.where((d) => d.isAlive).isEmpty)
            Text('All enemy camps defeated.', style: Theme.of(context).textTheme.bodySmall),

          // Debts list (plain children, not a nested scroll)
          ...s.debts.map((d) {
            final ratio = d.original <= 0 ? 0.0 : (d.balance / d.original).clamp(0, 1).toDouble();
            final hp = (ratio * 100).round();
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Chip(
                        label: Text('HP $hp%'),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        labelStyle: const TextStyle(color: Colors.red),
                      ),
                      IconButton(onPressed: () => _editBalance(context, d), icon: const Icon(Icons.edit)),
                      IconButton(onPressed: () => ctrl.removeDebt(d.id), icon: const Icon(Icons.delete_outline)),
                    ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Remaining: ${fmtInt(d.balance)} BHD'),
                      const Spacer(),
                      OutlinedButton(onPressed: () => ctrl.smite(d.id, 500), child: const Text('Smite 500')),
                      const SizedBox(width: 6),
                      FilledButton(onPressed: () => ctrl.smite(d.id, 1000), child: const Text('Smite 1000')),
                    ]),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.sick_outlined),
              const SizedBox(width: 8),
              const Text('Expenses Diseases', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          // Expenses list (also non-scrolling)
          ...s.expenses.map((e) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(e.label),
                  subtitle: Text('Monthly: ${fmtInt(e.monthly)} BHD'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final c = TextEditingController(text: e.monthly.toString());
                      final v = await showDialog<int>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('Edit ${e.label}'),
                          content: TextField(controller: c, keyboardType: TextInputType.number),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? e.monthly), child: const Text('Save')),
                          ],
                        ),
                      );
                      if (v != null) context.read<GameController>().setExpenseMonthly(e.id, v);
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
