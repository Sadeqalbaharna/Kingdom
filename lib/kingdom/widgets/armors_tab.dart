import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../utils.dart';

class ArmorsTab extends StatelessWidget {
  const ArmorsTab({super.key});

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<GameController>();
    final name = TextEditingController();
    final premium = TextEditingController();
    final coverage = TextEditingController();

    final res = await showDialog<InsurancePolicy>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Magical Armor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: premium, decoration: const InputDecoration(labelText: 'Premium (monthly)'), keyboardType: TextInputType.number),
            TextField(controller: coverage, decoration: const InputDecoration(labelText: 'Coverage'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(premium.text) ?? 0;
              final c = int.tryParse(coverage.text) ?? 0;
              Navigator.pop(
                context,
                InsurancePolicy(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name.text.isEmpty ? 'Policy' : name.text,
                  premium: p,
                  coverage: c,
                  active: true,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != null) ctrl.addArmor(res);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final items = ctrl.state.armors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.security_outlined),
              const SizedBox(width: 8),
              const Text('Magical Armors (Insurance)', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // List items as plain children (no inner scrolling)
          ...items.map((p) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text('Premium: ${fmtInt(p.premium)} • Coverage: ${fmtInt(p.coverage)}'),
                  leading: Switch(
                    value: p.active,
                    onChanged: (v) => ctrl.setArmorActive(p.id, v),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final n = TextEditingController(text: p.name);
                      final pr = TextEditingController(text: p.premium.toString());
                      final co = TextEditingController(text: p.coverage.toString());
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Edit Armor'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
                              TextField(controller: pr, decoration: const InputDecoration(labelText: 'Premium'), keyboardType: TextInputType.number),
                              TextField(controller: co, decoration: const InputDecoration(labelText: 'Coverage'), keyboardType: TextInputType.number),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        ctrl.editArmor(
                          p.id,
                          name: n.text,
                          premium: int.tryParse(pr.text),
                          coverage: int.tryParse(co.text),
                        );
                      }
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
