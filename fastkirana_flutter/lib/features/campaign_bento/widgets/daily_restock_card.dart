import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../campaign_bento_models.dart';
import '../campaign_bento_provider.dart';
import 'campaign_artwork.dart';

class DailyRestockCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const DailyRestockCard({super.key, required this.card});

  @override
  ConsumerState<DailyRestockCard> createState() => _DailyRestockCardState();
}

class _DailyRestockCardState extends ConsumerState<DailyRestockCard> {
  final Map<String, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.card.items) {
      _quantities[item.id] = 1;
    }
  }

  void _increment(CampaignBentoItemConfig item) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _quantities[item.id] ?? 0;
      _quantities[item.id] = current + 1;
    });
    ref.read(campaignBentoProvider.notifier).addItemToCart(item, quantity: 1);
  }

  void _decrement(CampaignBentoItemConfig item) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _quantities[item.id] ?? 0;
      if (current > 0) {
        _quantities[item.id] = current - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: card.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: card.borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: card.accentColor.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: card.textColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: card.textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shopping basket icon container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: card.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.shopping_basket_rounded,
                      size: 26,
                      color: card.accentColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3 List Rows
              Column(
                children: card.items.map((item) {
                  final qty = _quantities[item.id] ?? 1;

                  final outOfStock = item.isOutOfStock;
                  return Opacity(
                    opacity: outOfStock ? 0.55 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Row(
                        children: [
                          // Pouch / Item image (real product photo when linked)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: CampaignArtwork(
                                image: item.effectiveImage,
                                width: 38,
                                height: 38,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title & weight
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  outOfStock ? 'Out of stock' : item.weight,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: outOfStock ? FontWeight.w700 : FontWeight.w500,
                                    color: outOfStock ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Price
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              '₹${item.price.toInt()}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: outOfStock ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                decoration: outOfStock ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (outOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'OUT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            )
                          else
                            // Light blue stepper [- 1 +]
                            Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _decrement(item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.remove, size: 14, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                  Text(
                                    '$qty',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _increment(item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.add, size: 14, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
