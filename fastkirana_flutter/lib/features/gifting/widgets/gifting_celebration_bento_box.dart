import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/cart.dart';
import '../../../../data/models/gifting_store_config.dart';
import '../../../../core/theme/responsive.dart';
import '../../products/product_detail_screen.dart';
import '../../../../core/routes/page_transitions.dart';

/// The Celebration Edit Bento Box (Option A - Zepto Scalloped Liquid Style)
/// Unified luxury bento card with connected liquid squircle tabs and spacious 2-column cards.
class GiftingCelebrationBentoBox extends StatelessWidget {
  final List<GiftingOccasionModel> occasions;
  final String selectedOccasion;
  final ValueChanged<String> onOccasionChanged;
  final List<Product> products;
  final List<CartItem> cartItems;
  final Function(Product) onAddToCart;
  final Function(Product) onIncrement;
  final Function(Product) onDecrement;

  const GiftingCelebrationBentoBox({
    super.key,
    required this.occasions,
    required this.selectedOccasion,
    required this.onOccasionChanged,
    required this.products,
    required this.cartItems,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF3CDD7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF881337).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Sleek Soft-Rose Luxury Header Band (Zero harsh contrast)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF0F3), Color(0xFFFFE4E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFF3CDD7), width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCE7F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🌸', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thoughtful Gifts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF881337),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4.5),
                      Text(
                        'Live Stock',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Glassmorphic Liquid Connected Tabs (Big Image on Top, Name Below)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFDE8EF),
                  Color(0xFFF9D2E0),
                  Color(0xFFF7C7D7),
                ],
              ),
              border: Border(
                top: BorderSide(color: Color(0x99FFFFFF), width: 1.2),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const tabWidth = 84.0;
                const tabHeight = 104.0;
                const sidePadding = 12.0;
                final fullWidth = math.max(
                  constraints.maxWidth,
                  sidePadding * 2 + (tabWidth * occasions.length),
                );
                final activeIdx = occasions.indexWhere((o) => o.label == selectedOccasion);
                final selectedIdx = activeIdx >= 0 ? activeIdx : 0;
                final targetX = sidePadding + (selectedIdx * tabWidth);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: fullWidth,
                    height: tabHeight,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      tween: Tween<double>(end: targetX),
                      builder: (context, animX, child) => CustomPaint(
                        painter: _GiftingConnectedTabPainter(
                          x: animX,
                          width: tabWidth,
                          radius: 22,
                          color: const Color(0xFFF3CDD7),
                          fill: Colors.white,
                          lineWidth: 1.2,
                        ),
                        child: child,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                        child: Row(
                          children: [
                            for (int i = 0; i < occasions.length; i++) ...[
                              _buildOccasionTab(
                                occasions[i],
                                occasions[i].label == selectedOccasion,
                                tabWidth,
                                tabHeight,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Products Shelf Inside the Bento Box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtitle Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Curated for $selectedOccasion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF591020),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        'Free Handwritten Note 💌',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFBE123C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2-Column Spacious Luxury Grid
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🌸', style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 8),
                          Text(
                            'Fresh $selectedOccasion items arriving soon',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
                      childAspectRatio: 0.69,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final inCartCount = cartItems
                          .where((item) => (item.product.id == product.id) || (item.productId == product.id))
                          .fold<int>(0, (sum, item) => sum + item.quantity);

                      return _LuxuryGiftingCard(
                        product: product,
                        inCartCount: inCartCount,
                        onAdd: () => onAddToCart(product),
                        onIncrement: () => onIncrement(product),
                        onDecrement: () => onDecrement(product),
                      );
                    },
                  ),

                const SizedBox(height: 10),

                // 4. Quality Guarantee Footer
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF5E1E7))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🌸', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            'Packed with satin ribbon',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('🔒', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            'Price hidden on box',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF881337),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionTab(
    GiftingOccasionModel occ,
    bool isSelected,
    double tabWidth,
    double tabHeight,
  ) {
    final imgUrl = _getOccasionImageUrl(occ);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onOccasionChanged(occ.label);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tabWidth,
        height: tabHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Big Avatar Image with Glowing Glass Ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 52 : 46,
              height: isSelected ? 52 : 46,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.white.withValues(alpha: 0.85)],
                      ),
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 2.0 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFBE123C).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFFFF1F2),
                    child: Center(
                      child: Text(occ.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFFFF1F2),
                    child: Center(
                      child: Text(occ.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 2. Name BELOW Image (name image ke nichee)
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: GoogleFonts.plusJakartaSans(
                fontSize: isSelected ? 11.5 : 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? const Color(0xFF881337) : const Color(0xFF641E30),
                height: 1.15,
              ),
              child: Text(
                occ.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _getOccasionImageUrl(GiftingOccasionModel occ) {
    if (occ.imageUrl.trim().isNotEmpty) return occ.imageUrl;
    final label = occ.label.toLowerCase();
    if (label.contains('birth')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=200&q=80';
    } else if (label.contains('anniv') || label.contains('love') || label.contains('romance')) {
      return 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=200&q=80';
    } else if (label.contains('rose') || label.contains('flower') || label.contains('bloom')) {
      return 'https://images.unsplash.com/photo-1561181286-d3fee7d55364?w=200&q=80';
    } else if (label.contains('cake') || label.contains('bake') || label.contains('pastry')) {
      return 'https://images.unsplash.com/photo-1535141192574-5d4897c13136?w=200&q=80';
    } else if (label.contains('choc')) {
      return 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=200&q=80';
    } else if (label.contains('hamper') || label.contains('combo') || label.contains('box')) {
      return 'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?w=200&q=80';
    }
    return 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=200&q=80';
  }
}

/// Continuous Connected Liquid Tab Painter for Gifting Bento Box
class _GiftingConnectedTabPainter extends CustomPainter {
  final double x;
  final double width;
  final double radius;
  final Color color;
  final Color fill;
  final double lineWidth;

  const _GiftingConnectedTabPainter({
    required this.x,
    required this.width,
    required this.radius,
    required this.color,
    required this.fill,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 1.0;
    const filletR = 24.0;
    final topR = radius.clamp(18.0, 28.0);
    const top = 1.0;
    const k = 0.55228475;
    const invK = 1.0 - k;

    final tabLeft = x;
    final tabRight = x + width;

    final path = Path();
    path.moveTo(0, bottom);

    final effectiveLeftFillet = math.min(filletR, tabLeft).clamp(6.0, filletR);
    final leftScoopStartX = math.max(0.0, tabLeft - effectiveLeftFillet);

    if (leftScoopStartX > 0) {
      path.lineTo(leftScoopStartX, bottom);
    }

    path.cubicTo(
      leftScoopStartX + (effectiveLeftFillet * k),
      bottom,
      tabLeft,
      (bottom - effectiveLeftFillet) + (effectiveLeftFillet * invK),
      tabLeft,
      bottom - effectiveLeftFillet,
    );

    path.lineTo(tabLeft, top + topR);

    path.cubicTo(
      tabLeft,
      top + (topR * invK),
      tabLeft + (topR * invK),
      top,
      tabLeft + topR,
      top,
    );

    path.lineTo(tabRight - topR, top);

    path.cubicTo(
      tabRight - (topR * invK),
      top,
      tabRight,
      top + (topR * invK),
      tabRight,
      top + topR,
    );

    path.lineTo(tabRight, bottom - filletR);

    path.cubicTo(
      tabRight,
      (bottom - filletR) + (filletR * k),
      (tabRight + filletR) - (filletR * k),
      bottom,
      tabRight + filletR,
      bottom,
    );

    path.lineTo(size.width, bottom);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final shadowPaint = Paint()
      ..color = const Color(0xFF881337).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, shadowPaint);

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_GiftingConnectedTabPainter old) =>
      old.x != x ||
      old.width != width ||
      old.radius != radius ||
      old.color != color ||
      old.fill != fill ||
      old.lineWidth != lineWidth;
}

/// 2-Column Luxury Gifting Product Card (Option A)
class _LuxuryGiftingCard extends StatelessWidget {
  final Product product;
  final int inCartCount;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _LuxuryGiftingCard({
    required this.product,
    required this.inCartCount,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FadeSlideRoute(page: ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF2D7DF), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Photo Showcase with Luxury Tag & Heart
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFFFF5F7),
                                child: const Center(child: Text('🎁', style: TextStyle(fontSize: 22))),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFFFF5F7),
                                child: const Center(child: Text('🎁', style: TextStyle(fontSize: 22))),
                              ),
                            )
                          : const Center(child: Text('🎁', style: TextStyle(fontSize: 22))),
                    ),
                  ),

                  // Top-Right Wishlist Heart
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 2. Unit Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.unit.isNotEmpty ? product.unit : '1 pc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF881337),
                ),
              ),
            ),
            const SizedBox(height: 2),

            // 3. Product Title (2-lines max, fixed height 28px)
            SizedBox(
              height: 28,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // 4. Compact Price & Right-Aligned ADD Button Row (Zepto/Blinkit Style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Price & Strikethrough MRP on Left
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${product.price.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (product.mrp > product.price)
                      Text(
                        '₹${product.mrp.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),

                // Compact ADD Button / Stepper (Width: 64px, Height: 27px)
                inCartCount == 0
                    ? GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onAdd();
                        },
                        child: Container(
                          width: 64,
                          height: 27,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE11D48),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'ADD',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE11D48),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 27,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onDecrement();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: Icon(Icons.remove, size: 14, color: Colors.white),
                              ),
                            ),
                            Text(
                              '$inCartCount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onIncrement();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
