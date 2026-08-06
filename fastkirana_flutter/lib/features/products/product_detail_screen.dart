import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/brand_button.dart';
import '../../widgets/brand_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppDesignSystem.surface,
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: product.imageUrl ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppDesignSystem.borderLight,
                      child: const Icon(Icons.image_not_supported, size: 80),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _buildDiscountBadge(),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductInfo(product),
                  const SizedBox(height: 24),
                  _buildPriceSection(product),
                  const SizedBox(height: 24),
                  _buildDescription(product),
                  const SizedBox(height: 24),
                  _buildQuantitySelector(),
                  const SizedBox(height: 24),
                  BrandButton(
                    text: 'Add to Cart',
                    onPressed: () {
                      ref.read(cartProvider.notifier).addItem(product.id, _quantity);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${_quantity} item(s) added to cart'),
                          backgroundColor: AppDesignSystem.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icons.shopping_cart_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountBadge() {
    if (widget.product.discountPercentage <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${widget.product.discountPercentage}% OFF',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProductInfo(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.category.name,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppDesignSystem.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 18, color: AppDesignSystem.warning),
            const SizedBox(width: 4),
            Text(
              '4.5',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '(${product.unit})',
              style: GoogleFonts.poppins(fontSize: 13, color: AppDesignSystem.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.mrp > product.price)
                Text(
                  Helpers.formatPrice(product.mrp),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppDesignSystem.textTertiary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Row(
                children: [
                  Text(
                    Helpers.formatPrice(product.price),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                  if (product.discountPercentage > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Save ${Helpers.formatPrice(product.savings)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppDesignSystem.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: AppDesignSystem.accent),
                const SizedBox(width: 4),
                Text(
                  'In Stock',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

  Widget _buildDescription(Product product) {
    if (product.description == null || product.description!.isEmpty) return const SizedBox.shrink();
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 8),
          Text(
            product.description!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppDesignSystem.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text('Quantity:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: AppDesignSystem.borderLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}