import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
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
                  Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items Review',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Grocery Section
          if (groceryItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                      const SizedBox(width: 5),
                      Text(
                        'Grocery & Daily Essentials',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Darkstore',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: AppDesignSystem.slate300),
                  ...groceryItems.map((item) => _buildReviewItemRow(context, item)),
                ],
              ),
            ),
            if (restaurantGroups.isNotEmpty) const SizedBox(height: 10),
          ],

          // 2. Restaurant Sections
          ...restaurantGroups.entries.map((entry) {
            final outletName = entry.key;
            final rItems = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignSystem.orange50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.orange200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🥘', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                      const SizedBox(width: 5),
                      Text(
                        outletName,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fresh Kitchen',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: AppDesignSystem.orange200),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.product.unit.isNotEmpty ? item.product.unit : "1 unit"} × ${item.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.slate500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${(item.product.price * item.quantity).toInt()}',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
            ),
          ),
        ],
      ),
    );
  }
}
