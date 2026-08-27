import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shimmer/shimmer.dart';
import '../core/routes/page_transitions.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/dish_timing.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/store_settings_provider.dart';
import '../features/products/product_detail_screen.dart';
import 'cart_conflict_dialog.dart';
import 'variant_selector_sheet.dart';

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final bool isCompact;
  final bool showOutlet;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width,
    this.isCompact = false,
    this.showOutlet = true,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isPressed = false;
  bool _showAddedCheck = false;

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) =>
        t.contains('non-veg') ||
        t.contains('nonveg') ||
        t == 'egg' ||
        t.contains('chicken') ||
        t.contains('mutton'))) {
      return false;
    }
    final nameLower = product.name.toLowerCase();
    if (nameLower.contains('chicken') ||
        nameLower.contains('egg') ||
        nameLower.contains('mutton') ||
        nameLower.contains('fish')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isFood = isRestaurantProduct(product);
    final isVeg = _isVeg(product);

    // Variants handling
    final variants = product.parsedVariants;
    final hasVariants = variants.isNotEmpty;

    // Pricing calculation
    final startingPrice = hasVariants
        ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b)
        : product.price;

    final startingMrp = hasVariants
        ? (variants.firstWhere((v) => v.price == startingPrice, orElse: () => variants.first).mrp)
        : product.mrp;

    final resolvedDiscount = startingMrp > startingPrice && startingMrp > 0
        ? ((startingMrp - startingPrice) / startingMrp * 100).round()
        : product.discountPercentage;

    // Time Slot / Dish Timing Availability (Food only, if explicitly set)
    final timingStatus = isFood && (product.availableStartTime != null && product.availableStartTime!.trim().isNotEmpty)
        ? checkDishTimeAvailability(
            product.availableStartTime,
            product.availableEndTime,
          )
        : const DishTimingStatus(isAvailableNow: true);

    // Live Web App Store & Restaurant Open/Close Sync
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen =
        (settings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    // Stock & Availability
    final isOutOfStock = product.stock <= 0 || !product.isAvailable;
    final isLowStock = !isFood &&
        !isOutOfStock &&
        product.stock > 0 &&
        product.stock <= (product.minStock > 0 ? product.minStock : 10);

    // Cart calculations (including all variants)
    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) {
          final pId = i.productId;
          return pId == product.id || pId.startsWith('${product.id}_');
        }).toList() ??
        [];
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);

    // Primary Colors
    final primaryColor = isFood ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final gradientColors = isFood
        ? const [Color(0xFFEA580C), Color(0xFFF97316)]
        : const [Color(0xFF15803D), Color(0xFF16A34A)];

    final outletName = getOutletName(product);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap ??
            () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                FadeSlideRoute(page: ProductDetailScreen(product: product)),
              );
            },
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
          width: widget.width,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFood ? const Color(0xFFFED7AA).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. PRODUCT IMAGE SHOWCASE BOX WITH ALL WEB APP BADGES
              Container(
                height: widget.isCompact ? 100 : (isFood ? 126 : 116),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFood ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  children: [
                    // Edge-to-Edge Product Photo
                    Positioned.fill(
                      child: Hero(
                        tag: 'product_image_${product.id}',
                        child: _buildProductImage(product, isFood),
                      ),
                    ),

                    // Top Left: Discount Badge
                    if (resolvedDiscount > 0)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFF97316)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '$resolvedDiscount% OFF',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                    // Top Left Time Slot Badge (if outside active timing)
                    if (!timingStatus.isAvailableNow && timingStatus.formattedTimeSlot != null)
                      Positioned(
                        top: resolvedDiscount > 0 ? 24 : 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '⏰ ${timingStatus.formattedTimeSlot}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Top Right: Wishlist Heart Button
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final isFav =
                              ref.watch(wishlistProvider).any((p) => p.id == product.id);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(wishlistProvider.notifier).toggleWishlist(product);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 14,
                                color: isFav ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Respected Restaurant Tag Pinned on Photo (for Food items)
                    if (isFood && widget.showOutlet && outletName.isNotEmpty)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        right: isLowStock ? 60 : 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👨‍🍳', style: TextStyle(fontSize: 9.5)),
                              const SizedBox(width: 3.5),
                              Flexible(
                                child: Text(
                                  outletName,
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (product.isBestSeller || product.tags.contains('popular'))
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '⭐ Bestseller',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),

                    // Low Stock Alert Badge
                    if (isLowStock)
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'Only ${product.stock} left',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Out of Stock Dark Overlay
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF09090B).withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                              ),
                              child: Text(
                                'OUT OF STOCK',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFDA4AF),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Checkmark Animation on Add
                    if (_showAddedCheck)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 2. VEG / NON-VEG + PRODUCT TITLE (moved up for prominence)
              SizedBox(
                height: 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFood) ...[
                      Container(
                        margin: const EdgeInsets.only(top: 2.5, right: 4.5),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            width: 1.3,
                          ),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                              color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          height: 1.22,
                          letterSpacing: -0.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 3. PRICE & PACK SIZE ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Price
                  Text(
                    '₹${startingPrice.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (startingMrp > startingPrice) ...[
                    const SizedBox(width: 4),
                    Text(
                      '₹${startingMrp.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Pack size / unit pill
                  if (hasVariants)
                    GestureDetector(
                      onTap: () {
                        if (!isOutOfStock) {
                          VariantSelectorSheet.show(context, product);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '${variants.length} Options ▾',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      product.unit.isNotEmpty && product.unit != '1 unit'
                          ? product.unit
                          : (isFood ? 'Serves 1' : '1 pc'),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // 4. ADD BUTTON (full width)
              _buildAddButton(
                context,
                product,
                inCartQty,
                hasVariants,
                isOutOfStock,
                !timingStatus.isAvailableNow,
                timingStatus.nextAvailableTimeStr,
                isStoreOpen,
                isFood,
                gradientColors,
                primaryColor,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildProductImage(Product product, bool isFood) {
    var imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('/')) {
        imgUrl = 'https://www.fastkirana.in$imgUrl';
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: imgUrl,
          fit: isFood ? BoxFit.cover : BoxFit.contain,
          memCacheWidth: 400,
          memCacheHeight: 400,
          maxWidthDiskCache: 600,
          maxHeightDiskCache: 600,
          fadeInDuration: const Duration(milliseconds: 160),
          errorWidget: (context, url, error) => Center(
            child: Text(
              _getEmojiForProduct(product.name),
              style: const TextStyle(fontSize: 36),
            ),
          ),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFFAFAFA),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForProduct(product.name),
        style: const TextStyle(fontSize: 36),
      ),
    );
  }

  void _triggerAddAnimation() {
    setState(() => _showAddedCheck = true);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _showAddedCheck = false);
    });
  }

  void _handleAddToCart(BuildContext context, Product product) {
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
          _triggerAddAnimation();
        },
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addProduct(product, 1);
    _triggerAddAnimation();
  }

  Widget _buildAddButton(
    BuildContext context,
    Product product,
    int inCartQty,
    bool hasVariants,
    bool isOutOfStock,
    bool isTimingClosed,
    String? nextSlot,
    bool isStoreOpen,
    bool isFood,
    List<Color> gradientColors,
    Color primaryColor,
  ) {
    // 1. Out of Stock
    if (isOutOfStock) {
      return Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Sold Out',
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    // 2. Dish Timing Closed
    if (isTimingClosed) {
      return Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        alignment: Alignment.center,
        child: Text(
          nextSlot != null ? 'Next @ $nextSlot' : 'Closed',
          style: GoogleFonts.inter(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFD97706),
          ),
        ),
      );
    }

    // 3. Store Closed
    if (!isStoreOpen) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFood
                          ? '${product.restaurant?.name ?? "This Restaurant"} is currently closed.'
                          : 'FastKirana Grocery Darkstore is currently closed.',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            'Closed',
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    // 4. In Cart Stepper (For Single Product or Variant Trigger)
    if (inCartQty > 0) {
      return Container(
        height: 26,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (hasVariants) {
                  VariantSelectorSheet.show(context, product);
                } else {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).decrement(product.id);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Icon(Icons.remove_rounded, size: 13, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '$inCartQty',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                if (hasVariants) {
                  VariantSelectorSheet.show(context, product);
                } else {
                  final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                  if (conflict != null) {
                    _handleAddToCart(context, product);
                  } else {
                    HapticFeedback.lightImpact();
                    ref.read(cartProvider.notifier).increment(product);
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Icon(Icons.add_rounded, size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // 5. Default ADD Button
    return Bounceable(
      onTap: () {
        if (hasVariants) {
          VariantSelectorSheet.show(context, product);
        } else {
          _handleAddToCart(context, product);
        }
      },
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: primaryColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADD',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.add_rounded, size: 12, color: primaryColor),
          ],
        ),
      ),
    );
  }

  String _getEmojiForProduct(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('butter') || lower.contains('ghee')) return '🧈';
    if (lower.contains('cheese') || lower.contains('paneer')) return '🧀';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('potato') || lower.contains('aloo')) return '🥔';
    if (lower.contains('onion') || lower.contains('pyaz')) return '🧅';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('maggi') || lower.contains('noodle')) return '🍜';
    if (lower.contains('rice') || lower.contains('chawal')) return '🍚';
    if (lower.contains('atta') || lower.contains('flour')) return '🌾';
    if (lower.contains('oil') || lower.contains('mustard')) return '🛢️';
    if (lower.contains('biscuit') || lower.contains('cookie')) return '🍪';
    if (lower.contains('chocolate') || lower.contains('silk')) return '🍫';
    if (lower.contains('chips') || lower.contains('lays')) return '🥔';
    if (lower.contains('coke') || lower.contains('cola') || lower.contains('pepsi')) return '🥤';
    if (lower.contains('ice cream') || lower.contains('kulfi')) return '🍦';
    if (lower.contains('tea') || lower.contains('chai')) return '☕';
    if (lower.contains('coffee')) return '☕';
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('roll') || lower.contains('frankie')) return '🌯';
    return '🍽️';
  }
}

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  final bool isCompact;

  const ProductCardSkeleton({
    super.key,
    this.width,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: isCompact ? 100 : 118,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 50,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 55,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

