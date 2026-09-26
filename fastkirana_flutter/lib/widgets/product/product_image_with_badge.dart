import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/dish_timing.dart';
import '../../data/models/product.dart';
import '../../providers/wishlist_provider.dart';

// ─── Veg / Non-Veg Indicator ──────────────────────────────────────────────

class VegNonVegIndicator extends StatelessWidget {
  final bool isVeg;
  final double s;

  const VegNonVegIndicator({super.key, required this.isVeg, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: s * 2.5, right: s * 5),
      width: s * 13,
      height: s * 13,
      decoration: BoxDecoration(
        color: isVeg ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        border: Border.all(
          color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          width: s * 1.4,
        ),
        borderRadius: BorderRadius.circular(s * 3.5),
      ),
      child: Center(
        child: Container(
          width: s * 5.5,
          height: s * 5.5,
          decoration: BoxDecoration(
            shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
            color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            borderRadius: isVeg ? null : BorderRadius.circular(s),
          ),
        ),
      ),
    );
  }
}

// ─── Wishlist Button ──────────────────────────────────────────────────────

class WishlistButton extends ConsumerWidget {
  final Product product;
  final double s;

  const WishlistButton({super.key, required this.product, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(wishlistProvider).any((p) => p.id == product.id);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(wishlistProvider.notifier).toggleWishlist(product);
      },
      child: Container(
        padding: EdgeInsets.all(s * 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9), width: s * 0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: s * 6,
              offset: Offset(0, s * 2),
            ),
          ],
        ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: s * 14,
          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

// ─── Outlet Tag ───────────────────────────────────────────────────────────

class OutletTag extends StatelessWidget {
  final Product product;
  final double s;
  final bool isLowStock;

  const OutletTag({super.key, required this.product, required this.s, this.isLowStock = false});

