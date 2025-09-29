// No Flutter imports needed here; pure data definitions

class RewardStep {
  final int step; // 1-based
  final int gold; // 0 for non-gold steps
  final String? voucherTitle;
  final String? voucherType; // soft_drink, dessert, appetizer, potion, main_course
  final int voucherCount; // e.g., 2 for double drink
  final int? discountPercent; // 5,10,20 at steps 20,40,60

  const RewardStep({
    required this.step,
    this.gold = 0,
    this.voucherTitle,
    this.voucherType,
    this.voucherCount = 0,
    this.discountPercent,
  });

  String tooltip() {
    if (voucherTitle != null && voucherTitle!.isNotEmpty) {
      final prefix = voucherCount > 1 ? '$voucherCount× ' : '';
      // Use requested phrasing for potion/mocktail and premium dessert in tooltip only
      if (voucherType == 'potion') {
        return '🥤 Free potion/mocktail';
      }
      if (step == 45) {
        return '🍰 Premium dessert';
      }
      final icon = switch (voucherType) {
        'soft_drink' => '🥤',
        'dessert' => '🍰',
        'appetizer' => '🍗',
        'main_course' => '🍲',
        _ => '🎟️',
      };
      if (step == 55) {
        return '🥤 Bring-a-friend double drink';
      }
  return '$icon Free $prefix${voucherTitle!}';
    }
    if (discountPercent != null) {
      return '🏅 Permanent $discountPercent% discount';
    }
    return '🪙 +$gold Gold';
  }
}

/// Single source of truth: 60-step reward path.
List<RewardStep> rewardPath60() {
  final steps = <RewardStep>[];
  void addGold(int start, int end, int amount) {
    for (int s = start; s <= end; s++) {
      steps.add(RewardStep(step: s, gold: amount));
    }
  }
  // Tier I
  addGold(1, 4, 5);
  steps.add(const RewardStep(step: 5, voucherTitle: 'Soft drink', voucherType: 'soft_drink', voucherCount: 1));
  addGold(6, 9, 5);
  steps.add(const RewardStep(step: 10, voucherTitle: 'Dessert', voucherType: 'dessert', voucherCount: 1));
  addGold(11, 14, 5);
  steps.add(const RewardStep(step: 15, voucherTitle: 'Soft drink', voucherType: 'soft_drink', voucherCount: 1));
  addGold(16, 19, 10);
  steps.add(const RewardStep(step: 20, discountPercent: 5));

  // Tier II
  addGold(21, 24, 10);
  steps.add(const RewardStep(step: 25, voucherTitle: 'Starters', voucherType: 'appetizer', voucherCount: 1));
  addGold(26, 29, 10);
  steps.add(const RewardStep(step: 30, voucherTitle: 'Dessert', voucherType: 'dessert', voucherCount: 1));
  addGold(31, 34, 15);
  steps.add(const RewardStep(step: 35, voucherTitle: 'Potion (cocktail)', voucherType: 'potion', voucherCount: 1));
  addGold(36, 39, 15);
  steps.add(const RewardStep(step: 40, discountPercent: 10));

  // Tier III
  addGold(41, 44, 15);
  steps.add(const RewardStep(step: 45, voucherTitle: 'Dessert', voucherType: 'dessert', voucherCount: 1));
  addGold(46, 49, 20);
  steps.add(const RewardStep(step: 50, voucherTitle: 'Main course', voucherType: 'main_course', voucherCount: 1));
  addGold(51, 54, 20);
  steps.add(const RewardStep(step: 55, voucherTitle: 'Soft drink', voucherType: 'soft_drink', voucherCount: 2));
  addGold(56, 59, 20);
  steps.add(const RewardStep(step: 60, discountPercent: 20));

  // Ensure length 60
  assert(steps.length == 60, 'Reward path must contain 60 steps, got ${steps.length}');
  return steps;
}

// Helper to build tooltip for a specific step
String tooltipForStep(int step) {
  final list = rewardPath60();
  if (step < 1 || step > list.length) return 'Progress $step';
  return list[step - 1].tooltip();
}
