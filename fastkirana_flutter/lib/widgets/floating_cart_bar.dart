import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/routes/page_transitions.dart';
import '../core/services/location_service.dart';
import '../core/widgets/app_cached_image.dart';
import '../data/models/cart.dart';
import '../features/cart/cart_screen.dart';
import '../providers/cart_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 3D Fanned Mini-Card Product Deck (Shows last 1-3 added cart products)
// ─────────────────────────────────────────────────────────────────────────────

class _FannedCartProductDeck extends StatelessWidget {
  final List<CartItem> items;
  final int totalItemCount;
  final bool isFreeDelivery;

  const _FannedCartProductDeck({
    required this.items,
    required this.totalItemCount,
    required this.isFreeDelivery,
  });

  @override
  Widget build(BuildContext context) {
    // Take last 3 distinct products so the most recently added item pops on top
    final List<CartItem> distinct = [];
    final Set<String> seen = {};
    for (final item in items.reversed) {
      final pid = item.product.id.isNotEmpty ? item.product.id : item.productId;
      if (seen.add(pid)) {
        distinct.add(item);
        if (distinct.length == 3) break;
      }
    }
    final shown = distinct.reversed.toList();
    final int extraDistinct = math.max(0, items.length - shown.length);

    final List<double> angles = shown.length == 1
        ? [0.0]
        : shown.length == 2
            ? [-0.16, 0.12]
            : [-0.20, 0.0, 0.20];
    final List<double> offsets = shown.length == 1
        ? [0.0]
        : shown.length == 2
            ? [-6.0, 6.0]
            : [-9.0, 0.0, 9.0];

    return TweenAnimationBuilder<double>(
      key: ValueKey('fan_deck_$totalItemCount'),
      tween: Tween<double>(begin: 0.84, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: SizedBox(
        width: shown.length == 1 ? 40 : (shown.length == 2 ? 48 : 54),
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < shown.length; i++)
              Transform.translate(
                offset: Offset(offsets[i], i == shown.length - 1 ? -1.0 : 1.0),
                child: Transform.rotate(
                  angle: angles[i],
                  child: Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i == shown.length - 1
                            ? (isFreeDelivery
                                ? const Color(0xFF10B981)
                                : const Color(0xFFFDA4AF))
                            : const Color(0xFFE2E8F0),
                        width: i == shown.length - 1 ? 1.5 : 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.13),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _buildThumb(shown[i].product.imageUrl),
                    ),
                  ),
                ),
              ),
            if (extraDistinct > 0)
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    '+$extraDistinct',
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(String? imageUrl) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || url.startsWith('data:')) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: const Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFFE11D48)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: FastKiranaImageCacheManager.instance,
      fit: BoxFit.contain,
      memCacheWidth: 96,
      memCacheHeight: 96,
      placeholder: (_, __) => Container(color: const Color(0xFFF8FAFC)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFF8FAFC),
        child: const Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFFE11D48)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Universal Floating Cart Bar (Compact, Sleek & Pixel-Perfect)
// ─────────────────────────────────────────────────────────────────────────────

class FloatingCartBar extends ConsumerStatefulWidget {
  final double bottomOffset;

  const FloatingCartBar({
    super.key,
    this.bottomOffset = 16.0,
  });

  @override
  ConsumerState<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends ConsumerState<FloatingCartBar> {
  bool _isPressed = false;

  void _navigateToCart() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;

    if (cart == null || cart.totalItems == 0) {
      return const SizedBox.shrink();
    }

    final total = cart.subtotal;
    final itemCount = cart.totalItems;
    final tier = ref.watch(deliveryTierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = (screenWidth * 0.92).clamp(280.0, 410.0);

    final isFreeDelivery = tier.deliveryFee == 0;
    final remainingForFree = (tier.freeDeliveryThreshold - total).clamp(0.0, tier.freeDeliveryThreshold).toInt();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: widget.bottomOffset,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: barWidth,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, animValue, child) {
              return Transform.translate(
                offset: Offset(0, (1 - animValue) * 24),
                child: Opacity(
                  opacity: animValue.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  // 1. Crisp Edge Outline Shadow (kinare kinare dark contour taaki white background me mix na ho)
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                  // 2. Tight Contact Contour Shadow
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  // 3. Subtle FastMinute Crimson Ambient Glow
                  BoxShadow(
                    color: const Color(0xFFE20A22).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                    children: [
                      // 1. 3D Fanned Mini-Card Product Deck (shows last 1-3 added products)
                      _FannedCartProductDeck(
                        items: cart.items,
                        totalItemCount: itemCount,
                        isFreeDelivery: isFreeDelivery,
                      ),
                      const SizedBox(width: 8),

                      // 2. Minimalist Center Info with Clean Formatting (No Truncation)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _navigateToCart,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, anim) => SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.25),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: FadeTransition(opacity: anim, child: child),
                                    ),
                                    child: Text(
                                      '₹${total.toInt()}',
                                      key: ValueKey('price_${total.toInt()}'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, anim) => ScaleTransition(
                                      scale: anim,
                                      child: child,
                                    ),
                                    child: Text(
                                      '• $itemCount ${itemCount == 1 ? "item" : "items"}',
                                      key: ValueKey('count_$itemCount'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              if (!tier.isServiceable)
                                Text(
                                  '⚠️ Outside 5.0 km Hub',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE11D48),
                                  ),
                                )
                              else if (isFreeDelivery)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 10.5, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        'Free Delivery Unlocked',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Add ₹$remainingForFree for FREE Delivery',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE20A22),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 3. Compact FastMinute Crimson Gradient Button
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isPressed = true),
                        onTapUp: (_) => setState(() => _isPressed = false),
                        onTapCancel: () => setState(() => _isPressed = false),
                        onTap: _navigateToCart,
                        child: AnimatedScale(
                          scale: _isPressed ? 0.94 : 1.0,
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFE20A22), Color(0xFFB30013)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: _isPressed ? 0.20 : 0.38),
                                  blurRadius: _isPressed ? 5 : 10,
                                  offset: Offset(0, _isPressed ? 1.5 : 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Cart',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                AnimatedSlide(
                                  offset: _isPressed ? const Offset(0.18, 0) : Offset.zero,
                                  duration: const Duration(milliseconds: 140),
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.24),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 9.5,
                                        color: Colors.white,
                                      ),
                                    ),
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
            ),
          ),
        ),
      ),
    ),
  );
}
}
