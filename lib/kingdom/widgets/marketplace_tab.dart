import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class MarketplaceTab extends StatelessWidget {
  const MarketplaceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final items = [
      _MarketItem('Fries / side', 10, 'fries', 'assets/images/vouchers/starter.png'),
      _MarketItem('Soft drink', 15, 'soft_drink', 'assets/images/vouchers/soda.png'),
      _MarketItem('Dessert', 20, 'dessert', 'assets/images/vouchers/dessert.png'),
      _MarketItem('Appetizer', 25, 'appetizer', 'assets/images/vouchers/starter.png'),
      _MarketItem('Potion (mocktail/cocktail)', 30, 'potion', 'assets/images/vouchers/drink.png'),
      _MarketItem('Main course', 50, 'main_course', 'assets/images/vouchers/main.png'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Marketplace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              _GoldChip(available: ctrl.goldAvailable),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              final canBuy = ctrl.goldAvailable >= it.cost;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      it.imagePath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(it.title),
                  subtitle: Text('${it.cost} Gold'),
                  trailing: FilledButton.tonal(
                    onPressed: canBuy
                        ? () async {
                            try {
                              await ctrl.spendGold(amount: it.cost, voucherTitle: it.title, voucherType: it.type);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Redeemed ${it.title}! Voucher added.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Purchase failed: $e')),
                                );
                              }
                            }
                          }
                        : null,
                    child: const Text('Redeem'),
                  ),
                ),
              );
            },
            separatorBuilder: (a, b) => const SizedBox(height: 8),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class _GoldChip extends StatelessWidget {
  final int available;
  const _GoldChip({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE4A3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 18, color: Color(0xFFDAA520)),
          const SizedBox(width: 6),
          Text('$available Gold', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MarketItem {
  final String title;
  final int cost;
  final String type;
  final String imagePath;
  _MarketItem(this.title, this.cost, this.type, this.imagePath);
}
