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

  static const Color primaryRed = Color(0xFFB50017);
  static const Color textDark = Color(0xFF1C0D0F);
  static const Color textMuted = Color(0xFF9D4852);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Image Card Container
            Container(
              height: 125,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8EA)),
              ),
              child: Stack(
                children: [
                  // Center Image / Emoji
                  Center(
                    child: _buildProductImage(product),
                  ),

                  // Top Left Delivery Time Badge
                  Positioned(
                    top: 6,
                    left: 6,
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
                          Text(
                            '$mins MINS',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Right Add Button (+)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _buildAddButton(product, inCartQty, cartItem?.id),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Product Details
            Text(
              product.name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              product.unit,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 4),

            // Price & Discount Pill Row
            Row(
              children: [
                Text(
                  '₹${product.price.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                const SizedBox(width: 4),
                if (product.mrp > product.price) ...[
                  Text(
                    '₹${product.mrp.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (product.discountPercentage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: greenPillBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${product.discountPercentage}% OFF',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: greenPillText,
                      ),
                    ),
                  )
                else if (product.isTopPick)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: greenPillBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'BEST PRICE',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: greenPillText,
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
          errorWidget: (_, __, ___) => Center(
            child: Text(
              _getEmojiForProduct(product.name),
              style: const TextStyle(fontSize: 42),
            ),
          ),
          placeholder: (_, __) => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
            ),
          ),
        ),
      );
    }
    return Text(
      _getEmojiForProduct(product.name),
      style: const TextStyle(fontSize: 42),
    );
  }

  Widget _buildAddButton(Product product, int inCartQty, String? cartItemId) {
    if (inCartQty > 0 && cartItemId != null) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: primaryRed,
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
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.remove, size: 12, color: Colors.white),
              ),
            ),
            Text(
              '$inCartQty',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).addItem(product.id, 1);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.add, size: 12, color: Colors.white),
              ),
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
          border: Border.all(color: const Color(0xFFF4E7E8)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.add, size: 18, color: primaryRed),
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
    return '🛒';
  }
}