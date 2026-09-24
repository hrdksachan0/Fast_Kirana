import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:fastkirana_flutter/data/models/coupon.dart';
import 'package:fastkirana_flutter/data/models/restaurant.dart';
import 'package:fastkirana_flutter/providers/coupon_provider.dart';

/// Horizontal scrolling deals and coupon tickets strip for Cafe Menu Screen
class CafeOffersStrip extends ConsumerWidget {
  final Restaurant? currentRestaurant;
  final String restaurantId;

  const CafeOffersStrip({
    super.key,
    required this.currentRestaurant,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(restaurantCouponsProvider(restaurantId));

    return SliverToBoxAdapter(
      child: couponsAsync.when(
        data: (coupons) {
          final activeCoupons = coupons.where((c) => c.isValid).toList();
          final hasOffer = currentRestaurant?.discountOffer != null &&
              currentRestaurant!.discountOffer!.trim().isNotEmpty;

          if (activeCoupons.isEmpty && !hasOffer) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('🎟️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        'OFFERS & DEALS FOR YOU',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (activeCoupons.isNotEmpty)
                        ...activeCoupons.map((coupon) => _buildOfferTicketCard(context, coupon))
                      else if (hasOffer && currentRestaurant!.discountOffer != null)
                        _buildFallbackOfferTicket(context, currentRestaurant!.discountOffer!),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOfferTicketCard(BuildContext context, Coupon coupon) {
    final isBogo = coupon.isBogo;
    final isFreeDelivery = coupon.discountType == DiscountType.freeDelivery;

    String title;
    if (coupon.badgeText != null && coupon.badgeText!.isNotEmpty) {
      title = coupon.badgeText!;
    } else if (isBogo) {
      if (coupon.bogoType == 'BUY_LARGE_GET_SMALL') {
        title = 'BUY ${(coupon.triggerVariant ?? 'LARGE').toUpperCase()} GET ${(coupon.rewardVariant ?? 'SMALL').toUpperCase()} FREE';
      } else if (coupon.bogoType == 'FREE_GIFT') {
        title = 'BUY ${(coupon.triggerVariant ?? '1').toUpperCase()} GET FREE GIFT';
      } else if (coupon.bogoType == 'CHEAPEST_FREE') {
        title = 'BUY 2+, CHEAPEST ITEM FREE';
      } else {
        title = 'BUY 1 GET 1 FREE';
      }
    } else if (isFreeDelivery) {
      title = '100% FREE DELIVERY';
    } else if (coupon.discountType == DiscountType.percent) {
      title = 'FLAT ${coupon.value.toInt()}% OFF';
    } else {
      title = 'FLAT ₹${coupon.value.toInt()} OFF';
    }

    String subtitle;
    if (coupon.autoApply) {
      subtitle = '⚡ Auto-applied in cart • ${coupon.code}';
    } else if (coupon.minOrder > 0) {
      subtitle = 'Min order ₹${coupon.minOrder.toInt()} • Use ${coupon.code}';
    } else {
      subtitle = 'Code: ${coupon.code} • Tap to copy';
    }

    final accentColor = isBogo
        ? const Color(0xFFEA580C)
        : isFreeDelivery
            ? AppDesignSystem.emerald600
            : AppDesignSystem.primary;

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: coupon.code));
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: accentColor,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Copied "${coupon.code}"! Apply at checkout.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBogo ? const Color(0xFFFDBA74) : AppDesignSystem.slate200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isBogo
                    ? const Color(0xFFFFF7ED)
                    : isFreeDelivery
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBogo
                      ? const Color(0xFFFDBA74)
                      : isFreeDelivery
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFBFDBFE),
                ),
              ),
              child: Center(
                child: Text(
                  isBogo ? '🔥' : isFreeDelivery ? '🚚' : '🏷️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackOfferTicket(BuildContext context, String offerText) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(const ClipboardData(text: 'BOGO'));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEA580C),
            content: Text('🔥 Offer "$offerText" available at checkout!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offerText,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEA580C),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⚡ Tap to apply BOGO offer',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
