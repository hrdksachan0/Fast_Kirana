import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/design_system.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../features/products/product_detail_screen.dart';

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final bool isCompact;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width,
    this.isCompact = false,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isPressed = false;

  bool _isFoodProduct(Product product) {
    final cat = product.categoryId.toLowerCase();
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    return cat.contains('cafe') ||
        cat.contains('restaurant') ||
        cat.contains('food') ||
        tags.any((t) => t.contains('dish') || t.contains('cooked') || t.contains('restaurant'));
  }

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) => t.contains('non-veg') || t.contains('nonveg') || t == 'egg' || t.contains('chicken') || t.contains('mutton'))) {
      return false;
    }
    final nameLower = product.name.toLowerCase();
    if (nameLower.contains('chicken') || nameLower.contains('egg') || nameLower.contains('mutton') || nameLower.contains('fish')) {
      return false;
    }
    return true;
  }

  List<Color> _getThemeGradient(Product product) {
    if (_isFoodProduct(product)) {
      return const [Color(0xFFEA580C), Color(0xFFF97316)]; // Deep Orange to Bright Sunset
    }
    return const [Color(0xFF15803D), Color(0xFF16A34A)]; // Emerald Green
  }

  Color _getPrimaryColor(Product product) {
    if (_isFoodProduct(product)) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF15803D);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) => i.productId == product.id).toList() ?? [];
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);
    final themeGradient = _getThemeGradient(product);
    final primaryColor = _getPrimaryColor(product);
    final isFood = _isFoodProduct(product);
    final isVeg = _isVeg(product);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap ??
          () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
            );
          },
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width ?? (widget.isCompact ? 138 : 156),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
            children: [
              // 1. PRODUCT IMAGE SHOWCASE BOX
              Container(
                height: widget.isCompact ? 100 : 114,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 0.8),
                ),
                child: Stack(
                  children: [
                    // Centered Product Photo
                    Center(
                      child: Hero(
                        tag: 'product_image_${product.id}',
                        child: _buildProductImage(product),
                      ),
                    ),

                    // Top Left: Discount Badge
                    if (product.discountPercentage > 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFF97316)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${product.discountPercentage}% OFF',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),

                    // Top Right: Translucent Glass Wishlist Heart Button
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final isFav = ref.watch(wishlistProvider).any((p) => p.id == product.id);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(wishlistProvider.notifier).toggleWishlist(product);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
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

                    // Bottom Left: Bestseller Pill
                    if (product.isBestSeller)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 8)),
                              const SizedBox(width: 2),
                              Text(
                                'Bestseller',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. VEG / NON-VEG + PRODUCT TITLE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFood) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 5),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(3),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // 3. UNIT / PACK INFO
              Text(
                product.unit.isNotEmpty ? product.unit : '1 unit',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 4. BOTTOM BAR: PRICE + PREMIUM ADD BUTTON
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price Stack
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${product.price.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (product.mrp > product.price)
                        Text(
                          '₹${product.mrp.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.lineThrough,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),

                  // ADD Button / Stepper
                  _buildAddButton(product, inCartQty, items.isNotEmpty ? items.first.id : null, themeGradient, primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl!,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => Center(
            child: Text(
              _getEmojiForProduct(product.name),
              style: const TextStyle(fontSize: 32),
            ),
          ),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFFFFFFF),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForProduct(product.name),
        style: const TextStyle(fontSize: 32),
      ),
    );
  }

  Widget _buildAddButton(Product product, int inCartQty, String? cartItemId, List<Color> themeGradient, Color primaryColor) {
    if (inCartQty > 0) {
      return Container(
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).decrement(product.id);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Icon(
                  Icons.remove_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  '$inCartQty',
                  key: ValueKey<int>(inCartQty),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).increment(product);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Icon(Icons.add_rounded, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Bounceable(
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(cartProvider.notifier).addProduct(product, 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADD',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.add_rounded, size: 14, color: Colors.white),
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
