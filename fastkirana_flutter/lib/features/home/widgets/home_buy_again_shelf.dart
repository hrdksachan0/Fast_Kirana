import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/product.dart';
import '../../orders/orders_screen.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../widgets/product_card.dart';

class HomeBuyAgainShelf extends ConsumerWidget {
  final bool isGrocerySelected;

  const HomeBuyAgainShelf({
    super.key,
    required this.isGrocerySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider(''));
    final catalogAsync = ref.watch(homeProductCatalogProvider);

    final orders = ordersAsync.valueOrNull ?? [];
    if (orders.isEmpty) return const SizedBox.shrink();

    // Extract product IDs ordered by the user, preserving recency
    final orderedProductIds = <String>{};
    for (final order in orders) {
      final items = order.items ?? [];
      for (final item in items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
          orderedProductIds.add(item.productId!);
        }
      }
    }

    if (orderedProductIds.isEmpty) return const SizedBox.shrink();

    final allProducts = catalogAsync.valueOrNull ?? [];
    if (allProducts.isEmpty) return const SizedBox.shrink();

    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;

    final buyAgainProducts = <Product>[];
    for (final id in orderedProductIds) {
      final match = allProducts.firstWhereOrNull((p) => p.id == id && p.stock > 0);
      if (match != null && !buyAgainProducts.any((p) => p.id == match.id)) {
        final isFood = isRestaurantProduct(match);

        // Filter by currently active mode (Grocery mode vs Food mode)
        if (isGrocerySelected && isFood) continue;
        if (!isGrocerySelected && !isFood) continue;

        // Check if store / restaurant is currently open
        final rOpen = RestaurantScheduleHelper.isProductRestaurantOpen(match, storeSettings: settings);
        final isOpen = isFood ? rOpen : isGroceryOpen;

        if (!isOpen) continue;

        buyAgainProducts.add(match);
      }
      if (buyAgainProducts.length >= 15) break;
    }

    if (buyAgainProducts.isEmpty) return const SizedBox.shrink();

    final cardWidth = Responsive.productCardShelfWidth(context);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shelf Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.repeat_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Buy Again',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 16),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFED7AA), width: 0.8),
                              ),
                              child: Text(
                                '${buyAgainProducts.length} ITEMS',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFC2410C),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Frequently ordered essentials in 1-tap',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w500,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Horizontal Product Track
          SizedBox(
            height: Responsive.productShelfHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
              itemCount: buyAgainProducts.length,
              separatorBuilder: (_, __) => SizedBox(width: Responsive.isSmallMobile(context) ? 8 : 10),
              itemBuilder: (context, index) {
                final product = buyAgainProducts[index];
                return SizedBox(
                  width: cardWidth,
                  child: ProductCard(
                    product: product,
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
