import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/brand_button.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  final PageController _imageController = PageController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartAsync = ref.watch(cartProvider);
    final isInCart = cartAsync.value?.items.any((i) => i.productId == product.id) ?? false;
    final isLowStock = product.stock > 0 && product.stock <= (product.minStock ?? 5);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _buildImageCarousel(product),
                _buildDetailsContent(product, isLowStock, isInCart, cartAsync.value),
              ],
            ),
          ),
          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 20),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.favorite_border_rounded, size: 20, color: AppDesignSystem.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(Product product) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: AppDesignSystem.shadowCard,
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _imageController,
            physics: const BouncingScrollPhysics(),
            itemCount: 2,
            itemBuilder: (context, index) {
              return Center(
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.contain,
                        width: 280,
                        height: 280,
                        errorWidget: (_, __, ___) => _buildEmojiPlaceholder(product),
                        placeholder: (_, __) => _buildEmojiPlaceholder(product),
                      )
                    : _buildEmojiPlaceholder(product),
              );
            },
          ),

          // Top badges
          Positioned(
            top: 60,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.isFlashDeal) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('FLASH DEAL', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                ],
                if (product.discountPercentage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${product.discountPercentage}% OFF', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
              ],
            ),
          ),

          // Delivery time badge
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Text('10-15 MINS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
            ),

          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppDesignSystem.primary : AppDesignSystem.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPlaceholder(Product product) {
    return Text(_getEmoji(product.name), style: const TextStyle(fontSize: 100));
  }

  Widget _buildDetailsContent(Product product, bool isLowStock, bool isInCart, dynamic cart) {
    return Container(
      decoration: const BoxDecoration(
        color: AppDesignSystem.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name and category
                Text(
                  product.category?.name ?? 'Grocery',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (product.isBestSeller) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('⭐ BESTSELLER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppDesignSystem.warning)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product.unit,
                  style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary),
                ),
              ],
            ),
          ),

          // Rating info (available when backend returns review data)
          if (product.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: product.tags.take(5).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDesignSystem.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.border),
                ),
                child: Text(tag, style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
              )).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Price Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.primary,
                            ),
                          ),
                          if (product.mrp > product.price) ...[
                            const SizedBox(width: 10),
                            Text(
                              '₹${product.mrp.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: AppDesignSystem.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.mrp > product.price)
                        Text(
                          'You save ₹${(product.mrp - product.price).toInt()}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.success, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppDesignSystem.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${product.discountPercentage}%',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text('OFF', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLowStock) ...[
            const SizedBox(height: 16),
            _buildLowStockWarning(product.stock),
          ],

          const SizedBox(height: 20),

          // Quantity Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantity',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
                  ),
                  Row(
                    children: [
                      _qtyButton(Icons.remove_rounded, () {
                        if (_quantity > 1) setState(() => _quantity--);
                      }),
                      Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: Text('$_quantity', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      _qtyButton(Icons.add_rounded, () => setState(() => _quantity++)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Delivery info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.delivery_dining_rounded, size: 18, color: AppDesignSystem.primary),
                const SizedBox(width: 8),
                Text('Delivery in 10-15 mins', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('FREE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bottom Action Bar (inside scrollable content)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(cartProvider.notifier).addItem(product.id, _quantity);
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$_quantity x ${product.name} added to cart'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppDesignSystem.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isInCart ? Icons.check_rounded : Icons.add_circle_rounded, size: 20),
                    label: Text(
                      isInCart ? 'Add More to Cart' : 'Add to Cart',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLowStockWarning(int stock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Only $stock left in stock — Grab it before it\'s gone!',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppDesignSystem.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppDesignSystem.primary),
      ),
    );
  }

  String _getEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('ice')) return '🍦';
    if (lower.contains('choco')) return '🍫';
    return '🛒';
  }
}
