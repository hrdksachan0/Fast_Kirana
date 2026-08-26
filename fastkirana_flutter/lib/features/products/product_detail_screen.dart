import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart_conflict_dialog.dart';
import '../cart/cart_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selectedVariant;
  bool _isFavorite = false;
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color successGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    final variants = widget.product.parsedVariants;
    if (variants.isNotEmpty) {
      _selectedVariant = variants.first;
    }
  }

  void _promptRestaurantConflict(BuildContext context, Product product, String? variantName) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant == null) return;

    final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
    final newOutlet = getOutletName(product);

    CartConflictDialog.show(
      context,
      product: product,
      existingOutletName: conflictRestaurant,
      groceryItemsCount: groceryCount,
      onConfirm: () {
        ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1, variantName);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groceryCount > 0
                        ? 'Switched to $newOutlet. $groceryCount grocery item(s) kept safe in cart! 🛒'
                        : 'Switched to $newOutlet! 🍽️',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final variants = p.parsedVariants;
    final activePrice = _selectedVariant?.price ?? p.price;
    final activeMrp = _selectedVariant?.mrp ?? p.mrp;
    final activeUnit = _selectedVariant?.name ?? p.unit;

    final cart = ref.watch(cartProvider).value;
    final cartItem = cart?.items.where((i) => i.productId == p.id).firstOrNull;
    final inCartQty = cartItem?.quantity ?? 0;
    final discountPct = activeMrp > activePrice && activeMrp > 0
        ? (((activeMrp - activePrice) / activeMrp) * 100).toInt()
        : p.discount.toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: Stack(
          children: [
            // Scrollable Content
            ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // 1. Product Image Carousel with Discount Badge
              Stack(
                children: [
                  Container(
                    height: 360,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    child: Center(
                      child: Hero(
                        tag: 'product_image_${p.id}',
                        child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: p.imageUrl!,
                                height: 260,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(color: primaryRed),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Text('🛍️', style: TextStyle(fontSize: 72)),
                                ),
                              )
                            : const Center(
                                child: Text('🛍️', style: TextStyle(fontSize: 72)),
                              ),
                      ),
                    ),
                  ),

                  // Discount Badge
                  if (discountPct > 0)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$discountPct% OFF',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // 2. Product Details Box
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Speed Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            'FAST DELIVERY',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      p.name,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 150.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 150.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 4),

                    // Unit
                    Text(
                      activeUnit,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 250.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 250.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 14),

                    // Price and MRP Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${activePrice.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (activeMrp > activePrice) ...[
                          const SizedBox(width: 10),
                          Text(
                            '₹${activeMrp.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save ₹${(activeMrp - activePrice).toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 350.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 350.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 18),

                    // Variants / Pack Sizes (if available)
                    if (variants.isNotEmpty) ...[
                      Text(
                        'Select Pack Size / Variant',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: variants.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final variant = variants[index];
                            final isSelected = _selectedVariant?.name == variant.name;

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedVariant = variant);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? primaryRed : const Color(0xFFE5E7EB),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      variant.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? primaryRed : const Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      '₹${variant.price.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected ? primaryRed : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Product Highlights & Quality Promise
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _buildQualityRow('⚡ Superfast express delivery from local darkstore'),
                          const Divider(height: 16, color: Color(0xFFF3F4F6)),
                          _buildQualityRow('🛡️ 100% Genuine & Quality assured by FastKirana'),
                          const Divider(height: 16, color: Color(0xFFF3F4F6)),
                          _buildQualityRow('🔄 Hassle-free instant return at doorstep'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description (if exists)
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      Text(
                        'Product Details',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          p.description!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF4B5563),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // 3. Floating Glass Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF111827)),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isFavorite = !_isFavorite);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 20,
                              color: _isFavorite ? primaryRed : const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              FadeSlideRoute(page: const CartScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF111827)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Sticky Bottom Add to Cart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Price',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '₹${((inCartQty > 0 ? inCartQty : 1) * activePrice).toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: inCartQty > 0
                        ? Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: primaryRed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    ref.read(cartProvider.notifier).decrement(p.id);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.remove, size: 20, color: Colors.white),
                                  ),
                                ),
                                Text(
                                  '$inCartQty in Cart',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(p);
                                    if (conflictRestaurant != null) {
                                      _promptRestaurantConflict(context, p, _selectedVariant?.name);
                                      return;
                                    }
                                    HapticFeedback.lightImpact();
                                    ref.read(cartProvider.notifier).increment(p);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.add, size: 20, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              final productToCart = Product(
                                id: p.id,
                                name: p.name,
                                slug: p.slug,
                                description: p.description,
                                imageUrl: p.imageUrl,
                                categoryId: p.categoryId,
                                restaurantId: p.restaurantId,
                                mrp: activeMrp,
                                price: activePrice,
                                discount: activeMrp > activePrice ? ((activeMrp - activePrice) / activeMrp * 100) : 0,
                                unit: activeUnit,
                                stock: p.stock,
                                isAvailable: p.isAvailable,
                                tags: p.tags,
                                variants: p.variants,
                                minStock: p.minStock,
                                costPrice: p.costPrice,
                                isFlashDeal: p.isFlashDeal,
                                isTopPick: p.isTopPick,
                                isBestSeller: p.isBestSeller,
                                sortOrder: p.sortOrder,
                                createdAt: p.createdAt,
                                category: p.category,
                                restaurant: p.restaurant,
                              );

                              final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(productToCart);
                              if (conflictRestaurant != null) {
                                _promptRestaurantConflict(context, productToCart, _selectedVariant?.name);
                                return;
                              }

                              HapticFeedback.mediumImpact();
                              ref.read(cartProvider.notifier).addProduct(productToCart, 1, _selectedVariant?.name);
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryRed, Color(0xFFB30013)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryRed.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add to Cart',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildQualityRow(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}
