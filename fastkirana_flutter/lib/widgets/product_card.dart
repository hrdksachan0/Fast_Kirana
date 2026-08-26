import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shimmer/shimmer.dart';
import '../core/routes/page_transitions.dart';
import '../core/utils/restaurant_utils.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/store_settings_provider.dart';
import '../features/products/product_detail_screen.dart';
import 'cart_conflict_dialog.dart';

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
    return isCafeProduct(product);
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

    // Live Web App Store & Restaurant Open/Close Sync
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = (settings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap ??
          () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              FadeSlideRoute(page: ProductDetailScreen(product: product)),
            );
          },
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. PRODUCT IMAGE SHOWCASE BOX (Matrix Standardized)
              Container(
                height: widget.isCompact ? 100 : 114,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 0.8),
                ),
                child: Stack(
                  children: [
                    // Edge-to-Edge Product Photo
                    Positioned.fill(
                      child: Hero(
                        tag: 'product_image_${product.id}',
                        child: _buildProductImage(product, isFood),
                      ),
                    ),

                    // Top Left: Discount Badge
                    if (product.discountPercentage > 0)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFF97316)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(5),
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
                              fontSize: 8,
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
                                size: 13,
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
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(5),
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
              const SizedBox(height: 7),

              // 2. VEG / NON-VEG + PRODUCT TITLE (Exact 32px Matrix Height for 100% Horizontal Alignment)
              SizedBox(
                height: 32,
                child: Row(
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
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),

              // 3. UNIT / PACK INFO (Exact 15px Matrix Height)
              SizedBox(
                height: 15,
                child: Text(
                  product.unit.isNotEmpty ? product.unit : (isFood ? 'Freshly Prepared' : '1 unit'),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),

              // 4. BOTTOM BAR: PRICE + PREMIUM ADD BUTTON (Exact 32px Matrix Height)
              SizedBox(
                height: 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price Stack
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${product.price.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.2,
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

                    // ADD Button / Stepper (Or CLOSED badge if store/restaurant is off in admin)
                    _buildAddButton(
                      product,
                      inCartQty,
                      items.isNotEmpty ? items.first.id : null,
                      themeGradient,
                      primaryColor,
                      isStoreOpen: isStoreOpen,
                      isFood: isFood,
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

  Widget _buildProductImage(Product product, bool isFood) {
    var imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('/')) {
        imgUrl = 'https://www.fastkirana.in$imgUrl';
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: imgUrl,
          fit: isFood ? BoxFit.cover : BoxFit.contain,
          memCacheWidth: 400,
          memCacheHeight: 400,
          maxWidthDiskCache: 600,
          maxHeightDiskCache: 600,
          fadeInDuration: const Duration(milliseconds: 180),
          errorWidget: (context, url, error) => Center(
            child: Text(
              _getEmojiForProduct(product.name),
              style: const TextStyle(fontSize: 36),
            ),
          ),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFFAFAFA),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForProduct(product.name),
        style: const TextStyle(fontSize: 36),
      ),
    );
  }

  void _handleAddToCart(BuildContext context, Product product) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant != null) {
      final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
      final newOutlet = getOutletName(product);
      CartConflictDialog.show(
        context,
        product: product,
        existingOutletName: conflictRestaurant,
        groceryItemsCount: groceryCount,
        onConfirm: () {
          ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1);
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
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addProduct(product, 1);
  }

  void _handleIncrement(BuildContext context, Product product) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant != null) {
      _handleAddToCart(context, product);
      return;
    }
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).increment(product);
  }

  Widget _buildAddButton(
    Product product,
    int inCartQty,
    String? cartItemId,
    List<Color> themeGradient,
    Color primaryColor, {
    bool isStoreOpen = true,
    bool isFood = false,
  }) {
    if (!isStoreOpen) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFood
                          ? '${product.restaurant?.name ?? "This Restaurant"} is currently closed for orders.'
                          : 'FastKirana Grocery Darkstore is currently resting & closed.',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'CLOSED',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

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
              onTap: () => _handleIncrement(context, product),
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
      onTap: () => _handleAddToCart(context, product),
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

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  final bool isCompact;

  const ProductCardSkeleton({
    super.key,
    this.width,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (isCompact ? 138 : 156),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFF1F5F9),
        highlightColor: const Color(0xFFFAFAFA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Box
            Container(
              height: isCompact ? 100 : 114,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 7),

            // Title Line (Exact 32px)
            Container(
              height: 32,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 2),

            // Unit Line (Exact 15px)
            Container(
              height: 15,
              width: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),

            // Price & Add Button Row (Exact 32px)
            SizedBox(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 16,
                    width: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
