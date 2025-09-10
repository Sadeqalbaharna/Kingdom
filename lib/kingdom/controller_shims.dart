// lib/kingdom/controller_shims.dart
import '../kingdom/state.dart';   // <- your GameController + GameState

/// These add the symbols the map widget expects without touching your controller file.
/// Assumptions:
/// - controller.state.portfolio is num (BHD total)
/// - controller.state.unlocked is Set<String> of keys "q,r"
extension KingdomMapShims on GameController {
  int pointsRemaining() {
    final portfolio = (state.portfolio ?? 0);
    final spent = state.unlocked.length;
    final left = (portfolio ~/ 10000) - spent;
    return left < 0 ? 0 : left;
  }

  bool unlock(int q, int r) {
    final key = '$q,$r';
    if (state.unlocked.add(key)) {
      // this.state.spendPoint(); // Uncomment if you have this method
      return true;
    }
    return false;
  }

  bool unown(int q, int r) {
    final key = '$q,$r';
    if (state.unlocked.remove(key)) {
      // this.state.refundPoint(); // Uncomment if you have this method
      return true;
    }
    return false;
  }
}
