import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'onboarding/auth_service.dart';

int _clampi(num v, int min, int max) => v.clamp(min, max).toInt();
double _clampd(num v, double min, double max) =>
    v < min ? min : (v > max ? max : v.toDouble());

/// Controller used with Provider.
class GameController extends ChangeNotifier {
  Future<void> setFaction(String faction) async => await _authService.setFaction(faction);
  Future<String?> get faction async => await _authService.getFaction();
  String get currentUserDisplayName => _authService.currentUser?.displayName ?? "Player";
  final AuthService _authService = AuthService();
  /// Load unlocked tiles from Firestore for the current user
  Future<void> loadUnlockedTilesFromCloud() async {
    try {
      final loaded = await _authService.loadUnlockedTiles();
      final faction = await _authService.getFaction() ?? '';
      if (loaded.isNotEmpty) {
        unlockedTilesByUnderlay.clear();
        unlockedTilesByUnderlay.addAll({
          0: {'0,0'}, // always keep center tile for map 0
          1: <String>{},
          2: <String>{},
        });
        loaded.forEach((k, v) {
          // Always keep '0,0' for map 0
          if (k == 0) {
            unlockedTilesByUnderlay[0] = {'0,0', ...v};
          } else {
            unlockedTilesByUnderlay[k] = v;
          }
        });
  // Compute availablePoints as (points earned from portfolio) - (points used for claimed tiles)
  final totalPointsObtained = (state.portfolio ~/ 10000);
  final totalPointsUsed = _totalClaimedTiles();
  final totalPointsRemaining = totalPointsObtained - totalPointsUsed;
  // Ensure available points never go negative
  state.availablePoints = totalPointsRemaining < 0 ? 0 : totalPointsRemaining;
        state.faction = faction;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load unlocked tiles: $e');
    }
  }

  /// Save unlocked tiles and points info to Firestore for the current user
  Future<void> saveUnlockedTilesToCloud() async {
    try {
  final totalPointsObtained = (state.portfolio ~/ 10000);
  final totalPointsUsed = _totalClaimedTiles();
  final totalPointsRemaining = totalPointsObtained - totalPointsUsed;
  // Update local available points to reflect earned - used before persisting
  state.availablePoints = totalPointsRemaining < 0 ? 0 : totalPointsRemaining;
      notifyListeners();
      await _authService.saveUnlockedTiles(
        unlockedTilesByUnderlay,
        totalPointsObtained: totalPointsObtained,
        totalPointsUsed: totalPointsUsed,
        totalPointsRemaining: totalPointsRemaining,
      );
    } catch (e) {
      debugPrint('Failed to save unlocked tiles: $e');
    }
  }
  /// Returns all hexes fully visible in the current map canvas.
  /// This assumes a square canvas and uses maxRadius and tileSize similar to painter logic.
  Set<String> getVisibleHexes({Size? canvasSize, double tileSize = 28, int maxRadius = 10}) {
    // If canvasSize is not provided, use a default (e.g., 390x390)
    final size = canvasSize ?? const Size(390, 390);
    final center = Offset(size.width / 2, size.height / 2);
    final Set<String> visible = {};
    for (int q = -maxRadius; q <= maxRadius; q++) {
      for (int r_ = -maxRadius; r_ <= maxRadius; r_++) {
        if ((q).abs() + (r_).abs() + (-q - r_).abs() > maxRadius * 2) continue;
        final hexCenter = Offset(
          center.dx + tileSize * (3.0 / 2.0 * q),
          center.dy + tileSize * (math.sqrt(3) / 2.0 * q + math.sqrt(3) * r_),
        );
        final hexBounds = Rect.fromCircle(center: hexCenter, radius: tileSize);
        if (hexBounds.left >= 0 && hexBounds.right <= size.width &&
            hexBounds.top >= 0 && hexBounds.bottom <= size.height) {
          visible.add('$q,$r_');
        }
      }
    }
    return visible;
  }
  GameController()
      : state = GameState(
          portfolio: 0,
          monthlyIncome: 4000,
          monthlyContribution: 1500,
          debts: [
            Debt(id: 'd1', name: 'Car Loan', original: 6000, balance: 2500),
            Debt(id: 'd2', name: 'Card', original: 3000, balance: 1200),
          ],
          expenses: [
            Expense(id: 'e1', name: 'Rent', monthly: 3500),
            Expense(id: 'e2', name: 'Food', monthly: 400),
            Expense(id: 'e3', name: 'Utilities', monthly: 180),
          ],
          armors: [
            InsurancePolicy(
              id: 'i1',
              name: 'Home Shield',
              premium: 45,
              coverage: 10000,
              active: true,
            ),
          ],
          scandals: const [],
          fitness: Fitness(level: 2, strengthXP: 30, staminaXP: 20, armorTier: 2),
          growth: GrowthInfo(booksRead: 12, roi: 8.0),
          unlocked: {'0,0'},
          showHexLabels: false,
        ) {
        // Immediately try to load tiles from Firestore
        loadUnlockedTilesFromCloud();
        // Listen for auth changes and user doc updates so UI reflects server-side
        // point changes (e.g., teacher grants points) in real-time.
        _authSub = _authService.authChanges.listen((user) {
          _attachUserListener(user);
        });
  }
  GameState state;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
    /// Event for special hex claim (e.g., chest found)
    String? specialMessage;
    String? specialPopupAsset;
    DateTime? specialPopupTimestamp;
  int? specialHexQ;
  int? specialHexR;

  int mapUnderlayIndex = 0;

  // Hex label sets for each underlay
  final Map<int, Set<String>> underlayHexLabels = {
    0: {'A0,0'}, // map_underlay.png
    1: {'B0,0'}, // map_underlay2.png
    2: {'C0,0'}, // map_underlay3.png
  };
  Set<String> get currentHexLabels => underlayHexLabels[mapUnderlayIndex] ?? {};

  // Track unlocked tiles for each underlay
  final Map<int, Set<String>> unlockedTilesByUnderlay = {
    0: {'0,0'}, // map_underlay.png
    1: <String>{}, // map_underlay2.png
    2: <String>{}, // map_underlay3.png
  };
  int get currentUnderlay => mapUnderlayIndex;
  Set<String> get unlocked => unlockedTilesByUnderlay[currentUnderlay] ?? {};
  int get unlockedCount => unlocked.length;

  // availablePoints is now a mutable field in GameState

  int _totalClaimedTiles() {
    int total = 0;
    unlockedTilesByUnderlay.forEach((_, tiles) {
      total += tiles.length;
    });
    // Exclude permanent center tile (0,0) on underlay 0 from the claimed count
    if (unlockedTilesByUnderlay[0]?.contains('0,0') ?? false) {
      total -= 1;
    }
    return total < 0 ? 0 : total;
  }

  void _attachUserListener(User? user) {
    // Cancel any existing listener
    _userDocSub?.cancel();
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid).withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? {},
      toFirestore: (m, _) => m,
    );
    _userDocSub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      // Use server-side totals when available. totalPointsObtained maps to our
      // internal `portfolio` (each app 'point' = 10000 portfolio units).
      final obtained = (data['totalPointsObtained'] is num) ? (data['totalPointsObtained'] as num).toInt() : ((data['points'] is num) ? (data['points'] as num).toInt() : null);
      if (obtained != null) {
        state.portfolio = obtained * 10000;
      }
      // Prefer server-provided remaining points if present, otherwise recompute
      final rem = (data['totalPointsRemaining'] is num) ? (data['totalPointsRemaining'] as num).toInt() : null;
      if (rem != null) {
        state.availablePoints = rem < 0 ? 0 : rem;
      } else {
        final totalEarned = (state.portfolio ~/ 10000);
        final totalUsed = _totalClaimedTiles();
        state.availablePoints = (totalEarned - totalUsed) < 0 ? 0 : (totalEarned - totalUsed);
      }
      notifyListeners();
    });
  }

  /// Public helper returning total claimed tiles excluding the permanent center tile.
  int totalClaimedTiles() => _totalClaimedTiles();

  void unlock(int q, int r) {
    final key = '$q,$r';
    final tiles = unlockedTilesByUnderlay[currentUnderlay]!;
    // Only keep A0,0 un-unclaimable
    if (currentUnderlay == 0 && key == '0,0') return;
    if (tiles.contains(key)) return;
    // Enforce: total claimed tiles (excluding permanent center) cannot exceed earned points.
  final totalEarned = (state.portfolio ~/ 10000);
  int totalUsed = _totalClaimedTiles();
    if (totalUsed >= totalEarned) {
      print('Not enough earned points to claim tile $key (earned=$totalEarned, used=$totalUsed)');
      return;
    }
    print('Claiming tile $key on underlay $currentUnderlay (earned=$totalEarned, used=$totalUsed)');
    tiles.add(key);
    // Note: availablePoints now reflects earned - used and is recomputed/persisted in saveUnlockedTilesToCloud()
    // Show popup if claiming the special tile
    if (specialHexQ == q && specialHexR == r) {
      specialMessage = "You find an old chest, you open it and find a coupon for a free drink";
      specialPopupAsset = "assets/images/keep.png";
      specialPopupTimestamp = DateTime.now();
      notifyListeners();
    }
    // Randomize the next special hex after every unlock
    randomizeSpecialHex();
  notifyListeners();
  // Persist per-user unlocked tiles map and update per-tile aggregate counts
  saveUnlockedTilesToCloud();
  // Fire-and-forget increment of aggregate counts for analytics/hover display
  // Fire-and-forget increment of aggregate counts for analytics/hover display
  _authService.claimTile(currentUnderlay, key, state.faction);
  }

  void randomizeSpecialHex() {
    // Special tile must be on an unclaimed and visible tile
    final visible = getVisibleHexes(); // This should return Set<String> of visible hexes
    final claimed = unlocked;
    final unclaimedVisible = visible.difference(claimed);
    if (unclaimedVisible.isEmpty) {
      specialHexQ = null;
      specialHexR = null;
      return;
    }
  final rand = math.Random();
    final chosen = unclaimedVisible.elementAt(rand.nextInt(unclaimedVisible.length));
    final parts = chosen.split(',');
    specialHexQ = int.parse(parts[0]);
    specialHexR = int.parse(parts[1]);
    notifyListeners();
  }

  // _allPossibleHexesForCurrentUnderlay removed (unused)

  // Handy getters (some widgets were using these)
  bool get showHexLabels => state.showHexLabels;

  // ---------- Portfolio ----------
  // Dev-only: directly add/subtract points
  void addPoints(int delta) {
  // Adjust the underlying "earned" metric (portfolio) so that
  // saveUnlockedTilesToCloud() correctly recomputes availablePoints.
  // Each "point" corresponds to 10,000 in portfolio.
  final totalUsed = _totalClaimedTiles();
  final currentEarned = (state.portfolio ~/ 10000);
  // Apply +/-1 earned point based on delta sign
  int newEarned = currentEarned + (delta > 0 ? 1 : (delta < 0 ? -1 : 0));
  // Never allow earned to drop below the number of used/claimed tiles
  if (newEarned < totalUsed) newEarned = totalUsed;
  if (newEarned < 0) newEarned = 0;
  state.portfolio = newEarned * 10000;
  // Persist and recompute availablePoints (saveUnlockedTilesToCloud will notify)
  saveUnlockedTilesToCloud();
  notifyListeners();
  }

  // ---------- Army (income / contribution) ----------
  void setMonthlyIncome(int v) {
  state.monthlyIncome = _clampi(v, 0, 1 << 31);
  notifyListeners();
  saveUnlockedTilesToCloud();
  }

  void setContribution(int v) {
  state.monthlyContribution = _clampi(v, 0, 1 << 31);
  notifyListeners();
  saveUnlockedTilesToCloud();
  }

  void addContribution(int delta) {
  setContribution(state.monthlyContribution + delta);
  saveUnlockedTilesToCloud();
  }

  // ---------- Debts ----------
  void addDebt(Debt d) {
    state.debts.add(d);
    notifyListeners();
  }

  void setDebtBalance(String id, int value) {
    final i = state.debts.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = state.debts[i];
    state.debts[i] = Debt(
      id: old.id,
      name: old.name,
      original: old.original,
      balance: _clampi(value, 0, 1 << 31),
    );
    notifyListeners();
  }

  /// Pay down a debt by [amount].
  void smite(String id, int amount) {
    final i = state.debts.indexWhere((e) => e.id == id);
    if (i == -1) return;
    setDebtBalance(id, _clampi(state.debts[i].balance - amount, 0, 1 << 31));
  }

  void removeDebt(String id) {
    state.debts.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ---------- Expenses ----------
  void setExpenseMonthly(String id, int value) {
    final i = state.expenses.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = state.expenses[i];
    state.expenses[i] = Expense(id: old.id, name: old.name, monthly: _clampi(value, 0, 1 << 31));
    notifyListeners();
  }

  // ---------- Armors (insurance) ----------
  void addArmor(InsurancePolicy p) {
    state.armors.add(p);
    notifyListeners();
  }

  void setArmorActive(String id, bool v) {
    final i = state.armors.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = state.armors[i];
    state.armors[i] = InsurancePolicy(
      id: old.id,
      name: old.name,
      premium: old.premium,
      coverage: old.coverage,
      active: v,
    );
    notifyListeners();
  }

  void editArmor(String id, {String? name, int? premium, int? coverage}) {
    final i = state.armors.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = state.armors[i];
    state.armors[i] = InsurancePolicy(
      id: old.id,
      name: name ?? old.name,
      premium: premium ?? old.premium,
      coverage: coverage ?? old.coverage,
      active: old.active,
    );
    notifyListeners();
  }

  // ---------- Scandals ----------
  void addScandal(Scandal s) {
    state.scandals.add(s);
    notifyListeners();
  }

  void updateScandal(String id, {String? title, String? note, int? severity}) {
    final i = state.scandals.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = state.scandals[i];
    state.scandals[i] = Scandal(
      id: old.id,
      title: title ?? old.title,
      note: note ?? old.note,
      severity: severity ?? old.severity,
    );
    notifyListeners();
  }

  void removeScandal(String id) {
    state.scandals.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ---------- Hero ----------
  void grind() {
    setStrengthXP(state.fitness.strengthXP + 5);
    setStaminaXP(state.fitness.staminaXP + 5);
    if (state.fitness.strengthXP + state.fitness.staminaXP >= 180) {
      setLevel(state.fitness.level + 1);
      if (state.fitness.level % 3 == 0) {
        setArmorTier(state.fitness.armorTier + 1);
      }
    }
  }

  void setStrengthXP(int v) {
    state.fitness.strengthXP = _clampi(v, 0, 100);
    notifyListeners();
  }

  void setStaminaXP(int v) {
    state.fitness.staminaXP = _clampi(v, 0, 100);
    notifyListeners();
  }

  void setLevel(int v) {
    state.fitness.level = _clampi(v, 1, 999);
    notifyListeners();
  }

  void setArmorTier(int v) {
    state.fitness.armorTier = _clampi(v, 1, 5);
    notifyListeners();
  }

  // ---------- Growth ----------
  void setRoi(double roi) {
    state.growth.roi = _clampd(roi, 0, 100);
    notifyListeners();
  }

  void addBook() {
    state.growth.booksRead += 1;
    state.growth.libraries = state.growth.booksRead ~/ 10;
    notifyListeners();
  }

  // ---------- Dev toggle ----------
  void toggleHexLabels() {
    state.showHexLabels = !state.showHexLabels;
    notifyListeners();
  }

  void setMapUnderlayIndex(int i) {
    mapUnderlayIndex = i;
    notifyListeners();
  }

  void unown(int q, int r) {
    final key = '$q,$r';
    final tiles = unlockedTilesByUnderlay[currentUnderlay]!;
    // Only keep A0,0 un-unclaimable
    if (currentUnderlay == 0 && key == '0,0') return;
    if (!tiles.contains(key)) return;
  tiles.remove(key);
  // availablePoints will be recomputed in saveUnlockedTilesToCloud()
  notifyListeners();
  saveUnlockedTilesToCloud();
  _authService.unclaimTile(currentUnderlay, key, state.faction);
  }

  /// Reset all claims for the current user (developer action).
  /// Unclaims every tile (except center 0,0 on underlay 0), refunds points, and persists changes.
  Future<void> resetAllClaims() async {
    // Collect all tiles to unclaim (per underlay)
    final toUnclaim = <MapEntry<int, String>>[];
    unlockedTilesByUnderlay.forEach((underlay, tiles) {
      for (final t in tiles) {
        // Skip center tile on underlay 0
        if (underlay == 0 && t == '0,0') continue;
        toUnclaim.add(MapEntry(underlay, t));
      }
    });

    // Call backend to decrement aggregate counts for every tile (best-effort)
    for (final e in toUnclaim) {
      try {
        _authService.unclaimTile(e.key, e.value, state.faction);
      } catch (_) {}
    }

    // Clear local unlocked sets (preserve center tile)
    unlockedTilesByUnderlay.forEach((underlay, tiles) {
      if (underlay == 0) {
        unlockedTilesByUnderlay[0] = {'0,0'};
      } else {
        unlockedTilesByUnderlay[underlay] = <String>{};
      }
    });

    // Recompute availablePoints: refund all (set to total unlocked after reset)
    int total = 0;
    unlockedTilesByUnderlay.forEach((_, tiles) {
      total += tiles.length;
    });
    // Exclude center tile if present
    if (unlockedTilesByUnderlay[0]?.contains('0,0') ?? false) total -= 1;
    state.availablePoints = total < 0 ? 0 : total;

    notifyListeners();
    await saveUnlockedTilesToCloud();
  }

  void clearSpecialPopup() {
    specialPopupAsset = null;
    specialMessage = null;
    specialPopupTimestamp = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  String? _cachedFaction;
  Future<void> updateFactionCache() async {
    _cachedFaction = await _authService.getFaction();
    // Also keep the live state.faction in sync so widgets reading ctrl.state.faction
    // display the persisted faction immediately.
    if (_cachedFaction != null && _cachedFaction!.trim().isNotEmpty) {
      state.faction = _cachedFaction!;
    }
    notifyListeners();
  }
  String get factionString => _cachedFaction ?? '';

  /// Fetch per-faction counts for a given tile
  Future<Map<String, int>> fetchTileCounts(int underlay, String tileKey) async {
    return await _authService.getTileCounts(underlay, tileKey);
  }

  /// Fetch aggregated per-faction counts for an underlay (map) and return the
  /// raw counts map from AuthService.
  Future<Map<String, int>> fetchUnderlayCounts(int underlay) async {
    return await _authService.getUnderlayCounts(underlay);
  }

  /// Convenience helper: fetch percentage ownership per faction for an underlay.
  /// Returns a map of faction -> percentage (0-100). If there are no claimed tiles,
  /// returns an empty map.
  Future<Map<String, double>> fetchUnderlayPercentages(int underlay) async {
    final counts = await fetchUnderlayCounts(underlay);
    final total = counts['total'] ?? 0;
    if (total <= 0) return {};
    final Map<String, double> perc = {};
    counts.forEach((k, v) {
      if (k == 'total') return;
      perc[k] = (v / total) * 100.0;
    });
    return perc;
  }
}
