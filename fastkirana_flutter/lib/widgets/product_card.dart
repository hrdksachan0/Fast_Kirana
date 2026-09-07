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

// ─── Extracted Sub-Widgets ────────────────────────────────────────────────

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
          color: Colors.white.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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

class OutletTag extends StatelessWidget {
  final Product product;
  final double s;
  final bool isLowStock;

  const OutletTag({super.key, required this.product, required this.s, this.isLowStock = false});

  @override
  Widget build(BuildContext context) {
    final outletName = getOutletName(product);
    if (product.isBestSeller || product.tags.contains('popular')) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(s * 6),
          border: Border.all(color: const Color(0xFFFDE68A), width: s * 0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: s * 4,
              offset: Offset(0, s),
            ),
          ],
        ),
        child: Text(
          '⭐ Bestseller',
          style: GoogleFonts.inter(fontSize: s * 8, fontWeight: FontWeight.w900, color: const Color(0xFFB45309)),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s * 6, vertical: s * 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(s * 6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: s * 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('👨‍🍕', style: TextStyle(fontSize: s * 9.5)),
          SizedBox(width: s * 3.5),
          Flexible(
            child: Text(
              outletName,
              style: GoogleFonts.inter(fontSize: s * 8.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

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

  factory ProductBadge.discount(int percent, {required double s}) {
    return ProductBadge(
      s: s,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: s * 5.5, vertical: s * 2),
      gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      radius: s * 5,
      shadowColor: const Color(0xFFE11D48),
      shadowAlpha: 0.3,
      shadowBlur: s * 4,
      shadowOffset: Offset(0, s),
      child: Text('$percent% OFF', style: GoogleFonts.inter(fontSize: s * 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
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

class ProductImage extends StatelessWidget {
  final Product product;
  final bool isFood;
  final double s;

  const ProductImage({super.key, required this.product, required this.isFood, required this.s});

  @override
  Widget build(BuildContext context) {
    final imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      final resolved = imgUrl.startsWith('/') ? 'https://www.fastkirana.in$imgUrl' : imgUrl;
      return ClipRRect(
        borderRadius: BorderRadius.circular(s * 13),
        child: Container(
          color: isFood ? const Color(0xFFFFF7ED) : Colors.transparent,
          padding: isFood ? EdgeInsets.all(s * 6) : EdgeInsets.zero,
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
    if (lower.contains('milk')) return '👛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('butter') || lower.contains('ghee')) return '🧈';
    if (lower.contains('cheese') || lower.contains('paneer')) return '🏁';
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
    if (lower.contains('coke') || lower.contains('cola') || lower.contains('pepsi')) return '💤';
    if (lower.contains('ice cream') || lower.contains('kulfi')) return '🍦';
    if (lower.contains('tea') || lower.contains('chai')) return '☕';
    if (lower.contains('coffee')) return '☕';
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('roll') || lower.contains('frankie')) return '🌯';
    return '🍽️';
  }
}

class PriceRow extends StatelessWidget {
  final String priceText;
  final String? mrpText;
  final double s;

  const PriceRow({super.key, required this.priceText, this.mrpText, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          priceText,
          style: GoogleFonts.inter(fontSize: s * 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3, height: 1.1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (mrpText != null)
          Padding(
            padding: EdgeInsets.only(top: s * 1.5),
            child: Text(
              mrpText!,
              style: GoogleFonts.inter(fontSize: s * 9.5, fontWeight: FontWeight.w500, decoration: TextDecoration.lineThrough, color: const Color(0xFF94A3B8), height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class AddToCartButton extends ConsumerWidget {
  final BuildContext scaffoldContext;
  final Product product;
  final int inCartQty;
  final bool hasVariants;
  final bool isOutOfStock;
  final bool isTimingClosed;
  final String? nextSlot;
  final bool isStoreOpen;
  final bool isFood;
  final List<Color> gradientColors;
  final Color primaryColor;
  final double uiScale;

  const AddToCartButton({
    super.key,
    required this.scaffoldContext,
    required this.product,
    required this.inCartQty,
    required this.hasVariants,
    required this.isOutOfStock,
    required this.isTimingClosed,
    this.nextSlot,
    required this.isStoreOpen,
    required this.isFood,
    required this.gradientColors,
    required this.primaryColor,
    required this.uiScale,
  });

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Out of Stock
    if (isOutOfStock) return _soldOut();
    // 2. Timing Closed
    if (isTimingClosed) return _timingClosed();
    // 3. Store Closed
    if (!isStoreOpen) return _storeClosed();
    // 4. In Cart Stepper
    if (inCartQty > 0) return _stepper(context, ref);
    // 5. Default ADD
    return _addButton(context, ref);
  }

  Widget _soldOut() {
    return Container(
      height: s(30),
      padding: EdgeInsets.symmetric(horizontal: s(10)),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(s(8)), border: Border.all(color: const Color(0xFFE2E8F0), width: s(1))),
      alignment: Alignment.center,
      child: Text('SOLD OUT', style: GoogleFonts.inter(fontSize: s(9), fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.3)),
    );
  }

  Widget _timingClosed() {
    return Container(
      height: s(30),
      padding: EdgeInsets.symmetric(horizontal: s(8)),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(s(8)), border: Border.all(color: const Color(0xFFFDE68A), width: s(1))),
      alignment: Alignment.center,
      child: Text(nextSlot != null ? 'Next @ $nextSlot' : 'Closed', style: GoogleFonts.inter(fontSize: s(9), fontWeight: FontWeight.w800, color: const Color(0xFFD97706), letterSpacing: 0.1)),
    );
  }

  Widget _storeClosed() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: s(8)),
                Expanded(
                  child: Text(
                    isFood ? '${product.restaurant?.name ?? "This Restaurant"} is currently closed.' : 'FastKirana Grocery Darkstore is currently closed.',
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
        height: s(30),
        padding: EdgeInsets.symmetric(horizontal: s(10)),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(s(8)), border: Border.all(color: const Color(0xFFE2E8F0), width: s(1))),
        alignment: Alignment.center,
        child: Text('CLOSED', style: GoogleFonts.inter(fontSize: s(9), fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.3)),
      ),
    );
  }

  Widget _stepper(BuildContext context, WidgetRef ref) {
    return Container(
      height: s(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(s(8)),
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.28), blurRadius: s(6), offset: Offset(0, s(2)))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            child: SizedBox(width: s(26), height: s(30), child: Center(child: Icon(Icons.remove_rounded, size: s(14), color: Colors.white))),
          ),
          Container(constraints: BoxConstraints(minWidth: s(18)), alignment: Alignment.center, child: Text('$inCartQty', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: s(12), letterSpacing: -0.2))),
          InkWell(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(s(8))),
            onTap: () {
              if (hasVariants) {
                VariantSelectorSheet.show(context, product);
              } else {
                if (inCartQty >= product.stock) {
                  HapticFeedback.heavyImpact();
                  _showStockLimitSnackbar();
                  return;
                }
                final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                if (conflict != null) {
                  _showConflictDialog(context, ref);
                } else {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).increment(product);
                }
              }
            },
            child: SizedBox(width: s(26), height: s(30), child: Center(child: Icon(Icons.add_rounded, size: s(14), color: Colors.white))),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context, WidgetRef ref) {
    return Bounceable(
      scaleFactor: 0.94,
      onTap: () {
        if (hasVariants) {
          VariantSelectorSheet.show(context, product);
        } else {
          _handleAdd(context, ref);
        }
      },
      child: Container(
        height: s(30),
        padding: EdgeInsets.symmetric(horizontal: s(11)),
        decoration: BoxDecoration(
          color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(color: isFood ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC), width: s(1.2)),
          boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.12), blurRadius: s(5), offset: Offset(0, s(2)))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ADD', style: GoogleFonts.inter(fontSize: s(11), fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 0.4)),
            SizedBox(width: s(3)),
            Icon(Icons.add_rounded, size: s(14), color: primaryColor),
          ],
        ),
      ),
    );
  }

  void _showStockLimitSnackbar() {
    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
            SizedBox(width: s(8)),
            Expanded(child: Text('Only ${product.stock} units available in stock!', style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref) {
    CartConflictDialog.show(
      scaffoldContext,
      product: product,
      existingOutletName: ref.read(cartProvider.notifier).currentRestaurantName ?? '',
      groceryItemsCount: ref.read(cartProvider.notifier).groceryItemsCount,
      onConfirm: () => ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1),
    );
  }

  void _handleAdd(BuildContext context, WidgetRef ref) {
    if (product.stock <= 0 || !product.isAvailable) {
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('${product.name} is currently out of stock.'), backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10)))),
      );
      return;
    }
    final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflict != null) {
      _showConflictDialog(context, ref);
      return;
    }
    final success = ref.read(cartProvider.notifier).addProduct(product, 1);
    if (!success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
              SizedBox(width: s(8)),
              Expanded(child: Text('Cannot add more! Only ${product.stock} units available in stock.', style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white))),
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
}

