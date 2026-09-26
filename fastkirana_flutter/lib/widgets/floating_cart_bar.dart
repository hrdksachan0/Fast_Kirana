import '../core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/routes/page_transitions.dart';
import '../core/services/location_service.dart';
import '../providers/cart_provider.dart';
import '../features/cart/cart_screen.dart';

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
    final barWidth = (screenWidth * 0.93).clamp(290.0, 440.0);

    final isFreeDelivery = tier.deliveryFee == 0;
    final remainingForFree = (tier.freeDeliveryThreshold - total).clamp(0.0, tier.freeDeliveryThreshold);

    final effectiveBottomOffset = widget.bottomOffset;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: effectiveBottomOffset,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: barWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 16),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
              },
              child: AnimatedScale(
                scale: _isPressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE20A22), Color(0xFFBA0517)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                    boxShadow: _isPressed
                        ? [
                            BoxShadow(
                              color: AppDesignSystem.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: AppDesignSystem.primary.withValues(alpha: 0.42),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // 1. Shopping Bag Icon Container + Floating Item Count Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.shopping_bag_rounded, size: 19, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$itemCount',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 11),

                      // 2. Middle Info: Items • Price + Free Delivery Tracker
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 13.5),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    '  •  ',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹${total.toInt()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 14.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !tier.isServiceable
                                  ? '⚠️ Outside 5.0 km Hub'
                                  : (isFreeDelivery
                                      ? '✨ Free Delivery Unlocked'
                                      : 'Add ₹${remainingForFree.toInt()} for FREE Delivery'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                fontWeight: FontWeight.w600,
                                color: isFreeDelivery
                                    ? const Color(0xFFFFEB3B)
                                    : Colors.white.withValues(alpha: 0.92),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tier.isServiceable && !isFreeDelivery && tier.freeDeliveryThreshold > 0) ...[
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (total / tier.freeDeliveryThreshold).clamp(0.0, 1.0),
                                  minHeight: 2.5,
                                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. Right Pill Action Button ("View Cart ➔")
                      AnimatedOpacity(
                        opacity: _isPressed ? 0.85 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Cart',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.primary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _isPressed ? 0.08 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: AppDesignSystem.primary,
                                ),
                              ),
                            ],
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
    );
  }
}

