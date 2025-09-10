
// ---------- Data types ----------
class Debt {
  String id;
  String name;
  int balance;
  int original;
  Debt({
    required this.id,
    required this.name,
    required int balance,
    required int original,
  })  : balance = balance,
        original = original;

  bool get isAlive => balance > 0;
}

class Expense {
  String id;
  String name;
  int monthly;
  Expense({required this.id, required this.name, required int monthly}) : monthly = monthly;

  String get label => name;
}

class Fitness {
  int level;
  int strengthXP; // 0..100
  int staminaXP; // 0..100
  int armorTier; // 1..5
  Fitness({
    required this.level,
    required this.strengthXP,
    required this.staminaXP,
    required this.armorTier,
  });
}

class Scandal {
  String id;
  String title;
  String note;
  int threat; // 0..100
  Scandal({
    required this.id,
    required this.title,
    String? note,
    int? severity,
  })  : note = note ?? '',
        threat = severity ?? 0;

  int get severity => threat;
}

class ArmorPolicy {
  String id;
  String name;
  bool active;
  int premium; // monthly cost
  int coverage; // coverage amount
  ArmorPolicy({
    required this.id,
    required this.name,
    this.active = false,
    int premium = 0,
    int coverage = 0,
  })  : premium = premium,
        coverage = coverage;
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
    required double roi,
    int? libraries,
    int? temples,
    int? workshops,
  })  : roi = roi,
        libraries = libraries ?? (booksRead ~/ 10),
        temples = temples ?? 0,
        workshops = workshops ?? 0;

  double get roiRate => roi;
}

// ---------- Game state ----------
class GameState {
  double portfolio;
  int monthlyIncome;
  int monthlyContribution;
  List<Debt> debts;
  List<Expense> expenses;
  List<Scandal> scandals;
  List<ArmorPolicy> armors;
  Fitness fitness;
  GrowthInfo growth;
  Set<String> unlocked;
  bool showHexLabels; // dev toggle
  int availablePoints;
  String faction;

  GameState({
    required this.portfolio,
    required this.monthlyIncome,
    required this.monthlyContribution,
    required this.debts,
    required this.expenses,
    required this.scandals,
    required this.armors,
    required this.fitness,
    required this.growth,
    required this.unlocked,
    this.showHexLabels = false,
    this.availablePoints = 0,
    this.faction = '',
  });
}