// ─── Main ProductCard ─────────────────────────────────────────────────────

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final bool isCompact;
  final bool showOutlet;

  const ProductCard({super.key, required this.product, this.onTap, this.width, this.isCompact = false, this.showOutlet = true});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isPressed = false;
  bool _showAddedCheck = false;

  double get _uiScale {
    final cardWidth = widget.width ?? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;
    return (cardWidth / 155.0).clamp(1.0, 1.15);
  }

  double s(double v) => v * _uiScale;

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) => t.contains('non-veg') || t.contains('nonveg') || t == 'egg' || t.contains('chicken') || t.contains('mutton'))) return false;
    final nl = product.name.toLowerCase();
    if (nl.contains('chicken') || nl.contains('egg') || nl.contains('mutton') || nl.contains('fish')) return false;
    return true;
  }

  void _triggerAddAnimation() {
    setState(() => _showAddedCheck = true);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _showAddedCheck = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isFood = isRestaurantProduct(product);
    final isVeg = _isVeg(product);
    final cardWidth = widget.width ?? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 12) / 2;

    final variants = product.parsedVariants;
    final hasVariants = variants.isNotEmpty;
    final startingPrice = hasVariants ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b) : product.price;
    final startingMrp = hasVariants ? (variants.firstWhere((v) => v.price == startingPrice, orElse: () => variants.first).mrp) : product.mrp;
    final resolvedDiscount = startingMrp > startingPrice && startingMrp > 0 ? ((startingMrp - startingPrice) / startingMrp * 100).round() : product.discountPercentage;

    final timingStatus = isFood && product.availableStartTime != null && product.availableStartTime!.trim().isNotEmpty
        ? checkDishTimeAvailability(product.availableStartTime, product.availableEndTime)
        : const DishTimingStatus(isAvailableNow: true);

    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = (settings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    final isOutOfStock = product.stock <= 0 || !product.isAvailable;
    final isLowStock = !isFood && !isOutOfStock && product.stock > 0 && product.stock <= (product.minStock > 0 ? product.minStock : 10);

    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) => i.productId == product.id || i.productId.startsWith('${product.id}_')).toList() ?? [];
    final inCartQty = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final primaryColor = isFood ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final gradientColors = isFood ? const [Color(0xFFEA580C), Color(0xFFF97316)] : const [Color(0xFF15803D), Color(0xFF16A34A)];

    final imageHeight = widget.isCompact
        ? s(100)
        : Responsive.isSmallMobile(context) ? s(95) : (isFood ? 116 : 110) * _uiScale;

    final hasBadges = product.isBestsellerProduct || product.isTrending || product.isFlashDealProduct;

    return RepaintBoundary(
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
            padding: EdgeInsets.fromLTRB(s(6), s(6), s(6), s(7)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(s(18)),
              border: Border.all(color: isFood ? const Color(0xFFFED7AA).withValues(alpha: 0.5) : const Color(0xFFF1F5F9), width: s(1.2)),
              boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: s(10), offset: Offset(0, s(3)))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. IMAGE SHOWCASE
                _ImageShowcase(
                  product: product,
                  isFood: isFood,
                  uiScale: _uiScale,
                  imageHeight: imageHeight,
                  resolvedDiscount: resolvedDiscount,
                  hasBadges: hasBadges,
                  timingStatus: timingStatus,
                  isLowStock: isLowStock,
                  isOutOfStock: isOutOfStock,
                  showAddedCheck: _showAddedCheck,
                ),
                SizedBox(height: s(6)),

                // 2. VEG/NON-VEG + TITLE
                SizedBox(
                  height: s(34),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFood) VegNonVegIndicator(isVeg: isVeg, s: _uiScale),
                      Expanded(
                        child: Text(
                          product.name,
                          style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), height: 1.22, letterSpacing: -0.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: s(4)),

                // 3. VARIANT PILL / UNIT
                _VariantPill(product: product, variants: variants, hasVariants: hasVariants, isOutOfStock: isOutOfStock, isFood: isFood, uiScale: _uiScale),

                // 4. PRICE + ADD BUTTON
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: PriceRow(priceText: '₹${startingPrice.toInt()}', mrpText: startingMrp > startingPrice ? '₹${startingMrp.toInt()}' : null, s: _uiScale)),
                    SizedBox(width: s(4)),
                    AddToCartButton(
                      scaffoldContext: context,
                      product: product,
                      inCartQty: inCartQty,
                      hasVariants: hasVariants,
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
    );
  }
}

