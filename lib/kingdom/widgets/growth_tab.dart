import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../utils.dart';

class GrowthTab extends StatelessWidget {
  const GrowthTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final s = ctrl.state;
    final data = projectPortfolio(s);
    final maxY = data.map((e) => e['y'] as num).reduce((a, b) => a>b?a:b).toDouble();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children: const [Icon(Icons.trending_up_outlined), SizedBox(width:8), Text('ROI Rate', style: TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 8),
        Text('${s.growth.roiRate.toStringAsFixed(1)}% expected annual'),
        Slider(min:0,max:30, divisions:300, value: s.growth.roiRate, label: '${s.growth.roiRate.toStringAsFixed(1)}%', onChanged: (v)=> ctrl.setRoi(v)),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children: const [Icon(Icons.show_chart), SizedBox(width:8), Text('24-Month Projection')]),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: LineChart(LineChartData(
          minX:1, maxX:24, minY:0, maxY:(maxY*1.1), gridData: FlGridData(show:false), titlesData: FlTitlesData(show:false), borderData: FlBorderData(show:false),
          lineBarsData:[ LineChartBarData(spots: data.map((e)=> FlSpot((e['x'] as num).toDouble(), (e['y'] as num).toDouble())).toList(), isCurved:true, barWidth:3, dotData: const FlDotData(show:false)) ],
        ))),
      ]))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: ctrl.addBook, icon: const Icon(Icons.menu_book_outlined), label: const Text('Add Book (10 = +1 Library)')),
      const SizedBox(height: 8),
      Text('Libraries: ${s.growth.libraries} • Books: ${s.growth.booksRead} • Temples: ${s.growth.temples} • Workshops: ${s.growth.workshops}', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
