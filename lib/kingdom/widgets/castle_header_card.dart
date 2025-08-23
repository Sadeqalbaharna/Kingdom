import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';

String _fmt(num n){ 
  return n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m)=> ',');
}

class CastleHeaderCard extends StatefulWidget {
  final GameState state;
  const CastleHeaderCard({super.key, required this.state});
  @override
  State<CastleHeaderCard> createState() => _CastleHeaderCardState();
}

class _CastleHeaderCardState extends State<CastleHeaderCard> {
  final _amountCtl = TextEditingController(text: '10000');
  @override
  void dispose(){ _amountCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final s = ctrl.state;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.castle_outlined),
                const SizedBox(width: 8),
                const Text('Kingdom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                FilledButton.tonal(onPressed: (){}, child: const Text('Keep')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_fmt(s.portfolio)} BHD',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('toward 1,965,000 BHD',
                        style: TextStyle(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('Tier'),
                    Text('2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            // Points pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hexagon_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Points: ${s.availablePoints} / ${s.totalPoints}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Amount + Add/Remove
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: 'BHD ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (){
                    final v = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0;
                    if (v > 0) ctrl.addAmount(v);
                  },
                  child: const Text('+ Add'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: (){
                    final v = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0;
                    if (v > 0) ctrl.addAmount(-v);
                  },
                  child: const Text('− Remove'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '1 point per 10k BHD. Spend 1 point to unlock a tile. Unown returns 1 point.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
