import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';

Color severityColor(int s) {
  final t = (s.clamp(0, 100)) / 100.0;
  return Color.lerp(Colors.green, Colors.red, t) ?? Colors.green;
}

class ScandalsTab extends StatelessWidget {
  const ScandalsTab({super.key});

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<GameController>();
    final title = TextEditingController();
    final note = TextEditingController();
    int sev = 30;

    final created = await showDialog<Scandal>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Add Threat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: note,  decoration: const InputDecoration(labelText: 'Note')),
              const SizedBox(height: 8),
              Text('Severity: $sev'),
              Slider(
                min: 0, max: 100, value: sev.toDouble(),
                activeColor: severityColor(sev),
                onChanged: (v) => setState(() => sev = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  Scandal(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title.text.isEmpty ? 'Threat' : title.text,
                    note: note.text,
                    severity: sev, // compatible ctor field -> stored as threat
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );

    if (created != null) ctrl.addScandal(created);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final items = ctrl.state.scandals;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.report_gmailerrorred_outlined),
            const SizedBox(width: 8),
            const Text('Scandals & Legal Threats', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('Add')),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((sc) => Card(
          margin: const EdgeInsets.only(top: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: severityColor(sc.severity),
              child: Text('${sc.severity}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(sc.title),
            subtitle: Text(sc.note.isEmpty ? (sc.note.isEmpty ? '—' : sc.note) : sc.note),
            trailing: PopupMenuButton<String>(
              onSelected: (k) async {
                if (k == 'edit') {
                  final t = TextEditingController(text: sc.title);
                  final n = TextEditingController(text: sc.note.isNotEmpty ? sc.note : sc.note);
                  int sev = sc.severity;

                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
                      return AlertDialog(
                        title: const Text('Edit Threat'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')),
                            TextField(controller: n, decoration: const InputDecoration(labelText: 'Note')),
                            const SizedBox(height: 8),
                            Text('Severity: $sev'),
                            Slider(
                              min: 0, max: 100, value: sev.toDouble(),
                              activeColor: severityColor(sev),
                              onChanged: (v) => setState(() => sev = v.round()),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                        ],
                      );
                    }),
                  );

                  if (ok == true) {
                    ctrl.updateScandal(sc.id, title: t.text, note: n.text, severity: sev);
                  }
                } else if (k == 'delete') {
                  ctrl.removeScandal(sc.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
