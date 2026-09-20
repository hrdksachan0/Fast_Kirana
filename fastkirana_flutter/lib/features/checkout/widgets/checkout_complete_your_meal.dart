import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/cart.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';

/// "Complete Your Meal" Cross-Sell Section on Checkout
class CheckoutCompleteYourMeal extends ConsumerWidget {
  final List<CartItem> items;

  const CheckoutCompleteYourMeal({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemIds = items.map((i) => i.product.id).toList();

    return ref.watch(cartUpsellProductsProvider(itemIds)).when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMPLETE YOUR MEAL',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, idx) {
                  final p = products[idx];
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.slate300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: p.imageUrl ?? '',
                            width: double.infinity,
                            height: 75,
                            fit: BoxFit.cover,
                            memCacheWidth: 260,
                            memCacheHeight: 150,
                            maxWidthDiskCache: 400,
                            maxHeightDiskCache: 225,
                            errorWidget: (_, __, ___) => Container(
                              color: AppDesignSystem.slate200,
                              child: const Icon(Icons.fastfood_rounded, color: AppDesignSystem.slate400),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${p.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            Bounceable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(cartProvider.notifier).addProduct(p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.green100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.emerald200),
                                ),
                                child: Text(
                                  '+ ADD',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.green600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
