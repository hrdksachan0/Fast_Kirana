import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/design_system.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../features/products/product_detail_screen.dart';

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isPressed = false;

  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color brandRed = Color(0xFFE20A22);

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartState = ref.watch(cartProvider);
    final items = cartState.value?.items.where((i) => i.productId == product.id).toList() ?? [];
    final cartItem = items.isNotEmpty ? items.first : null;
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);

    final bgColors = [
      const Color(0xFFF9FAFB),
      const Color(0xFFFFF7ED),
      const Color(0xFFF0F9FF),
      const Color(0xFFFEFCE8),
      const Color(0xFFF0FDF4),
    ];
    final cardBgColor = bgColors[product.id.hashCode.abs() % bgColors.length];
    final mins = [8, 10, 12, 15][product.id.hashCode.abs() % 4];

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap ??
          () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
          },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 156,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Container
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Stack(
                  children: [
                    // Center Image
                    Center(child: _buildProductImage(product)),

                    // Top Left: Express Delivery Pill
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 9)),
                            const SizedBox(width: 2),
                            Text(
                              '$mins MINS',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right: Wishlist Icon
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),

                    // Bottom Left: Discount Badge
                    if (product.discountPercentage > 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product.discountPercentage}% OFF',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Bestseller Badge (if no discount)
                    if (product.isBestSeller && product.discountPercentage == 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            '⭐ BESTSELLER',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info & Price/ADD Row
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Unit/Pack + ADD Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product.unit,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                          _buildAddButton(product, inCartQty, cartItem?.id),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹${product.price.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                          if (product.mrp > product.price) ...[
                            const SizedBox(width: 4),
                            Text(
                              '₹${product.mrp.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Product Name
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl!,
          height: 75,
          width: 75,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => Center(child: Text(_getEmojiForProduct(product.name), style: const TextStyle(fontSize: 40))),
          placeholder: (_, __) => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: brandRed))),
        ),
      );
    }
    return Text(_getEmojiForProduct(product.name), style: const TextStyle(fontSize: 40));
  }

  Widget _buildAddButton(Product product, int inCartQty, String? cartItemId) {
    if (inCartQty > 0 && cartItemId != null) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: brandRed,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: brandRed.withOpacity(0.25),
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
                ref.read(cartProvider.notifier).updateQuantity(cartItemId, inCartQty - 1);
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.remove, size: 14, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$inCartQty',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).addItem(product.id, 1);
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addItem(product.id, 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00B140), width: 1.5),
        ),
        child: Text(
          'ADD',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF00B140),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _getEmojiForProduct(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ramen') || lower.contains('noodle')) return '🍜';
    if (lower.contains('chicken') || lower.contains('butter')) return '🍛';
    if (lower.contains('mac') || lower.contains('cheese')) return '🧀';
    if (lower.contains('ghee')) return '🧈';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('sauce')) return '🥫';
    if (lower.contains('chips')) return '🍟';
    if (lower.contains('pasta') || lower.contains('oats')) return '🥣';
    if (lower.contains('poha') || lower.contains('dalia')) return '🍚';
    if (lower.contains('soya')) return '🫘';
    if (lower.contains('parwal') || lower.contains('vegetable')) return '🥬';
    if (lower.contains('lemon')) return '🍋';
    if (lower.contains('coriander')) return '🌿';
    if (lower.contains('brinjal')) return '🍆';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍦';
    if (lower.contains('vanilla')) return '🍨';
    if (lower.contains('cone')) return '🍦';
    if (lower.contains('bhelpuri')) return '🥨';
    if (lower.contains('hide')) return '🍪';
    if (lower.contains('choco pie')) return '🍪';
    if (lower.contains('mixture')) return '🥜';
    if (lower.contains('hing')) return '🧂';
    if (lower.contains('pepper')) return '🌶️';
    if (lower.contains('methi')) return '🌿';
    return '🛒';
  }
}
