import 'models.dart';

const double kFITarget = (6550 * 12) / 0.04; // 1,965,000
const double kTileValue = 10000;              // 10k BHD = 1 point/tile

String fmtInt(num v) {
  final s = v.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

/// Projection for charts (24 months by default)
/// Returns a list of maps: [{'name':'M1','value':...}, ...]
List<Map<String, dynamic>> projectPortfolio(GameState s, {int months = 24}) {
  final pts = <Map<String, dynamic>>[];
  final monthlyRate = (s.growth.roiRate / 100.0) / 12.0;
  double v = s.portfolio;
  for (int i = 1; i <= months; i++) {
    v = v * (1.0 + monthlyRate) + s.monthlyContribution.toDouble();
    pts.add({'name': 'M' + i.toString(), 'value': v});
  }
  return pts;
}

double fiRatio(GameState s) => (s.portfolio / kFITarget);
int tilesFromPortfolio(GameState s) => (s.portfolio ~/ kTileValue);
double roiToMonthly(GameState s) => s.growth.roiRate;
