import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
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

    return upsellAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                    const SizedBox(width: 6),
                    Text(
                      'Frequently bought together',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Slide for more →',
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
          // Centered Product Image
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? (kIsWeb
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24, color: AppDesignSystem.slate400),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24, color: AppDesignSystem.slate400),
                        ))
                  : const Icon(Icons.shopping_bag_outlined, size: 24, color: AppDesignSystem.slate400),
            ),
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
