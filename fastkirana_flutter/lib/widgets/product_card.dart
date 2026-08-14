import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  static const Color primaryGreen = Color(0xFF047857);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color greenPillBg = Color(0xFFDCFCE7);
  static const Color greenPillText = Color(0xFF005319);

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartState = ref.watch(cartProvider);
    final items = cartState.value?.items.where((i) => i.productId == product.id).toList() ?? [];
    final cartItem = items.isNotEmpty ? items.first : null;
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);

    final bgColors = [
      const Color(0xFFF3F3F6),
      const Color(0xFFFFF7ED),
      const Color(0xFFF0F9FF),
      const Color(0xFFFEFCE8),
      const Color(0xFFF0FDF4),
    ];
    final cardBgColor = bgColors[product.id.hashCode.abs() % bgColors.length];
    final mins = [8, 10, 12, 15][product.id.hashCode.abs() % 4];

    final isLowStock = product.stock > 0 && product.stock <= (product.minStock ?? 5);

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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Card
              Container(
                height: 125,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border.all(color: const Color(0xFFE8E8EA)),
                ),
                child: Stack(
                  children: [
                    // Center Image / Emoji
                    Center(child: _buildProductImage(product)),

                    // Top Left: Delivery Time Badge
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_filled, size: 10, color: Color(0xFF475569)),
                            const SizedBox(width: 3),
                            Text('$mins MINS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ),

                    // Top Right: Discount Badge
                    if (product.discountPercentage > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product.discountPercentage}% OFF',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),

                    // Bottom Right: Flash Deal Badge
                    if (product.isFlashDeal)
                      Positioned(
                        bottom: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '🔥 Flash Deal',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),

                    // Bottom Left: Add / Quantity Button
                    Positioned(
                      bottom: 6, left: 6,
                      child: _buildAddButton(product, inCartQty, cartItem?.id),
                    ),

                    // Bottom Center: Low Stock Warning
                    if (isLowStock)
                      Positioned(
                        bottom: 6, left: 6,
                        child: _buildLowStockBadge(product.stock),
                      ),

                    // Top Right: Bestseller Badge (shows when no discount)
                    if (product.isBestSeller && product.discountPercentage == 0 && !product.isFlashDeal)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            '⭐ Bestseller',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Details
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.unit,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: textMuted),
                    ),
                    const SizedBox(height: 4),

                    // Price & Discount
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toInt()}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: textDark),
                        ),
                        const SizedBox(width: 4),
                        if (product.mrp > product.price) ...[
                          Text(
                            '₹${product.mrp.toInt()}',
                            style: GoogleFonts.inter(fontSize: 10, decoration: TextDecoration.lineThrough, color: textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
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
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl!,
          height: 80,
          width: 80,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => Center(child: Text(_getEmojiForProduct(product.name), style: const TextStyle(fontSize: 42))),
          placeholder: (_, __) => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)))),
        ),
      );
    }
    return Text(_getEmojiForProduct(product.name), style: const TextStyle(fontSize: 42));
  }

  Widget _buildAddButton(Product product, int inCartQty, String? cartItemId) {
    if (inCartQty > 0 && cartItemId != null) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: primaryGreen,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).updateQuantity(cartItemId, inCartQty - 1);
              },
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Icon(Icons.remove, size: 12, color: Colors.white)),
            ),
            Text('$inCartQty', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).addItem(product.id, 1);
              },
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Icon(Icons.add, size: 12, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addItem(product.id, 1);
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(Icons.add, size: 18, color: primaryGreen),
      ),
    );
  }

  Widget _buildLowStockBadge(int stock) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFEF3C7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Text(
              'Only $stock left',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
            ),
          ],
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
    if (lower.contains('cup')) return '🍦';
    return '🛒';
  }
}