// ─── Image Showcase (Stack of badges, heart, outlet, overlays) ─────────────

class _ImageShowcase extends StatelessWidget {
  final Product product;
  final bool isFood;
  final double uiScale;
  final double imageHeight;
  final int resolvedDiscount;
  final bool hasBadges;
  final DishTimingStatus timingStatus;
  final bool isLowStock;
  final bool isOutOfStock;
  final bool showAddedCheck;

  const _ImageShowcase({
    required this.product,
    required this.isFood,
    required this.uiScale,
    required this.imageHeight,
    required this.resolvedDiscount,
    required this.hasBadges,
    required this.timingStatus,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.showAddedCheck,
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
            child: Hero(tag: 'product_image_${product.id}', child: ProductImage(product: product, isFood: isFood, s: s)),
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
                  if (product.isBestsellerProduct) ProductBadge.bestseller(s: s)
                  else if (product.isTrending) ProductBadge.trending(s: s)
                  else if (product.isFlashDealProduct) ProductBadge.flashDeal(s: s),
                  if (resolvedDiscount > 0) ProductBadge.discount(resolvedDiscount, s: s),
                ],
              ),
            ),

          // Time Slot Badge
          if (!timingStatus.isAvailableNow && timingStatus.formattedTimeSlot != null)
            Positioned(
              top: (resolvedDiscount > 0 || hasBadges) ? s * 24 : s * 5,
              left: s * 5,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: s * 5, vertical: s * 2),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(s * 6), boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: s * 4, offset: Offset(0, s))]),
                child: Text('⏰ ${timingStatus.formattedTimeSlot}', style: GoogleFonts.inter(fontSize: s * 8, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),

          // Wishlist Heart
          Positioned(top: s * 5, right: s * 5, child: WishlistButton(product: product, s: s)),

          // Outlet / Bestseller Tag
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

// ─── Variant Pill ─────────────────────────────────────────────────────────

class _VariantPill extends StatelessWidget {
  final Product product;
  final List variants;
  final bool hasVariants;
  final bool isOutOfStock;
  final bool isFood;
  final double uiScale;

  const _VariantPill({required this.product, required this.variants, required this.hasVariants, required this.isOutOfStock, required this.isFood, required this.uiScale});

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context) {
    if (hasVariants) {
      return GestureDetector(
        onTap: () { if (!isOutOfStock) VariantSelectorSheet.show(context, product); },
        child: Container(
          margin: EdgeInsets.only(bottom: s(5)),
          padding: EdgeInsets.symmetric(horizontal: s(6), vertical: s(2.5)),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(6)), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${variants.length} Options', style: GoogleFonts.inter(fontSize: s(9), fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
              SizedBox(width: s(2)),
              Icon(Icons.keyboard_arrow_down_rounded, size: s(12), color: const Color(0xFF64748B)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: s(5)),
      child: Text(
        product.unit.isNotEmpty && product.unit != '1 unit' ? product.unit : (isFood ? 'Serves 1' : '1 pc'),
        style: GoogleFonts.inter(fontSize: s(10), fontWeight: FontWeight.w500, color: const Color(0xFF64748B), letterSpacing: -0.1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    final uiScale = (cardWidth / 155.0).clamp(1.0, 1.15);
    double s(double v) => v * uiScale;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(s(8)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(s(18)), border: Border.all(color: const Color(0xFFF1F5F9), width: s(1.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: isCompact ? s(100) : s(118), width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(14)))),
          SizedBox(height: s(8)),
          Container(width: s(80), height: s(10), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
          SizedBox(height: s(6)),
          Container(width: double.infinity, height: s(14), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
          SizedBox(height: s(6)),
          Container(width: s(45), height: s(12), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
          SizedBox(height: s(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: s(40), height: s(14), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(4)))),
              Container(width: s(58), height: s(27), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(s(8)))),
            ],
          ),
        ],
      ),
    );
  }
}