  @override
  Widget build(BuildContext context) {
    final isFood = isRestaurantProduct(product);
    if (!isFood) return const SizedBox.shrink();

    final outletName = getOutletName(product);
    if (outletName.isEmpty || outletName == 'FastKirana Store' || outletName == 'Restaurant') {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: isLowStock ? s * 80 : s * 130),
        padding: EdgeInsets.symmetric(horizontal: s * 6, vertical: s * 2.5),
        decoration: BoxDecoration(
          color: const Color(0xDE0F172A),
          borderRadius: BorderRadius.circular(s * 100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: s * 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: s * 4,
              offset: Offset(0, s * 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: s * 9, color: const Color(0xFFFB923C)),
            SizedBox(width: s * 3.5),
            Flexible(
              child: Text(
                outletName,
                style: GoogleFonts.inter(
                  fontSize: s * 8,
                  fontWeight: FontWeight.w700,
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
    );
  }
}

// ─── Product Badges ───────────────────────────────────────────────────────

class ProductBadge extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Gradient gradient;
  final double radius;
  final Color shadowColor;
  final double shadowAlpha;
  final double shadowBlur;
  final Offset shadowOffset;
  final double s;

  const ProductBadge({
    super.key,
    required this.child,
    required this.margin,
    required this.padding,
    required this.gradient,
    required this.radius,
    required this.shadowColor,
    required this.shadowAlpha,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.s,
  });

  factory ProductBadge.bestseller({required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFFD97706),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: s * 8)),
          SizedBox(width: s * 2.5),
          Text('BESTSELLER', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  factory ProductBadge.bogo({required double s, String? text}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFDC2626)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFFEA580C),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: s * 8)),
          SizedBox(width: s * 2.5),
          Text(text ?? 'BOGO', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  factory ProductBadge.trending({required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFF7C3AED),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚡', style: TextStyle(fontSize: s * 8)),
          SizedBox(width: s * 2.5),
          Text('TRENDING', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  factory ProductBadge.flashDeal({required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFFDC2626),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Text('⚡ DEAL', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
    );
  }

  factory ProductBadge.organic({required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFF059669),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Text('🌿 PURE', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
    );
  }

  factory ProductBadge.mustTry({required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFF8B5CF6),
      shadowAlpha: 0.35,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Text('✨ MUST TRY', style: GoogleFonts.inter(fontSize: s * 7.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
    );
  }

  factory ProductBadge.discount(int percent, {required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: s * 6, vertical: s * 2.5),
      gradient: const LinearGradient(
        colors: [Color(0xFFE11D48), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      radius: s * 6,
      shadowColor: const Color(0xFFE11D48),
      shadowAlpha: 0.28,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s * 1.5),
      child: Text(
        '$percent% OFF',
        style: GoogleFonts.plusJakartaSans(
          fontSize: s * 8.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding as EdgeInsets,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: shadowColor.withValues(alpha: shadowAlpha), blurRadius: shadowBlur, offset: shadowOffset),
        ],
      ),
      child: child,
    );
  }
}

// ─── Product Image with Fallback & Memory Limits ──────────────────────────

class ProductImage extends StatelessWidget {
  final Product product;
  final bool isFood;
  final double s;

  const ProductImage({super.key, required this.product, required this.isFood, required this.s});

  @override
  Widget build(BuildContext context) {
    final imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('data:image')) {
        try {
          final base64String = imgUrl.contains(',') ? imgUrl.split(',')[1] : imgUrl;
          final bytes = base64Decode(base64String);
          return ClipRRect(
            borderRadius: BorderRadius.circular(s * 13),
            child: Container(
              color: isFood ? const Color(0xFFFFF7ED) : Colors.transparent,
              padding: isFood ? EdgeInsets.all(s * 6) : EdgeInsets.zero,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Center(child: Text(_emoji(product.name), style: TextStyle(fontSize: s * 36))),
              ),
            ),
          );
        } catch (_) {}
      }
      final resolved = imgUrl.startsWith('/') ? 'https://www.fastkirana.in$imgUrl' : imgUrl;
      return ClipRRect(
        borderRadius: BorderRadius.circular(s * 13),
        child: Container(
          color: isFood ? const Color(0xFFFFF7ED) : Colors.transparent,
          padding: EdgeInsets.all(s * 6),
          child: CachedNetworkImage(
            imageUrl: resolved,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 400,
            memCacheHeight: 400,
            maxWidthDiskCache: 600,
            maxHeightDiskCache: 600,
            fadeInDuration: const Duration(milliseconds: 160),
            errorWidget: (context, url, error) => Center(child: Text(_emoji(product.name), style: TextStyle(fontSize: s * 36))),
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: const Color(0xFFF1F5F9),
              highlightColor: const Color(0xFFFAFAFA),
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(s * 13))),
            ),
          ),
        ),
      );
    }
    return Center(child: Text(_emoji(product.name), style: TextStyle(fontSize: s * 36)));
  }

  static String _emoji(String name) {
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

// ─── Image Showcase Component ─────────────────────────────────────────────

class ImageShowcase extends StatelessWidget {
  final Product product;
  final bool isFood;
  final bool isBogoDish;
  final String? bogoBadgeText;
  final double uiScale;
  final double imageHeight;
  final int resolvedDiscount;
  final bool hasBadges;
  final DishTimingStatus timingStatus;
  final bool isLowStock;
  final bool isOutOfStock;
  final bool showAddedCheck;
  final bool showOutlet;
  final String? heroTag;

  const ImageShowcase({
    super.key,
    required this.product,
    required this.isFood,
    this.isBogoDish = false,
    this.bogoBadgeText,
    required this.uiScale,
    required this.imageHeight,
    required this.resolvedDiscount,
    required this.hasBadges,
    required this.timingStatus,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.showAddedCheck,
    this.showOutlet = true,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final s = uiScale;
    return Container(
      height: imageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(s * 14),
        border: Border.all(color: isFood ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9), width: s * 0.8),
      ),
      child: Stack(
        children: [
          // Product Photo
          Positioned.fill(
            child: heroTag != null
                ? Hero(tag: heroTag!, child: ProductImage(product: product, isFood: isFood, s: s))
                : ProductImage(product: product, isFood: isFood, s: s),
          ),

          // Badges
          if (hasBadges || resolvedDiscount > 0)
            Positioned(
              top: s * 5,
              left: s * 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBogoDish)
                    ProductBadge.bogo(
                      s: s,
                      text: bogoBadgeText ?? 'BOGO',
                    )
                  else if (product.isFlashDealProduct) ProductBadge.flashDeal(s: s)
                  else if (product.isBestsellerProduct) ProductBadge.bestseller(s: s)
                  else if (product.isTrending) ProductBadge.trending(s: s)
                  else if (product.isOrganic) ProductBadge.organic(s: s)
                  else if (product.isMustTry) ProductBadge.mustTry(s: s),
                  if (resolvedDiscount > 0) ProductBadge.discount(resolvedDiscount, s: s),
                ],
              ),
            ),

          // Wishlist Heart
          Positioned(top: s * 5, right: s * 5, child: WishlistButton(product: product, s: s)),

          // Outlet / Bestseller Tag
          if (showOutlet)
            Positioned(bottom: s * 5, left: s * 5, right: isLowStock ? s * 60 : s * 5, child: OutletTag(product: product, s: s, isLowStock: isLowStock)),

          // Low Stock
          if (isLowStock)
            Positioned(
              bottom: s * 5,
              right: s * 5,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: s * 5, vertical: s * 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(s * 6), boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: s * 4, offset: Offset(0, s))]),
                child: Text('Only ${product.stock} left', style: GoogleFonts.inter(fontSize: s * 8, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),

          // Out of Stock Overlay
          if (isOutOfStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.52), borderRadius: BorderRadius.circular(s * 14)),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: s * 8, vertical: s * 3),
                    decoration: BoxDecoration(color: const Color(0xFF09090B).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(s * 20), border: Border.all(color: const Color(0xFFF43F5E), width: s)),
                    child: Text('OUT OF STOCK', style: GoogleFonts.inter(fontSize: s * 8.5, fontWeight: FontWeight.w900, color: const Color(0xFFFDA4AF), letterSpacing: 0.6)),
                  ),
                ),
              ),
            ),

          // Add Checkmark Animation
          if (showAddedCheck)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(s * 14)),
                child: Center(
                  child: Container(
                    width: s * 32,
                    height: s * 32,
                    decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, color: Colors.white, size: s * 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
