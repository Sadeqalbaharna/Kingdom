import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class HeroTab extends StatelessWidget {
  const HeroTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final f = ctrl.state.fitness;
    const gears = ['Leather','Chain','Plate','Mythril','Legendary'];
    final gear = gears[(f.armorTier-1).clamp(0,4)];

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children: const [Icon(Icons.fitness_center_outlined), SizedBox(width:8), Text('Hero', style: TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 8),
        Row(children:[
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Text('Lvl ${f.level}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text('Armor: $gear')
          ])),
          FilledButton.icon(onPressed: ctrl.grind, icon: const Icon(Icons.auto_awesome), label: const Text('Train')),
        ]),
        const SizedBox(height: 12),
        Text('Strength ${f.strengthXP}%'),
        Slider(min:0,max:100, value: f.strengthXP.toDouble(), onChanged: (v)=> ctrl.setStrengthXP(v.round())),
        Text('Stamina ${f.staminaXP}%'),
        Slider(min:0,max:100, value: f.staminaXP.toDouble(), onChanged: (v)=> ctrl.setStaminaXP(v.round())),
        Row(children:[
          Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Level'), keyboardType: TextInputType.number, controller: TextEditingController(text: f.level.toString()), onSubmitted: (t){ final v=int.tryParse(t); if(v!=null) ctrl.setLevel(v);})),
          const SizedBox(width: 8),
          Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Armor Tier (1-5)'), keyboardType: TextInputType.number, controller: TextEditingController(text: f.armorTier.toString()), onSubmitted: (t){ final v=int.tryParse(t); if(v!=null) ctrl.setArmorTier(v);})),
        ])
      ])))
    ]);
  }
}
