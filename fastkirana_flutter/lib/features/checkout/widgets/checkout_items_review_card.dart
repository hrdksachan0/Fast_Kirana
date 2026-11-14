import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/cart.dart';

/// Items Review Card for Checkout
class CheckoutItemsReviewCard extends StatelessWidget {
  final List<CartItem> items;

  const CheckoutItemsReviewCard({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final groceryItems = items.where((i) => !isRestaurantProduct(i.product)).toList();
    final restaurantItems = items.where((i) => isRestaurantProduct(i.product)).toList();

    final Map<String, List<CartItem>> restaurantGroups = {};
    for (final item in restaurantItems) {
      final outlet = getOutletName(item.product);
      restaurantGroups.putIfAbsent(outlet, () => []).add(item);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                  const SizedBox(width: 5),
                  Text(
                    'Order Items Review',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Grocery Section
          if (groceryItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 11))),
                      const SizedBox(width: 4),
                      Text(
                        'Grocery & Daily Essentials',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Darkstore',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 10, thickness: 0.6, color: AppDesignSystem.slate200),
                  ...groceryItems.map((item) => _buildReviewItemRow(context, item)),
                ],
              ),
            ),
            if (restaurantGroups.isNotEmpty) const SizedBox(height: 8),
          ],

          // 2. Restaurant Sections
          ...restaurantGroups.entries.map((entry) {
            final outletName = entry.key;
            final rItems = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.orange50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.orange200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🥘', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 11))),
                      const SizedBox(width: 4),
                      Text(
                        outletName,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fresh Kitchen',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 10, thickness: 0.6, color: AppDesignSystem.orange200),
                  ...rItems.map((item) => _buildReviewItemRow(context, item)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItemRow(BuildContext context, CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty)
            AppCachedImage(
              imageUrl: item.product.imageUrl,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(6),
              memCacheWidth: 56,
              memCacheHeight: 56,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate900,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${item.product.unit.isNotEmpty ? item.product.unit : "1 unit"} × ${item.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${(item.product.price * item.quantity).toInt()}',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
            ),
          ),
        ],
      ),
    );
  }
}
