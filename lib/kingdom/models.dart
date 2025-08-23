import 'package:flutter/foundation.dart';

// ---------- Data types ----------
class Debt {
  String id;
  String name;
  double balance;
  double original;
  Debt({
    required this.id,
    required this.name,
    required num balance,
    required num original,
  })  : balance = balance.toDouble(),
        original = original.toDouble();

  bool get isAlive => balance > 0;
}

class Expense {
  String id;
  String name;
  double monthly;
  Expense({
    required this.id,
    required this.name,
    required num monthly,
  }) : monthly = monthly.toDouble();

  String get label => name;
}

class Fitness {
  int level;
  int strengthXP; // 0..100
  int staminaXP;  // 0..100
  int armorTier;  // 1..5
  Fitness({required this.level, required this.strengthXP, required this.staminaXP, required this.armorTier});
}

class Scandal {
  String id;
  String title;
  String description;
  String note;
  int threat; // 0..100
  Scandal({
    required this.id,
    required this.title,
    String? description,
    String? note,
    int? severity, // compatibility
    int? threat,   // primary
  })  : description = description ?? (note ?? ''),
        note = note ?? (description ?? ''),
        threat = (threat ?? severity ?? 0);

  int get severity => threat;
}

class ArmorPolicy {
  String id;
  String name;
  bool active;
  String notes;
  double premium;   // monthly cost
  double coverage;  // coverage amount
  ArmorPolicy({
    required this.id,
    required this.name,
    this.active=false,
    this.notes='',
    num premium = 0,
    num coverage = 0,
  })  : premium = premium.toDouble(),
        coverage = coverage.toDouble();
}
typedef InsurancePolicy = ArmorPolicy;

class GrowthInfo {
  int booksRead;
  double roi; // % annual
  int libraries;
  int temples;
  int workshops;

  GrowthInfo({
    required this.booksRead,
    required num roi,
    int? libraries,
    int? temples,
    int? workshops,
  })  : roi = roi.toDouble(),
        libraries = libraries ?? (booksRead ~/ 10),
        temples = temples ?? 0,
        workshops = workshops ?? 0;

  double get roiRate => roi;
}

// ---------- Game state ----------
class GameState {
  double portfolio;
  int monthlyIncome;         // int to satisfy UI
  int monthlyContribution;   // int to satisfy UI
  List<Debt> debts;
  List<Expense> expenses;
  Fitness fitness;
  List<Scandal> scandals;
  List<ArmorPolicy> armors;
  GrowthInfo growth;
  Set<String> unlocked; // 'q,r'

  GameState({
    required this.portfolio,
    required this.monthlyIncome,
    required this.monthlyContribution,
    required this.debts,
    required this.expenses,
    required this.fitness,
    required this.scandals,
    required this.armors,
    required this.growth,
    required this.unlocked,
  });

  int get totalPoints => (portfolio ~/ 10000);
  int get spentPoints {
    int used = unlocked.length;
    if (unlocked.contains('0,0')) used -= 1;
    return used.clamp(0, totalPoints);
  }
  int get availablePoints => (totalPoints - spentPoints).clamp(0, totalPoints);
}

// ---------- Controller ----------
class GameController extends ChangeNotifier {
  GameState state = GameState(
    portfolio: 570000,
    monthlyIncome: 9500,
    monthlyContribution: 6700,
    debts: [
      Debt(id: 'cc', name: 'Credit Card Bandits', balance: 0, original: 6000),
      Debt(id: 'family', name: 'Rival Clan Note', balance: 28000, original: 36000),
    ],
    expenses: [
      Expense(id:'rent', name:'Guild Dues (Rent)', monthly: 800),
    ],
    fitness: Fitness(level: 7, strengthXP: 62, staminaXP: 48, armorTier: 3),
    scandals: [
      Scandal(id:'fine', title:'Old Bank Fee', description:'Appeal pending', severity: 25),
    ],
    armors: [
      ArmorPolicy(id:'health', name:'Health Insurance', active:true, notes:'Basic plan', premium: 80, coverage: 20000),
      ArmorPolicy(id:'auto', name:'Car Insurance', active:true, premium: 60, coverage: 15000),
    ],
    growth: GrowthInfo(booksRead: 12, roi: 7.0),
    unlocked: {'0,0'},
  );

  // --- Savings / portfolio ---
  void addAmount(num delta) {
    final next = (state.portfolio + delta).clamp(0, 1e12);
    state.portfolio = next.toDouble();
    notifyListeners();
  }

  // --- Army (income/contrib) ---
  void setMonthlyIncome(int v) { state.monthlyIncome = v; notifyListeners(); }
  void setContribution(int v) { state.monthlyContribution = v; notifyListeners(); }
  void addContribution(int delta) {
    final next = (state.monthlyContribution + delta).clamp(0, 1000000000);
    state.monthlyContribution = next;
    notifyListeners();
  }

