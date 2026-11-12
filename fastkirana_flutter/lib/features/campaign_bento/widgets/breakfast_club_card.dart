import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../campaign_bento_models.dart';
import '../campaign_bento_provider.dart';
import 'campaign_artwork.dart';

class BreakfastClubCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const BreakfastClubCard({super.key, required this.card});

  @override
  ConsumerState<BreakfastClubCard> createState() => _BreakfastClubCardState();
}

class _BreakfastClubCardState extends ConsumerState<BreakfastClubCard> {
  final Map<String, bool> _checkedMap = {};
  bool _isBundleAdded = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.card.items) {
      _checkedMap[item.id] = item.isOutOfStock ? false : item.checkedByDefault;
    }
  }

  @override
  void didUpdateWidget(covariant BreakfastClubCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.items != widget.card.items) {
      for (final item in widget.card.items) {
        if (item.isOutOfStock) {
          _checkedMap[item.id] = false;
        } else {
          _checkedMap.putIfAbsent(item.id, () => item.checkedByDefault);
        }
      }
    }
  }

  int get _selectedCount => widget.card.items
      .where((item) => !item.isOutOfStock && _checkedMap[item.id] == true)
      .length;

  double get _totalPrice {
    double sum = 0;
    for (final item in widget.card.items) {
      if (!item.isOutOfStock && _checkedMap[item.id] == true) {
        sum += item.price;
      }
    }
    return sum;
  }

  void _handleBundleAdd() {
    if (_selectedCount == 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _isBundleAdded = true);

    final notifier = ref.read(campaignBentoProvider.notifier);
    for (final item in widget.card.items) {
      if (!item.isOutOfStock && _checkedMap[item.id] == true) {
        notifier.addItemToCart(item, quantity: 1);
      }
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isBundleAdded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final items = card.items.isNotEmpty
        ? card.items
        : const [
            CampaignBentoItemConfig(
              id: 'bc-1',
              name: 'Bread',
              weight: '400 g',
              price: 45,
              image: 'daily-bread.svg',
              checkedByDefault: true,
            ),
            CampaignBentoItemConfig(
              id: 'bc-2',
              name: 'Butter',
              weight: '100 g',
              price: 60,
              image: 'table-butter.svg',
              checkedByDefault: false,
            ),
            CampaignBentoItemConfig(
              id: 'bc-3',
              name: 'Milk',
              weight: '500 ml',
              price: 30,
              image: 'daily-milk.svg',
              checkedByDefault: true,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBF9F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title & Subtitle
              Text(
                card.title.isNotEmpty ? card.title : 'Breakfast Club',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.subtitle.isNotEmpty ? card.subtitle : 'Your quick breakfast list',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 12),

              // Two columns: Left = Breakfast Toast Photo, Right = Checklist items
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Golden Toast Photo
                  Expanded(
                    flex: 9,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CampaignArtwork(
                        image: card.heroImage ?? 'ref-breakfast-toast.png',
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.breakfast_dining_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right: Checklist items
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: items.map((item) {
                        final outOfStock = item.isOutOfStock;
                        final isChecked = !outOfStock && (_checkedMap[item.id] ?? false);

                        return Opacity(
                          opacity: outOfStock ? 0.55 : 1.0,
                          child: InkWell(
                            onTap: outOfStock
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _checkedMap[item.id] = !isChecked);
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  // Checkbox
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: outOfStock
                                          ? const Color(0xFFF1F5F9)
                                          : (isChecked ? const Color(0xFF15803D) : Colors.white),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: outOfStock
                                            ? const Color(0xFFE2E8F0)
                                            : (isChecked ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isChecked
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),

                                  // Thumbnail (real product image if linked, else artwork)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    child: CampaignArtwork(
                                      image: item.effectiveImage,
                                      width: 28,
                                      height: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Name & Weight
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          outOfStock ? 'Out of stock' : item.weight,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: outOfStock ? FontWeight.w700 : FontWeight.w500,
                                            color: outOfStock ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price
                                  Text(
                                    '₹${item.price.toInt()}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: outOfStock ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      decoration: outOfStock ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Bottom Dynamic Green Button: "Add X items • ₹Y"
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _selectedCount > 0 ? _handleBundleAdd : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBundleAdded ? const Color(0xFF16A34A) : const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isBundleAdded
                        ? '✓ Added to Cart!'
                        : (_selectedCount > 0
                            ? 'Add $_selectedCount ${_selectedCount == 1 ? "item" : "items"} • ₹${_totalPrice.toInt()}'
                            : 'Select items to add'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
