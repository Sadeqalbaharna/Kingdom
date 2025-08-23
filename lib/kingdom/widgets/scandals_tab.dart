import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';

Color severityColor(int s){
  final t = (s.clamp(0,100))/100.0;
  return Color.lerp(Colors.green, Colors.red, t) ?? Colors.green;
}

class ScandalsTab extends StatelessWidget {
  const ScandalsTab({super.key});

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<GameController>();
    final title = TextEditingController();
    final note = TextEditingController();
    int sev = 30;
    final res = await showDialog<Scandal>(context: context, builder: (_)=> StatefulBuilder(builder: (ctx, setState){
      return AlertDialog(title: const Text('Add Threat'), content: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        const SizedBox(height:8), Text('Severity: $sev'), Slider(min:0,max:100,value: sev.toDouble(), activeColor: severityColor(sev), onChanged: (v)=> setState(()=> sev=v.round())),
      ]), actions:[TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: ()=> Navigator.pop(context, Scandal(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title.text.isEmpty? 'Threat': title.text, note: note.text, severity: sev)), child: const Text('Add'))]);
    }));
    if (res!=null) ctrl.addScandal(res);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final items = ctrl.state.scandals;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [const Icon(Icons.report_gmailerrorred_outlined), const SizedBox(width:8), const Text('Scandals & Legal Threats', style: TextStyle(fontWeight: FontWeight.w600)), const Spacer(), FilledButton.icon(onPressed: ()=> _add(context), icon: const Icon(Icons.add), label: const Text('Add'))]),
      const SizedBox(height: 8),
      ...items.map((s)=> Card(margin: const EdgeInsets.only(top:8), child: ListTile(
        leading: CircleAvatar(backgroundColor: severityColor(s.severity), child: Text('${s.severity}', style: const TextStyle(color: Colors.white))),
        title: Text(s.title), subtitle: Text(s.note.isEmpty? '—' : s.note),
        trailing: PopupMenuButton<String>(onSelected: (k){
          if (k=='edit') {
            final t=TextEditingController(text: s.title); final n=TextEditingController(text: s.note); int sev=s.severity;
            showDialog(context: context, builder: (_)=> StatefulBuilder(builder: (ctx, setState){
              return AlertDialog(title: const Text('Edit Threat'), content: Column(mainAxisSize: MainAxisSize.min, children:[
                TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: n, decoration: const InputDecoration(labelText: 'Note')),
                const SizedBox(height:8), Text('Severity: $sev'), Slider(min:0,max:100,value: sev.toDouble(), activeColor: severityColor(sev), onChanged: (v)=> setState(()=> sev=v.round())),
              ]), actions:[TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: (){ ctrl.updateScandal(s.id, title: t.text, note: n.text, severity: sev); Navigator.pop(context); }, child: const Text('Save'))]);
            }));
          } else if (k=='delete') {
            ctrl.removeScandal(s.id);
          }
        }, itemBuilder: (_)=> const [PopupMenuItem(value:'edit',child:Text('Edit')), PopupMenuItem(value:'delete',child:Text('Delete'))]),
      )))
    ]);
  }
}
