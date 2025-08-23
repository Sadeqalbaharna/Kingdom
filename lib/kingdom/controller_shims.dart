// lib/kingdom/controller_shims.dart
import 'package:flutter/foundation.dart';
import 'package:kingdom/kingdom/state.dart';   // <- your GameController + GameState

/// These add the symbols the map widget expects without touching your controller file.
/// Assumptions:
/// - controller.state.portfolio is num (BHD total)
/// - controller.state.unlocked is Set<String> of keys "q,r"
extension KingdomMapShims on GameController {
  /// 1 point per 10k BHD, each unlocked tile spends 1 point
  int get pointsRemaining {
    final portfolio = (state.portfolio ?? 0) as num; // tolerate int/double/null
    final tilesFromWealth = (portfolio ~/ 10000);
    final spent = state.unlocked.length;
    final left = tilesFromWealth - spent;
    return left < 0 ? 0 : left;
  }

  /// Spend 1 point to unlock the tile key "q,r"
  void unlockTile(String key) {
    if (pointsRemaining <= 0) return;
    if (state.unlocked.add(key)) {
      notifyListeners();
    }
  }

  /// Unown a tile (refund 1 point implicitly—since pointsRemaining is derived)
  void unownTile(String key) {
    if (state.unlocked.remove(key)) {
      notifyListeners();
    }
  }
}
