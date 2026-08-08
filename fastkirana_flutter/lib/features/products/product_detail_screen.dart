import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/brand_button.dart';
import 'package:badges/badges.dart' as badges;

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

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildImageCarousel(product),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      children: [
                        _buildProductInfo(product),
                        const SizedBox(height: 20),
                        _buildPriceAndOffer(product),
                        const SizedBox(height: 20),
                        _buildQuantitySelector(product),
                      ],
                    ),
                  ),
                ),
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
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Row(
                children: [
                  // Quantity Stepper
                  Container(
                    decoration: BoxDecoration(
                      color: AppDesignSystem.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_quantity > 1) setState(() => _quantity--);
                          },
                          icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppDesignSystem.primary),
                        ),
                        Text(
                          '$_quantity',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: Icon(Icons.add_circle_rounded, size: 20, color: AppDesignSystem.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(product.id, _quantity);
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_quantity x ${product.name} added'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppDesignSystem.success,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(isInCart ? Icons.check_rounded : Icons.add_circle_rounded, size: 20),
                      label: Text(
                        isInCart ? 'Add More' : 'Add to Cart',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
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
      height: 320,
      decoration: const BoxDecoration(
        color: AppDesignSystem.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _imageController,
            physics: const BouncingScrollPhysics(),
            itemCount: 2,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Hero(
                  tag: 'product-${product.id}-$index',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppDesignSystem.background,
                    ),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => _buildPlaceholder(),
                              placeholder: (_, __) => _buildPlaceholder(),
                            ),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
              );
            },
          ),

          // Discount Badge
          if (product.discountPercentage > 0)
            Positioned(
              top: 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppDesignSystem.accent, Color(0xFF4ADE80)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${product.discountPercentage}% OFF',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Dot Indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary,
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppDesignSystem.background,
      child: Center(
        child: Icon(Icons.shopping_basket_rounded, size: 80, color: AppDesignSystem.borderLight),
      ),
    );
  }

  Widget _buildProductInfo(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesignSystem.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                product.category?.name ?? 'Grocery',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesignSystem.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 12, color: AppDesignSystem.warning),
                  const SizedBox(width: 3),
                  Text(
                    '4.5',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          product.name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.unit,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppDesignSystem.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndOffer(Product product) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                    product.price.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (product.mrp > product.price)
                    Text(
                      '₹${product.mrp}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppDesignSystem.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              if (product.discountPercentage > 0)
                Text(
                  'You save ₹${(product.mrp - product.price)} on this item',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppDesignSystem.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (product.mrp > product.price)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.accent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '${product.discountPercentage}%',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.accent,
                    ),
                  ),
                  Text(
                    'OFF',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              _qtyButton(Icons.remove_rounded, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _qtyButton(Icons.add_rounded, () => setState(() => _quantity++)),
            ],
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
}