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
  bool _isFavorite = false;

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
    return true;
  }

  Color _getThemeColor(Product product) {
    if (_isFoodProduct(product)) {
      return const Color(0xFFF97316); // Cafe / Food Orange
    }
    return AppDesignSystem.accent; // Grocery Green (#00B140)
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartState = ref.watch(cartProvider);
    final items = cartState.value?.items.where((i) => i.productId == product.id).toList() ?? [];
    final cartItem = items.isNotEmpty ? items.first : null;
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);
    final themeColor = _getThemeColor(product);
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
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width ?? (widget.isCompact ? 136 : 148),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Box
              Container(
                height: widget.isCompact ? 96 : 106,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Stack(
                  children: [
                    // Center Product Image
                    Center(
                      child: Hero(
                        tag: 'product_image_${product.id}',
                        child: _buildProductImage(product),
                      ),
                    ),

                    // Top Left: Discount Badge (Red-Orange Gradient Pill)
                    if (product.discountPercentage > 0)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF43F5E).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${product.discountPercentage}% OFF',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Top Right: Wishlist Heart
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final isFav = ref.watch(wishlistProvider).any((p) => p.id == product.id);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(wishlistProvider.notifier).toggleWishlist(product);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
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
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 7.5)),
                              const SizedBox(width: 2),
                              Text(
                                'Bestseller',
                                style: GoogleFonts.inter(
                                  fontSize: 7.5,
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
              const SizedBox(height: 6),

              // Title & Veg Indicator Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFood) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 4),
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                      child: Center(
                        child: Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                            color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              // Unit / Pack info
              Text(
                product.unit,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Bottom Row: Price + ADD Stepper
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price & MRP
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${product.price.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (product.mrp > product.price)
                        Text(
                          '₹${product.mrp.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.lineThrough,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),

                  // Contextual ADD Button
                  _buildAddButton(product, inCartQty, cartItem?.id, themeColor),
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
        padding: const EdgeInsets.all(4),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl!,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => Center(
            child: Text(
              _getEmojiForProduct(product.name),
              style: const TextStyle(fontSize: 30),
            ),
          ),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFFFFFFF),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForProduct(product.name),
        style: const TextStyle(fontSize: 30),
      ),
    );
  }

  Widget _buildAddButton(Product product, int inCartQty, String? cartItemId, Color themeColor) {
    if (inCartQty > 0) {
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  Icons.remove,
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
                    fontSize: 11.5,
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
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.add, size: 14, color: Colors.white),
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.3),
              blurRadius: 5,
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
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.add, size: 13, color: Colors.white),
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
    return '🛒';
  }
}
