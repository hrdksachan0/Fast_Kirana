import 'package:flutter/material.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/product.dart';
import '../../../widgets/product_card.dart';

/// Modular Flash Deals & Trending Steals Product Rail
class FlashDealsCarousel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final VoidCallback? onSeeAll;
  final String? badgeText;

  const FlashDealsCarousel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    this.onSeeAll,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkSurface : const Color(0xFFFFF7ED),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: isDark ? AppDesignSystem.darkBorder : const Color(0xFFFFEDD5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (badgeText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppDesignSystem.h3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppDesignSystem.caption.copyWith(
                            color: AppDesignSystem.slate600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            color: AppDesignSystem.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppDesignSystem.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Horizontal Product Rail
          SizedBox(
            height: Responsive.productShelfHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cardWidth = Responsive.productCardShelfWidth(context);
                return SizedBox(
                  width: cardWidth,
                  child: ProductCard(
                    product: products[index],
                    isCompact: false,
                    width: cardWidth,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
