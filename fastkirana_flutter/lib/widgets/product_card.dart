import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/widgets/app_cached_image.dart';

import '../core/routes/page_transitions.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/dish_timing.dart';
import '../core/theme/responsive.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/store_settings_provider.dart';
import '../features/products/product_detail_screen.dart';
import '../core/utils/app_haptics.dart';

// Re-export extracted modular subcomponents for seamless backward compatibility
export 'product/product_image_with_badge.dart';
export 'product/product_price_tag.dart';
export 'product/product_quantity_selector.dart';
export 'product/product_dish_timing_badge.dart';

import 'product/product_image_with_badge.dart';
import 'product/product_price_tag.dart';
import 'product/product_quantity_selector.dart';
import 'product/blinkit_battery_meter.dart';

// ─── Main ProductCard ─────────────────────────────────────────────────────

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final bool isCompact;
  final bool showOutlet;
  final String? heroTag;
  final Widget Function(Widget)? imageBuilder;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width,
    this.isCompact = false,
    this.showOutlet = true,
    this.heroTag,
    this.imageBuilder,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final imgUrl = widget.product.imageUrl;
    if (imgUrl != null && imgUrl.isNotEmpty && !imgUrl.startsWith('data:')) {
      final resolved = imgUrl.startsWith('/') ? 'https://www.fastkirana.in$imgUrl' : imgUrl;
      precacheImage(CachedNetworkImageProvider(resolved), context).catchError((_) {});
    }
  }

  double get _effectiveWidth => widget.width ?? (widget.isCompact
      ? (context.screenWidth - 74 - 24) / 2
      : (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2);

  double get _uiScale {
    final effectiveWidth = _effectiveWidth;
    if (effectiveWidth < 125) {
      // 3-card compact horizontal shelf mode (Zepto/Blinkit 3-card view ~104-118px)
      return (effectiveWidth / 125.0).clamp(0.82, 0.95);
    }
    final baseWidth = widget.isCompact ? 144.0 : 160.0;
    return (effectiveWidth / baseWidth).clamp(0.90, 1.10);
  }

  double s(double v) => v * _uiScale;

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase().trim()).toList();
    if (tags.contains('veg') || tags.contains('pure-veg') || tags.contains('pureveg')) {
      return true;
    }
    if (tags.any((t) =>
        t == 'non-veg' ||
        t == 'nonveg' ||
        t == 'egg' ||
        t == 'chicken' ||
        t == 'mutton' ||
        t == 'fish' ||
        t.contains('non-veg') ||
        t.contains('nonveg'))) {
      return false;
    }
    final nl = product.name.toLowerCase();
    final words = nl.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();
    if (words.contains('chicken') ||
        words.contains('egg') ||
        words.contains('eggs') ||
        words.contains('mutton') ||
        words.contains('fish') ||
        words.contains('meat')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isFood = isRestaurantProduct(product);
    final isVeg = _isVeg(product);
    final cardWidth = _effectiveWidth;

    final variants = product.parsedVariants;
    final addons = product.parsedAddons;
    final hasVariants = variants.isNotEmpty;
    final hasAddons = addons.isNotEmpty;
    final hasOptions = hasVariants || hasAddons;
    final startingPrice = hasVariants ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b) : product.price;
    final startingMrp = hasVariants ? (variants.firstWhere((v) => v.price == startingPrice, orElse: () => variants.first).mrp) : product.mrp;
    final resolvedDiscount = startingMrp > startingPrice && startingMrp > 0 ? ((startingMrp - startingPrice) / startingMrp * 100).round() : product.discountPercentage;

    final timingStatus = isFood && product.availableStartTime != null && product.availableStartTime!.trim().isNotEmpty
        ? checkDishTimeAvailability(product.availableStartTime, product.availableEndTime)
        : const DishTimingStatus(isAvailableNow: true);

    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = RestaurantScheduleHelper.isProductRestaurantOpen(
      product,
      storeSettings: settings,
    );
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    final isOutOfStock = !product.isInStock;
    final totalStock = product.parsedVariants.isNotEmpty
        ? product.parsedVariants.fold<int>(0, (sum, v) => sum + v.stock)
        : product.stock;
    final isLowStock = !isFood && !isOutOfStock && totalStock > 0 && totalStock <= (product.minStock > 0 ? product.minStock : 10);

    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) => i.productId == product.id || i.productId.startsWith('${product.id}_')).toList() ?? [];
    final inCartQty = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final primaryColor = isFood ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final gradientColors = isFood ? const [Color(0xFFEA580C), Color(0xFFF97316)] : const [Color(0xFF15803D), Color(0xFF16A34A)];

    final imageHeight = isFood
        ? (widget.isCompact
            ? (cardWidth * 0.82).clamp(s(90.0), s(115.0))
            : (cardWidth * 0.80).clamp(128.0, 155.0))
        : widget.isCompact
            ? s(92)
            : Responsive.isSmallMobile(context)
                ? s(90)
                : 106 * _uiScale;

    String? bogoBadgeText;
    final restOffer = product.restaurant?.discountOffer;
    if (isFood && restOffer != null && restOffer.trim().isNotEmpty) {
      final up = restOffer.toUpperCase();
      if (up.contains('BOGO') || up.contains('BUY 1') || up.contains('BUY LARGE') || up.contains('CHEAPEST') || up.contains('FREE')) {
        final pTags = product.tags.map((t) => t.toLowerCase().trim()).toList();
        final pName = product.name.toLowerCase();
        final pSlug = product.slug.toLowerCase();
        final pSec = (product.menuSection ?? '').toLowerCase();

        bool qualifies = false;
        if (up.contains('PIZZA') || up.contains('BUY LARGE')) {
          final isConflicting = pTags.contains('burger') || pSec.contains('burger') || pTags.contains('sandwich') || pSec.contains('sandwich') || pTags.contains('maggie') || pTags.contains('maggi');
          final isPizza = !isConflicting && (pTags.contains('pizza') || pTags.any((t) => t.contains('pizza')) || pSec.contains('pizza') || pName.contains('pizza') || pSlug.contains('pizza'));
          final hasLarge = (product.variants ?? []).any((v) => v.name.toLowerCase().contains('large'));
          if (isPizza || hasLarge) {
            qualifies = true;
          }
        } else if (up.contains('BURGER')) {
          if (pTags.contains('burger') || pSec.contains('burger') || pName.contains('burger')) {
            qualifies = true;
          }
        } else if (up.contains('SANDWICH')) {
          if (pTags.contains('sandwich') || pSec.contains('sandwich') || pName.contains('sandwich')) {
            qualifies = true;
          }
        } else if (up.contains('PASTA')) {
          if (pTags.contains('pasta') || pSec.contains('pasta') || pName.contains('pasta')) {
            qualifies = true;
          }
        }

        if (qualifies) {
          if (up.contains('BUY LARGE')) {
            bogoBadgeText = 'BUY 1 GET 1';
          } else if (up.contains('CHEAPEST')) {
            bogoBadgeText = 'BUY 2 GET 1';
          } else {
            bogoBadgeText = 'BOGO DEAL';
          }
        }
      }
    } else if (product.tags.any((t) => t.toLowerCase().contains('bogo')) || product.name.toLowerCase().contains('bogo')) {
      bogoBadgeText = 'BOGO';
    }

    final isBogoDish = bogoBadgeText != null;
    final hasBadges = isBogoDish || product.isBestsellerProduct || product.isTrending || product.isFlashDealProduct || product.isOrganic || product.isMustTry;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.of(context).textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.15,
        ),
      ),
      child: RepaintBoundary(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap ?? () {
            AppHaptics.subtleTap();
            Navigator.push(context, FadeSlideRoute(page: ProductDetailScreen(product: product)));
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: cardWidth,
              padding: isFood
                  ? EdgeInsets.fromLTRB(s(2.5), s(2.5), s(2.5), s(7.0))
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isFood ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(s(14)),
                border: isFood
                    ? Border.all(color: const Color(0xFFFFEDD5), width: s(1.0))
                    : null,
                boxShadow: isFood
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: s(10),
                          offset: Offset(0, s(2.5)),
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: isFood
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. IMAGE SHOWCASE
                        ImageShowcase(
                          product: product,
                          isFood: isFood,
                          isBogoDish: isBogoDish,
                          bogoBadgeText: bogoBadgeText,
                          uiScale: _uiScale,
                          imageHeight: imageHeight,
                          resolvedDiscount: resolvedDiscount,
                          hasBadges: hasBadges,
                          timingStatus: timingStatus,
                          isLowStock: isLowStock,
                          isOutOfStock: isOutOfStock,
                          showAddedCheck: false,
                          showOutlet: widget.showOutlet,
                          heroTag: widget.heroTag,
                          imageBuilder: widget.imageBuilder,
                        ),
                        SizedBox(height: s(4)),

                        // 2. VEG/NON-VEG + TITLE
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: s(28), maxHeight: s(42)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isFood) VegNonVegIndicator(isVeg: isVeg, s: _uiScale),
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: s(12.5),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    height: 1.22,
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: s(2)),

                        // 3. VARIANT PILL / UNIT
                        VariantPill(product: product, variants: variants, hasVariants: hasOptions, isOutOfStock: isOutOfStock, isFood: isFood, uiScale: _uiScale),
                        SizedBox(height: s(3)),

                        // 4. PRICE + ADD BUTTON
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: s(5.0), bottom: s(5.0)),
                                child: PriceRow(
                                  priceText: '₹${startingPrice.toInt()}',
                                  mrpText: startingMrp > startingPrice ? '₹${startingMrp.toInt()}' : null,
                                  s: _uiScale,
                                ),
                              ),
                            ),
                            SizedBox(width: s(4)),
                            Padding(
                              padding: EdgeInsets.only(right: s(6.0), bottom: s(5.0)),
                              child: AddToCartButton(
                                scaffoldContext: context,
                                product: product,
                                inCartQty: inCartQty,
                                hasVariants: hasOptions,
                                isOutOfStock: isOutOfStock,
                                isTimingClosed: !timingStatus.isAvailableNow,
                                nextSlot: timingStatus.nextAvailableTimeStr,
                                isStoreOpen: isStoreOpen,
                                isFood: isFood,
                                gradientColors: gradientColors,
                                primaryColor: primaryColor,
                                uiScale: _uiScale,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. UPPER ENCLOSED GREY BOX WITH FLOATING BUTTON
                        // Taller portrait photo area (cardWidth * 1.12) so product images look BIG & bold even in 3-card rows!
                        SizedBox(
                          height: (cardWidth * 1.12) + s(29) + s(15),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // The Grey Container Box (bottom: s(15) + right: s(3.5) keeps the protruding button 100% inside Stack hit-test bounds!)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: s(3.5),
                                bottom: s(15),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(s(13)),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: s(1.0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Product Photo Box (full uncropped product on crisp white rounded frame)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.all(s(2)),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(s(11)),
                                            child: Container(
                                              color: Colors.white,
                                              padding: EdgeInsets.all(s(3)),
                                              child: (widget.heroTag != null && widget.heroTag!.isNotEmpty)
                                                  ? Hero(
                                                      tag: widget.heroTag!,
                                                      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                                        final target = flightDirection == HeroFlightDirection.push
                                                            ? toHeroContext.widget
                                                            : fromHeroContext.widget;
                                                        return Material(
                                                          color: Colors.transparent,
                                                          child: target,
                                                        );
                                                      },
                                                      child: AppCachedImage(
                                                        imageUrl: product.imageUrl ?? '',
                                                        fit: BoxFit.contain,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                      ),
                                                    )
                                                  : AppCachedImage(
                                                      imageUrl: product.imageUrl ?? '',
                                                      fit: BoxFit.contain,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Thin Seam Divider Line
                                      Container(
                                        height: s(0.9),
                                        color: const Color(0xFFE2E8F0),
                                      ),

                                      // Weight / Unit Row (inside the grey box — generous room so '500 ml ˅' never truncates on 3-card shelf or Moto)
                                      Container(
                                        height: s(28),
                                        padding: EdgeInsets.only(left: s(5), right: s(54)),
                                        alignment: Alignment.centerLeft,
                                        child: VariantPill(
                                          product: product,
                                          variants: variants,
                                          hasVariants: hasOptions,
                                          isOutOfStock: isOutOfStock,
                                          isFood: isFood,
                                          uiScale: _uiScale,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Top-Left Badges (Discount % OFF / Bestseller)
                              if (resolvedDiscount > 0)
                                Positioned(
                                  top: s(4),
                                  left: s(4),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: s(4.5), vertical: s(2)),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C831F),
                                      borderRadius: BorderRadius.circular(s(3.5)),
                                    ),
                                    child: Text(
                                      '$resolvedDiscount% OFF',
                                      style: GoogleFonts.inter(
                                        fontSize: s(7.5),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                )
                              else if (product.isBestsellerProduct)
                                Positioned(
                                  top: s(4),
                                  left: s(4),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: s(4.5), vertical: s(2)),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(s(3.5)),
                                    ),
                                    child: Text(
                                      'BESTSELLER',
                                      style: GoogleFonts.inter(
                                        fontSize: s(7.2),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),

                              // Wishlist Button on Top-Right
                              Positioned(
                                top: s(3),
                                right: s(6.5),
                                child: WishlistButton(product: product, s: _uiScale),
                              ),

                              // Blinkit Battery Meter Badge (Bottom-Left of photo)
                              Positioned(
                                bottom: s(15 + 32),
                                left: s(5),
                                child: BlinkitBatteryMeter(
                                  stock: totalStock,
                                  uiScale: _uiScale,
                                ),
                              ),

                              // Floating Overlapping ADD / Stepper Button (Anchored bottom-right of Stack)
                              // Visually peeks 3.5px past the grey box while staying 100% inside Stack hit-test bounds
                              Positioned(
                                bottom: s(12),
                                right: 0,
                                child: AddToCartButton(
                                  scaffoldContext: context,
                                  product: product,
                                  inCartQty: inCartQty,
                                  hasVariants: hasOptions,
                                  isOutOfStock: isOutOfStock,
                                  isTimingClosed: !timingStatus.isAvailableNow,
                                  nextSlot: timingStatus.nextAvailableTimeStr,
                                  isStoreOpen: isStoreOpen,
                                  isFood: isFood,
                                  gradientColors: gradientColors,
                                  primaryColor: primaryColor,
                                  uiScale: _uiScale,
                                  isZeptoStyle: false,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Spacing between button and price
                        SizedBox(height: s(2)),

                        // 2. UNBOXED BOTTOM AREA (Price Row + Title on clean white bg)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: s(2)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Price Row (₹Price + strikethrough ₹MRP side-by-side)
                              PriceRow(
                                priceText: '₹${startingPrice.toInt()}',
                                mrpText: startingMrp > startingPrice ? '₹${startingMrp.toInt()}' : null,
                                s: _uiScale,
                              ),
                              SizedBox(height: s(2)),

                              // Clean Title (Up to 3 lines — Blinkit editorial look, natural height)
                              ConstrainedBox(
                                constraints: BoxConstraints(minHeight: s(16), maxHeight: s(48)),
                                child: Text(
                                  product.name,
                                  style: GoogleFonts.inter(
                                    fontSize: s(12.5),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                    letterSpacing: -0.15,
                                    height: 1.22,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  final bool isCompact;

  const ProductCardSkeleton({super.key, this.width, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final cardWidth = width ?? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;
    final uiScale = cardWidth < 125
        ? (cardWidth / 125.0).clamp(0.82, 0.95)
        : (cardWidth / (isCompact ? 144.0 : 160.0)).clamp(0.90, 1.10);
    double s(double v) => v * uiScale;

    return RepaintBoundary(
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(s(7)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(14)),
          border: Border.all(color: const Color(0xFFF1F5F9), width: s(1.0)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: cardWidth - s(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: isCompact ? s(92) : s(106),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(s(12)),
                  ),
                ),
                SizedBox(height: s(6)),
                Container(width: s(70), height: s(9), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
                SizedBox(height: s(5)),
                Container(width: double.infinity, height: s(12), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
                SizedBox(height: s(5)),
                Container(width: s(40), height: s(10), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
                SizedBox(height: s(6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: s(36), height: s(12), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
                    Container(width: s(52), height: s(26), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(6)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
