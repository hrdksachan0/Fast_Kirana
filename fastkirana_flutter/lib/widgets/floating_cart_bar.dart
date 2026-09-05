import '../core/theme/design_system.dart';
import '../core/theme/responsive.dart';
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final barWidth = (screenWidth * 0.93).clamp(290.0, 440.0);

    final isFreeDelivery = tier.deliveryFee == 0;
    final remainingForFree = (tier.freeDeliveryThreshold - total).clamp(0.0, tier.freeDeliveryThreshold);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: widget.bottomOffset,
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
                scale: _isPressed ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppDesignSystem.primary, AppDesignSystem.red700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _isPressed
                        ? [
                            BoxShadow(
                              color: AppDesignSystem.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: AppDesignSystem.primary.withValues(alpha: 0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: const Center(
                              child: Icon(Icons.shopping_bag_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.elasticOut,
                            top: _isPressed ? -5 : -3,
                            right: _isPressed ? -5 : -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppDesignSystem.primary, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$itemCount',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} • ₹${total.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            !tier.isServiceable
                                ? '⚠️ Outside 5.0 km Hub'
                                : (isFreeDelivery
                                    ? '✨ Free Delivery Unlocked'
                                    : 'Add ₹${remainingForFree.toInt()} for FREE Delivery'),
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _isPressed ? 0.75 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VIEW CART',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.primary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _isPressed ? 0.15 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
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

