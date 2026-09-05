import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/product.dart';
import '../core/theme/responsive.dart';
import '../providers/cart_provider.dart';
import '../providers/store_settings_provider.dart';
import '../core/utils/restaurant_utils.dart';
import 'cart_conflict_dialog.dart';

class VariantSelectorSheet extends ConsumerWidget {
  final Product product;

  const VariantSelectorSheet({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, Product product) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VariantSelectorSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = product.parsedVariants;
    final isFood = isCafeProduct(product);
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = (settings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Product Info Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!.startsWith('/')
                                ? 'https://www.fastkirana.in${product.imageUrl}'
                                : product.imageUrl!,
                            fit: BoxFit.contain,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            maxWidthDiskCache: 200,
                            maxHeightDiskCache: 200,
                            errorWidget: (_, __, ___) => Center(
                              child: Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24))),
                            ),
                          )
                        : Center(
                            child: Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24))),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate900,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.unit.isNotEmpty ? product.unit : (isFood ? 'Freshly Prepared' : 'Options available'),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Close Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppDesignSystem.slate500),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'SELECT OPTION / PACK SIZE',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate400,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Variants List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final v = variants[index];
                return _buildVariantRow(context, ref, v, isStoreOpen, isFood);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildVariantRow(
    BuildContext context,
    WidgetRef ref,
    ProductVariant variant,
    bool isStoreOpen,
    bool isFood,
  ) {
    final cart = ref.watch(cartProvider).value;
    final variantProductId = '${product.id}_${variant.name}';
    final cartItem = cart?.items.cast<dynamic>().firstWhere(
      (i) => i.productId == variantProductId || (i.productId == product.id && i.selectedVariant == variant.name),
      orElse: () => null,
    );
    final inCartQty = cartItem?.quantity ?? 0;

    final discount = variant.mrp > variant.price && variant.mrp > 0
        ? ((variant.mrp - variant.price) / variant.mrp * 100).round()
        : 0;

    final isSelected = inCartQty > 0;
    final isSoldOut = !product.isAvailable || product.stock <= 0;

    // Create variant-specific product copy for Cart
    final variantProduct = Product(
      id: variantProductId,
      name: '${product.name} (${variant.name})',
      slug: product.slug,
      description: product.description,
      imageUrl: product.imageUrl,
      categoryId: product.categoryId,
      restaurantId: product.restaurantId,
      mrp: variant.mrp,
      price: variant.price,
      discount: discount.toDouble(),
      unit: variant.name,
      stock: product.stock,
      isAvailable: product.isAvailable,
      tags: product.tags,
      variants: product.variants,
      minStock: product.minStock,
      expiryDate: product.expiryDate,
      costPrice: product.costPrice,
      location: product.location,
      isFlashDeal: product.isFlashDeal,
      isTopPick: product.isTopPick,
      isBestSeller: product.isBestSeller,
      sortOrder: product.sortOrder,
      availableStartTime: product.availableStartTime,
      availableEndTime: product.availableEndTime,
      barcode: product.barcode,
      createdAt: product.createdAt,
      category: product.category,
      restaurant: product.restaurant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppDesignSystem.green50 : AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppDesignSystem.lime500 : AppDesignSystem.slate200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Variant Name & Pricing Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '₹${variant.price.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                    if (variant.mrp > variant.price) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${variant.mrp.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          color: AppDesignSystem.slate400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.rose50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.rose600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sold Out',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate400,
                ),
              ),
            )
          else if (!isStoreOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Closed',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate400,
                ),
              ),
            )
          else if (inCartQty == 0)
            ElevatedButton(
              onPressed: () {
                final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(variantProduct);
                if (conflictRestaurant != null) {
                  final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
                  final newOutlet = getOutletName(variantProduct);
                  CartConflictDialog.show(
                    context,
                    product: variantProduct,
                    existingOutletName: conflictRestaurant,
                    groceryItemsCount: groceryCount,
                    onConfirm: () {
                      ref.read(cartProvider.notifier).replaceRestaurantItemsWith(variantProduct, 1);
                    },
                  );
                  return;
                }
                HapticFeedback.mediumImpact();
                ref.read(cartProvider.notifier).addProduct(variantProduct, 1, variant.name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFood ? AppDesignSystem.orange600 : AppDesignSystem.green600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'ADD',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: isFood ? AppDesignSystem.orange600 : AppDesignSystem.green600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).decrement(variantProductId);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Icon(Icons.remove_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$inCartQty',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.scaledFontSize(context, 13),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).addProduct(variantProduct, 1, variant.name);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Icon(Icons.add_rounded, size: 15, color: Colors.white),
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
