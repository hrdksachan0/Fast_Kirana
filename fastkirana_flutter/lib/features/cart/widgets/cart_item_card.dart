import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/cart.dart';
import '../../../widgets/shimmer_box.dart';

/// Modular Cart Item Tile with Quantity Modifier Stepper
class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = item.product;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate100,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppDesignSystem.darkSurfaceMuted : AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate100,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const ShimmerBox(width: 48, height: 48),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.shopping_basket_outlined,
                      color: AppDesignSystem.slate400,
                    ),
                  )
                : const Icon(
                    Icons.shopping_basket_outlined,
                    color: AppDesignSystem.slate400,
                  ),
          ),

          const SizedBox(width: 12),

          // Title, Unit & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesignSystem.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                  ),
                ),
                const SizedBox(height: 3),
                if (product.unit.isNotEmpty)
                  Text(
                    product.unit,
                    style: const TextStyle(
                      color: AppDesignSystem.slate500,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${product.price.toInt()}',
                      style: const TextStyle(
                        color: AppDesignSystem.slate900,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (product.mrp > product.price) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${product.mrp.toInt()}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: AppDesignSystem.slate400,
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Stepper Modifier: [-] Qty [+]
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF00B140),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B140).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDecrement();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Icon(
                      Icons.remove_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onIncrement();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
