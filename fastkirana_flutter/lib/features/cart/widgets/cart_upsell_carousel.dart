import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/cart_conflict_dialog.dart';

/// Frequently Bought Together Carousel for Cart
class CartUpsellCarousel extends ConsumerWidget {
  final List<String> cartProductIds;

  const CartUpsellCarousel({
    super.key,
    required this.cartProductIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upsellAsync = ref.watch(cartUpsellProductsProvider(cartProductIds));

    final cart = ref.watch(cartProvider).valueOrNull;
    final cartItems = cart?.items ?? [];
    final hasFoodItem = cartItems.any((i) {
      final n = i.product.name.toLowerCase();
      return n.contains('biryani') ||
          n.contains('burger') ||
          n.contains('pizza') ||
          n.contains('roll') ||
          n.contains('meal') ||
          n.contains('thali') ||
          n.contains('noodle') ||
          n.contains('rice') ||
          n.contains('chicken') ||
          n.contains('paneer') ||
          isRestaurantProduct(i.product);
    });

    return upsellAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      hasFoodItem ? '🥤' : '🛒',
                      style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14)),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasFoodItem ? 'Aap Ye Bhool Gaye?' : 'Frequently bought together',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            if (hasFoodItem) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.rose50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.red100, width: 0.8),
                                ),
                                child: Text(
                                  '1-TAP ADD',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          hasFoodItem
                              ? 'Chilled Coke, Thums Up & Ice Cream'
                              : 'Add essentials for your home',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  'Slide →',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.slate400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, idx) {
                  return CartUpsellCard(product: products[idx]);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Single Upsell Card inside Cart Carousel
class CartUpsellCard extends ConsumerWidget {
  final Product product;

  const CartUpsellCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).valueOrNull;
    final cartItem = cart?.items.firstWhereOrNull((i) => i.productId == product.id || i.product.id == product.id);
    final imageUrl = product.imageUrl ?? '';

    final nameLower = product.name.toLowerCase();
    final catLower = (product.category?.slug ?? '').toLowerCase();
    final isDrinkOrIceCream = nameLower.contains('thums') ||
        nameLower.contains('coke') ||
        nameLower.contains('pepsi') ||
        nameLower.contains('sprite') ||
        nameLower.contains('drink') ||
        nameLower.contains('ice cream') ||
        nameLower.contains('kulfi') ||
        catLower.contains('beverage') ||
        catLower.contains('ice-cream');

    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centered Product Image with Chilled/Dessert Badge
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                  ),
                ),
              ),
              if (isDrinkOrIceCream)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      nameLower.contains('ice cream') || catLower.contains('ice-cream') ? '🍦 Dessert' : '❄️ Chilled',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 8),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Product Title (2 lines max)
          Text(
            product.name,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.slate900,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // Unit text
          Text(
            product.unit,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Bottom Price & Add/Stepper Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₹${product.price.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),

              if (cartItem != null)
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cartProvider.notifier).updateQuantity(cartItem.productId, cartItem.quantity - 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                      Text(
                        '${cartItem.quantity}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cartProvider.notifier).updateQuantity(cartItem.productId, cartItem.quantity + 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                    if (conflictRestaurant != null) {
                      final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
                      final newOutlet = getOutletName(product);
                      CartConflictDialog.show(
                        context,
                        product: product,
                        existingOutletName: conflictRestaurant,
                        groceryItemsCount: groceryCount,
                        onConfirm: () {
                          ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppDesignSystem.emerald700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      groceryCount > 0
                                          ? 'Switched to $newOutlet. $groceryCount grocery item(s) kept safe in cart! 🛒'
                                          : 'Switched to $newOutlet! 🍽️',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      return;
                    }

                    HapticFeedback.lightImpact();
                    ref.read(cartProvider.notifier).addProduct(product);
                  },
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDesignSystem.red100, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ ADD',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
