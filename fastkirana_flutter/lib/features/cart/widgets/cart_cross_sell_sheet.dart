import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../checkout/checkout_screen.dart';

/// "Aap Ye Bhool Gaye?" (Smart Cross-Sell Bottom Sheet at Checkout)
class CartCrossSellSheet extends ConsumerWidget {
  final String? cookingInstruction;
  final String? appliedCoupon;
  final double couponDiscount;
  final List<String> cartProductIds;

  const CartCrossSellSheet({
    super.key,
    required this.cookingInstruction,
    required this.appliedCoupon,
    required this.couponDiscount,
    required this.cartProductIds,
  });

  static Future<void> show(
    BuildContext context, {
    required String? cookingInstruction,
    required String? appliedCoupon,
    required double couponDiscount,
    required List<String> cartProductIds,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CartCrossSellSheet(
        cookingInstruction: cookingInstruction,
        appliedCoupon: appliedCoupon,
        couponDiscount: couponDiscount,
        cartProductIds: cartProductIds,
      ),
    );
  }

  void _proceedToCheckout(BuildContext context) {
    Navigator.pop(context); // Close sheet
    Navigator.push(
      context,
      FadeSlideRoute(
        page: CheckoutScreen(
          cookingInstruction: cookingInstruction,
          couponCode: appliedCoupon,
          discountAmount: couponDiscount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upsellAsync = ref.watch(cartUpsellProductsProvider(cartProductIds));
    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;
    final totalBill = ((cart?.subtotal ?? 0.0) - (cart?.couponDiscount ?? 0.0)).clamp(0.0, double.infinity);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            'Aap Ye Bhool Gaye?',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Most customers add these essentials before placing order',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => _proceedToCheckout(context),
                  tooltip: 'Skip and Checkout',
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Product list
          Flexible(
            child: upsellAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) _proceedToCheckout(context);
                  });
                  return const SizedBox.shrink();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF8FAFC)),
                  itemBuilder: (ctx, index) {
                    final item = products[index];
                    final cartItem = cart?.items.firstWhereOrNull((ci) => ci.productId == item.id);
                    final quantity = cartItem?.quantity ?? 0;

                    return _CrossSellItemTile(
                      product: item,
                      quantity: quantity,
                      onAdd: () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).addProduct(item);
                      },
                      onRemove: () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).decrement(item.id);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (_, __) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) _proceedToCheckout(context);
                });
                return const SizedBox.shrink();
              },
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _proceedToCheckout(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Skip & Proceed',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _proceedToCheckout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Checkout ₹${totalBill.toInt()} ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
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

class _CrossSellItemTile extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CrossSellItemTile({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.mrp > product.price;

    return Row(
      children: [
        // Product thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 58,
            height: 58,
            color: const Color(0xFFF8FAFC),
            child: AppCachedImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.contain,
              errorWidget: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Product Title & Price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                product.unit.isNotEmpty ? product.unit : '1 pc',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate500,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '₹${product.price.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(width: 6),
                    Text(
                      '₹${product.mrp.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppDesignSystem.slate400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Add / Stepper Button
        if (quantity == 0)
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF16A34A),
              elevation: 0,
              side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              minimumSize: const Size(64, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              '+ ADD',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF15803D),
              ),
            ),
          )
        else
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.remove, size: 16, color: Colors.white),
                  ),
                ),
                Text(
                  '$quantity',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                InkWell(
                  onTap: onAdd,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
