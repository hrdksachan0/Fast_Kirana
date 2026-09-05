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
import '../core/theme/responsive.dart';
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

  double get _uiScale {
    final cardWidth = widget.width ??
        (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;
    const baseWidth = 155.0;
    return (cardWidth / baseWidth).clamp(1.0, 1.15);
  }

  double s(double v) => v * _uiScale;
  double bs(double v) => v * _uiScale;
  Offset off(double x, double y) => Offset(s(x), s(y));

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

    // Responsive scale: scales all internal sizes proportionally based on card width
    final cardWidth = widget.width ??
        (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;
    final baseWidth = 155.0;
    final uiScale = (cardWidth / baseWidth).clamp(1.0, 1.15);

    // Scale helpers
    double s(double v) => (v * uiScale);
    EdgeInsets geo(double all) => EdgeInsets.all(s(all));
    EdgeInsets only({double? top, double? bottom, double? left, double? right}) =>
        EdgeInsets.only(top: s(top ?? 0), bottom: s(bottom ?? 0), left: s(left ?? 0), right: s(right ?? 0));
    EdgeInsets sym({double h = 0, double v = 0}) => EdgeInsets.symmetric(horizontal: s(h), vertical: s(v));
    Radius r(double v) => Radius.circular(s(v));
    double blur(double v) => s(v);
    Offset off(double x, double y) => Offset(s(x), s(y));

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
          child: Container(
            width: cardWidth,
            padding: EdgeInsets.fromLTRB(s(6), s(6), s(6), s(7)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(s(18)),
              border: Border.all(
                color: isFood ? const Color(0xFFFED7AA).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                width: s(1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: s(10),
                  offset: off(0, 3),
                ),
              ],
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. PRODUCT IMAGE SHOWCASE BOX WITH ALL WEB APP BADGES
              Container(
                height: widget.isCompact
                    ? s(100)
                    : Responsive.isSmallMobile(context)
                        ? s(95)
                        : (isFood ? 116 : 110) * uiScale,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(s(14)),
                  border: Border.all(
                    color: isFood ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9),
                    width: s(0.8),
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

                    // Top Left: Stacked Badges (Discount + Bestseller / Trending / Flash Deal)
                    Positioned(
                      top: s(5),
                      left: s(5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.isBestsellerProduct)
                            _badge(
                              margin: only(bottom: 3),
                              padding: sym(h: 5.5, v: 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              radius: 5,
                              shadowColor: const Color(0xFFD97706),
                              shadowAlpha: 0.35,
                              shadowBlur: 4,
                              shadowOffset: off(0, 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🔥', style: TextStyle(fontSize: s(8))),
                                  SizedBox(width: s(2.5)),
                                  Text(
                                    'BESTSELLER',
                                    style: GoogleFonts.inter(
                                      fontSize: s(7.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (product.isTrending)
                            _badge(
                              margin: only(bottom: 3),
                              padding: sym(h: 5.5, v: 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              radius: 5,
                              shadowColor: const Color(0xFF7C3AED),
                              shadowAlpha: 0.35,
                              shadowBlur: 4,
                              shadowOffset: off(0, 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('⚡', style: TextStyle(fontSize: s(8))),
                                  SizedBox(width: s(2.5)),
                                  Text(
                                    'TRENDING',
                                    style: GoogleFonts.inter(
                                      fontSize: s(7.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (product.isFlashDealProduct)
                            _badge(
                              margin: only(bottom: 3),
                              padding: sym(h: 5.5, v: 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              radius: 5,
                              shadowColor: const Color(0xFFDC2626),
                              shadowAlpha: 0.35,
                              shadowBlur: 4,
                              shadowOffset: off(0, 1),
                              child: Text(
                                '⚡ DEAL',
                                style: GoogleFonts.inter(
                                  fontSize: s(7.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),

                          // Discount Badge
                          if (resolvedDiscount > 0)
                            _badge(
                              margin: EdgeInsets.zero,
                              padding: sym(h: 5.5, v: 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFF97316)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              radius: 5,
                              shadowColor: const Color(0xFFE11D48),
                              shadowAlpha: 0.3,
                              shadowBlur: 4,
                              shadowOffset: off(0, 1),
                              child: Text(
                                '$resolvedDiscount% OFF',
                                style: GoogleFonts.inter(
                                  fontSize: s(8.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Top Left Time Slot Badge (if outside active timing)
                    if (!timingStatus.isAvailableNow && timingStatus.formattedTimeSlot != null)
                      Positioned(
                        top: resolvedDiscount > 0 ? s(24) : s(5),
                        left: s(5),
                        child: Container(
                          padding: sym(h: 5, v: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(s(6)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                blurRadius: s(4),
                                offset: off(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '⏰ ${timingStatus.formattedTimeSlot}',
                            style: GoogleFonts.inter(
                              fontSize: s(8),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Top Right: Wishlist Heart Button
                    Positioned(
                      top: s(5),
                      right: s(5),
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
                              padding: geo(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: s(6),
                                    offset: off(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: s(14),
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
                        bottom: s(5),
                        left: s(5),
                        right: isLowStock ? s(60) : s(5),
                        child: Container(
                          padding: sym(h: 6, v: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(s(6)),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: s(0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('👨‍🍳', style: TextStyle(fontSize: s(9.5))),
                              SizedBox(width: s(3.5)),
                              Flexible(
                                child: Text(
                                  outletName,
                                  style: GoogleFonts.inter(
                                    fontSize: s(8.5),
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
                        bottom: s(5),
                        left: s(5),
                        child: Container(
                          padding: sym(h: 5.5, v: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(s(6)),
                            border: Border.all(color: const Color(0xFFFDE68A), width: s(0.8)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                blurRadius: s(4),
                                offset: off(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '⭐ Bestseller',
                            style: GoogleFonts.inter(
                              fontSize: s(8),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),

                    // Low Stock Alert Badge
                    if (isLowStock)
                      Positioned(
                        bottom: s(5),
                        right: s(5),
                        child: Container(
                          padding: sym(h: 5, v: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(s(6)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                blurRadius: s(4),
                                offset: off(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'Only ${product.stock} left',
                            style: GoogleFonts.inter(
                              fontSize: s(8),
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
                            borderRadius: BorderRadius.circular(s(14)),
                          ),
                          child: Center(
                            child: Container(
                              padding: sym(h: 8, v: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF09090B).withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(s(20)),
                                border: Border.all(color: const Color(0xFFF43F5E), width: s(1)),
                              ),
                              child: Text(
                                'OUT OF STOCK',
                                style: GoogleFonts.inter(
                                  fontSize: s(8.5),
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
                            borderRadius: BorderRadius.circular(s(14)),
                          ),
                          child: Center(
                            child: Container(
                              width: s(32),
                              height: s(32),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded, color: Colors.white, size: s(20)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: s(6)),

              // 2. VEG / NON-VEG + PRODUCT TITLE
              SizedBox(
                height: s(34),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFood) ...[
                      Container(
                        margin: only(top: 2.5, right: 5),
                        width: s(13),
                        height: s(13),
                        decoration: BoxDecoration(
                          color: isVeg ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          border: Border.all(
                            color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            width: s(1.4),
                          ),
                          borderRadius: BorderRadius.circular(s(3.5)),
                        ),
                        child: Center(
                          child: Container(
                            width: s(5.5),
                            height: s(5.5),
                            decoration: BoxDecoration(
                              shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                              color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              borderRadius: isVeg ? null : BorderRadius.circular(s(1)),
                            ),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: s(12),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.22,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: s(4)),

              // 3. PACK SIZE / UNIT / VARIANT PILL
              if (hasVariants)
                GestureDetector(
                  onTap: () {
                    if (!isOutOfStock) {
                      VariantSelectorSheet.show(context, product);
                    }
                  },
                  child: Container(
                    margin: only(bottom: 5),
                    padding: sym(h: 6, v: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(s(6)),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${variants.length} Options',
                          style: GoogleFonts.inter(
                            fontSize: s(9),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        SizedBox(width: s(2)),
                        Icon(Icons.keyboard_arrow_down_rounded, size: s(12), color: const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: only(bottom: 5),
                  child: Text(
                    product.unit.isNotEmpty && product.unit != '1 unit'
                        ? product.unit
                        : (isFood ? 'Serves 1' : '1 pc'),
                    style: GoogleFonts.inter(
                      fontSize: s(10),
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 4. PRICE ON LEFT & PREMIUM ADD BUTTON ON RIGHT ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: Price & MRP
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${startingPrice.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: s(13.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (startingMrp > startingPrice)
                          Padding(
                            padding: only(top: 1.5),
                            child: Text(
                              '₹${startingMrp.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: s(9.5),
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.lineThrough,
                                color: const Color(0xFF94A3B8),
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: s(4)),
                  // Right Side: Compact Premium ADD Button / Stepper
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
                    uiScale,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _badge({
    required EdgeInsetsGeometry margin,
    required EdgeInsetsGeometry padding,
    required Gradient gradient,
    required double radius,
    required Color shadowColor,
    required double shadowAlpha,
    required double shadowBlur,
    required Offset shadowOffset,
    required Widget child,
  }) {
    return Container(
      margin: margin,
      padding: padding as EdgeInsets,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: shadowAlpha),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildProductImage(Product product, bool isFood) {
    var imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('/')) {
        imgUrl = 'https://www.fastkirana.in$imgUrl';
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(s(13)),
        child: Container(
          color: isFood ? const Color(0xFFFFF7ED) : Colors.transparent,
          padding: isFood ? EdgeInsets.all(s(6)) : EdgeInsets.zero,
          child: CachedNetworkImage(
            imageUrl: imgUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 400,
            memCacheHeight: 400,
            maxWidthDiskCache: 600,
            maxHeightDiskCache: 600,
            fadeInDuration: const Duration(milliseconds: 160),
            errorWidget: (context, url, error) => Center(
              child: Text(
                _getEmojiForProduct(product.name),
                style: TextStyle(fontSize: s(36)),
              ),
            ),
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: const Color(0xFFF1F5F9),
              highlightColor: const Color(0xFFFAFAFA),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(s(13)),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForProduct(product.name),
        style: TextStyle(fontSize: s(36)),
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
    if (product.stock <= 0 || !product.isAvailable) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is currently out of stock.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
        ),
      );
      return;
    }

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

    final success = ref.read(cartProvider.notifier).addProduct(product, 1);
    if (success) {
      HapticFeedback.mediumImpact();
      _triggerAddAnimation();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
              SizedBox(width: s(8)),
              Expanded(
                child: Text(
                  'Cannot add more! Only ${product.stock} units available in stock.',
                  style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    double uiScale,
  ) {
    final btnScale = uiScale;
    double bs(double v) => (v * btnScale).toDouble();

    // 1. Out of Stock
    if (isOutOfStock) {
      return Container(
        height: bs(30),
        padding: EdgeInsets.symmetric(horizontal: bs(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(color: const Color(0xFFE2E8F0), width: s(1)),
        ),
        alignment: Alignment.center,
        child: Text(
          'SOLD OUT',
          style: GoogleFonts.inter(
            fontSize: s(9),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    // 2. Dish Timing Closed
    if (isTimingClosed) {
      return Container(
        height: bs(30),
        padding: EdgeInsets.symmetric(horizontal: bs(8)),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(color: const Color(0xFFFDE68A), width: s(1)),
        ),
        alignment: Alignment.center,
        child: Text(
          nextSlot != null ? 'Next @ $nextSlot' : 'Closed',
          style: GoogleFonts.inter(
            fontSize: s(9),
            fontWeight: FontWeight.w800,
            color: const Color(0xFFD97706),
            letterSpacing: 0.1,
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
                  SizedBox(width: s(8)),
                  Expanded(
                    child: Text(
                      isFood
                          ? '${product.restaurant?.name ?? "This Restaurant"} is currently closed.'
                          : 'FastKirana Grocery Darkstore is currently closed.',
                      style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          height: bs(30),
          padding: EdgeInsets.symmetric(horizontal: bs(10)),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(s(8)),
            border: Border.all(color: const Color(0xFFE2E8F0), width: s(1)),
          ),
          alignment: Alignment.center,
          child: Text(
            'CLOSED',
            style: GoogleFonts.inter(
              fontSize: s(9),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    // 4. In Cart Stepper (Tactile Premium Gradient Stepper)
    if (inCartQty > 0) {
      return Container(
        height: bs(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(s(8)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.28),
              blurRadius: s(6),
              offset: off(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minus Button
            InkWell(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(s(8))),
              onTap: () {
                if (hasVariants) {
                  VariantSelectorSheet.show(context, product);
                } else {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).decrement(product.id);
                }
              },
              child: SizedBox(
                width: bs(26),
                height: bs(30),
                child: Center(
                  child: Icon(Icons.remove_rounded, size: bs(14), color: Colors.white),
                ),
              ),
            ),
            // Quantity Number
            Container(
              constraints: BoxConstraints(minWidth: bs(18)),
              alignment: Alignment.center,
              child: Text(
                '$inCartQty',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: s(12),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // Plus Button
            InkWell(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(s(8))),
              onTap: () {
                if (hasVariants) {
                  VariantSelectorSheet.show(context, product);
                } else {
                  if (inCartQty >= product.stock) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                            SizedBox(width: s(8)),
                            Expanded(
                              child: Text(
                                'Only ${product.stock} units available in stock!',
                                style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                  if (conflict != null) {
                    _handleAddToCart(context, product);
                  } else {
                    HapticFeedback.lightImpact();
                    ref.read(cartProvider.notifier).increment(product);
                  }
                }
              },
              child: SizedBox(
                width: bs(26),
                height: bs(30),
                child: Center(
                  child: Icon(Icons.add_rounded, size: bs(14), color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 5. Default ADD Button (Blinkit/Instamart Style Premium Pill)
    return Bounceable(
      scaleFactor: 0.94,
      onTap: () {
        if (hasVariants) {
          VariantSelectorSheet.show(context, product);
        } else {
          _handleAddToCart(context, product);
        }
      },
      child: Container(
        height: bs(30),
        padding: EdgeInsets.symmetric(horizontal: bs(11)),
        decoration: BoxDecoration(
          color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(
            color: isFood ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
            width: s(1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: s(5),
              offset: off(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ADD',
              style: GoogleFonts.inter(
                fontSize: s(11),
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(width: s(3)),
            Icon(
              Icons.add_rounded,
              size: s(14),
              color: primaryColor,
            ),
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
    final cardWidth = width ??
        (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;
    final baseWidth = 155.0;
    final uiScale = (cardWidth / baseWidth).clamp(1.0, 1.15);
    double s(double v) => (v * uiScale);

    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(s(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s(18)),
        border: Border.all(color: const Color(0xFFF1F5F9), width: s(1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: isCompact ? s(100) : s(118),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(s(14)),
            ),
          ),
          SizedBox(height: s(8)),
          Container(
            width: s(80),
            height: s(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(s(4)),
            ),
          ),
          SizedBox(height: s(6)),
          Container(
            width: double.infinity,
            height: s(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(s(4)),
            ),
          ),
          SizedBox(height: s(6)),
          Container(
            width: s(45),
            height: s(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(s(4)),
            ),
          ),
          SizedBox(height: s(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: s(40),
                height: s(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(s(4)),
                ),
              ),
              Container(
                width: s(58),
                height: s(27),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(s(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
