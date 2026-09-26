import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/routes/page_transitions.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/dish_timing.dart';
import '../core/theme/responsive.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/store_settings_provider.dart';
import '../features/products/product_detail_screen.dart';

// Re-export extracted modular subcomponents for seamless backward compatibility
export 'product/product_image_with_badge.dart';
export 'product/product_price_tag.dart';
export 'product/product_quantity_selector.dart';
export 'product/product_dish_timing_badge.dart';

import 'product/product_image_with_badge.dart';
import 'product/product_price_tag.dart';
import 'product/product_quantity_selector.dart';

// ─── Main ProductCard ─────────────────────────────────────────────────────

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final bool isCompact;
  final bool showOutlet;
  final String? heroTag;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width,
    this.isCompact = false,
    this.showOutlet = true,
    this.heroTag,
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

  double get _uiScale {
    final effectiveWidth = widget.width ?? (widget.isCompact
        ? (context.screenWidth - 74 - 24) / 2
        : (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2);
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
    final cardWidth = widget.width ?? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;

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

    final isOutOfStock = product.stock <= 0 || !product.isAvailable;
    final isLowStock = !isFood && !isOutOfStock && product.stock > 0 && product.stock <= (product.minStock > 0 ? product.minStock : 10);

    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) => i.productId == product.id || i.productId.startsWith('${product.id}_')).toList() ?? [];
    final inCartQty = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final primaryColor = isFood ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final gradientColors = isFood ? const [Color(0xFFEA580C), Color(0xFFF97316)] : const [Color(0xFF15803D), Color(0xFF16A34A)];

    final imageHeight = widget.isCompact
        ? (isFood ? s(98) : s(92))
        : Responsive.isSmallMobile(context)
            ? (isFood ? s(96) : s(90))
            : (isFood ? 114 : 106) * _uiScale;

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
          minScaleFactor: 0.85,
          maxScaleFactor: 1.05,
        ),
      ),
      child: RepaintBoundary(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap ?? () {
            HapticFeedback.lightImpact();
            Navigator.push(context, FadeSlideRoute(page: ProductDetailScreen(product: product)));
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: cardWidth,
              padding: EdgeInsets.fromLTRB(s(7), s(7), s(7), s(8)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(s(14)),
                border: Border.all(
                  color: isFood ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9),
                  width: s(1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: s(10),
                    offset: Offset(0, s(2.5)),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.02),
                    blurRadius: s(4),
                    offset: Offset(0, s(1)),
                  ),
                ],
              ),
              child: Column(
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
                  ),
                  SizedBox(height: s(5)),

                  // 2. VEG/NON-VEG + TITLE
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: s(30)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFood) VegNonVegIndicator(isVeg: isVeg, s: _uiScale),
                        Expanded(
                          child: Text(
                            product.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: s(12.0),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              height: 1.24,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: s(3)),

                  // 3. VARIANT PILL / UNIT
                  VariantPill(product: product, variants: variants, hasVariants: hasOptions, isOutOfStock: isOutOfStock, isFood: isFood, uiScale: _uiScale),
                  SizedBox(height: s(4)),

                  // 4. PRICE + ADD BUTTON
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: PriceRow(
                          priceText: '₹${startingPrice.toInt()}',
                          mrpText: startingMrp > startingPrice ? '₹${startingMrp.toInt()}' : null,
                          s: _uiScale,
                        ),
                      ),
                      SizedBox(width: s(4)),
                      AddToCartButton(
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
                    ],
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
    final baseWidth = isCompact ? 144.0 : 160.0;
    final uiScale = (cardWidth / baseWidth).clamp(0.90, 1.10);
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
    );
  }
}