  // --- Debts ---
  void addDebt(dynamic a, [num? balance]) {
    if (a is Debt) {
      state.debts = [...state.debts, a];
    } else if (a is String) {
      final id = 'd${state.debts.length+1}';
      final b = (balance ?? 0);
      state.debts = [...state.debts, Debt(id: id, name: a, balance: b, original: b)];
    }
    notifyListeners();
  }
  void setDebtBalance(String id, num balance) {
    state.debts = state.debts.map((d) => d.id == id
      ? Debt(id:d.id, name:d.name, balance: balance, original: d.original)
      : d).toList();
    notifyListeners();
  }
  void removeDebt(String id) {
    state.debts = state.debts.where((d)=> d.id != id).toList();
    notifyListeners();
  }
  void smite(String id, num amount) {
    state.debts = state.debts.map((d) {
      if (d.id != id) return d;
      final nb = (d.balance - amount).clamp(0, 1e12);
      return Debt(id:d.id, name:d.name, balance: nb, original: d.original);
    }).toList();
    notifyListeners();
  }

  // --- Expenses ---
  void setExpenseMonthly(String id, num v) {
    state.expenses = state.expenses.map((e)=>
      e.id==id ? Expense(id:e.id, name:e.name, monthly:v) : e
    ).toList();
    notifyListeners();
  }

  // --- Fitness / Hero ---
  void grind() {
    state.fitness.strengthXP = (state.fitness.strengthXP + 5).clamp(0, 100);
    state.fitness.staminaXP  = (state.fitness.staminaXP  + 5).clamp(0, 100);
    if (state.fitness.strengthXP + state.fitness.staminaXP >= 180) {
      state.fitness.level += 1;
      if (state.fitness.level % 3 == 0) {
        state.fitness.armorTier = (state.fitness.armorTier + 1).clamp(1,5);
      }
    }
    notifyListeners();
  }
  void setStrengthXP(int v){ state.fitness.strengthXP = v.clamp(0,100); notifyListeners(); }
  void setStaminaXP(int v){ state.fitness.staminaXP  = v.clamp(0,100); notifyListeners(); }
  void setLevel(int v){ state.fitness.level = v; notifyListeners(); }
  void setArmorTier(int v){ state.fitness.armorTier = v.clamp(1,5); notifyListeners(); }

  // --- Scandals ---
  void addScandal(dynamic a, {String? desc, String? note, int? severity}){
    if (a is Scandal) {
      state.scandals = [...state.scandals, a];
    } else if (a is String) {
      final id = 's${state.scandals.length+1}';
      state.scandals = [
        ...state.scandals,
        Scandal(id:id, title:a, description:desc, note:note, severity:severity),
      ];
    }
    notifyListeners();
  }
  void updateScandal(dynamic a, {String? title, String? desc, String? note, int? severity}){
    String? id;
    if (a is String) id = a; else if (a is Scandal) id = a.id;
    if (id == null) return;
    state.scandals = state.scandals.map((s){
      if (s.id != id) return s;
      return Scandal(
        id: s.id,
        title: title ?? s.title,
        description: (desc ?? note) ?? s.description,
        severity: severity ?? s.threat,
      );
    }).toList();
    notifyListeners();
  }
  void removeScandal(dynamic a){
    String? id;
    if (a is String) id = a; else if (a is Scandal) id = a.id;
    if (id == null) return;
    state.scandals = state.scandals.where((s)=> s.id != id).toList();
    notifyListeners();
  }

  // --- Armors ---
  void addArmor(dynamic a, {num premium = 0, num coverage = 0}){
    if (a is ArmorPolicy) {
      state.armors = [...state.armors, a];
    } else if (a is String) {
      final id = 'a${state.armors.length+1}';
      state.armors = [
        ...state.armors,
        ArmorPolicy(id:id, name:a, premium: premium, coverage: coverage),
      ];
    }
    notifyListeners();
  }
  void setArmorActive(String id, bool active){
    state.armors = state.armors.map((b)=>
      b.id==id ? ArmorPolicy(id:b.id, name:b.name, active:active, notes:b.notes, premium:b.premium, coverage:b.coverage) : b
    ).toList();
    notifyListeners();
  }
  void editArmor(String id, {String? name, String? notes, num? premium, num? coverage}){
    state.armors = state.armors.map((b)=>
      b.id==id ? ArmorPolicy(
        id:b.id,
        name:name??b.name,
        active:b.active,
        notes:notes??b.notes,
        premium: premium ?? b.premium,
        coverage: coverage ?? b.coverage,
      ) : b
    ).toList();
    notifyListeners();
  }

  // --- Growth ---
  void setRoi(num roi){ state.growth.roi = roi.toDouble(); notifyListeners(); }
  void addBook(){ state.growth.booksRead += 1; state.growth.libraries = state.growth.booksRead ~/ 10; notifyListeners(); }

  // --- Tiles economy ---
  void unlock(int q, int r) {
    final key = '$q,$r';
    if (state.unlocked.contains(key)) return;
    if (state.availablePoints <= 0) return;
    state.unlocked = {...state.unlocked, key};
    notifyListeners();
  }
  void unown(int q, int r) {
    final key = '$q,$r';
    if (key == '0,0') return;
    if (!state.unlocked.contains(key)) return;
    state.unlocked = {...state.unlocked}..remove(key);
    notifyListeners();
  }
}
