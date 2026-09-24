import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/services/location_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../widgets/unserviceable_location_banner.dart';
import '../../auth/login_screen.dart';
import '../../checkout/checkout_screen.dart';

/// Pinned Bottom Checkout Bar with Total Bill and Proceed Action
class CartBottomCheckoutBar extends ConsumerWidget {
  final double totalSavings;
  final double grandTotal;
  final double subtotal;
  final double deliveryFee;
  final DeliveryTierInfo tier;
  final double couponDiscount;
  final String? appliedCoupon;
  final String cookingInstruction;
  final VoidCallback onViewBreakdown;

  const CartBottomCheckoutBar({
    super.key,
    required this.totalSavings,
    required this.grandTotal,
    required this.subtotal,
    required this.deliveryFee,
    required this.tier,
    required this.couponDiscount,
    required this.appliedCoupon,
    required this.cookingInstruction,
    required this.onViewBreakdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingForFree = (tier.freeDeliveryThreshold - subtotal).clamp(0.0, tier.freeDeliveryThreshold);
    final isFreeUnlocked = remainingForFree <= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Savings / Free Delivery Zone Callout Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: !tier.isServiceable
                  ? const Color(0xFFFEF2F2)
                  : (isFreeUnlocked ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !tier.isServiceable
                    ? const Color(0xFFFECACA)
                    : (isFreeUnlocked ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA)),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !tier.isServiceable
                      ? '⚠️ '
                      : (isFreeUnlocked ? '🎉 ' : '🛵 '),
                  style: const TextStyle(fontSize: 12),
                ),
                Flexible(
                  child: Text(
                    !tier.isServiceable
                        ? 'Outside 5.0 km Central Hub Delivery Zone'
                        : (isFreeUnlocked
                            ? 'FREE Delivery Unlocked • You saved ₹${(totalSavings + tier.baseFee).toInt()}!'
                            : 'Add ₹${remainingForFree.toInt()} more to get FREE Delivery'),
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: !tier.isServiceable
                          ? const Color(0xFFDC2626)
                          : (isFreeUnlocked ? const Color(0xFF15803D) : const Color(0xFFC2410C)),
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Total Bill & Checkout Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onViewBreakdown,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${grandTotal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 19),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'TOTAL BILL • VIEW BREAKDOWN',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 8.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 6,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();

                    if (!tier.isServiceable) {
                      HapticFeedback.heavyImpact();
                      UnserviceableLocationBanner.showUnserviceableModal(context, ref, tier.distanceKm);
                      return;
                    }

                    final currentCart = ref.read(cartProvider).value;
                    final settings = ref.read(storeSettingsProvider).valueOrNull;
                    final isGroceryOpen = settings?.groceryMartOpen ?? true;

                    if (currentCart != null) {
                      final hasGrocery = currentCart.items.any((i) => !isRestaurantProduct(i.product));
                      final hasRestaurant = currentCart.items.any((i) => isRestaurantProduct(i.product));

                      if (hasGrocery && !isGroceryOpen) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppDesignSystem.rose500,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: const Text(
                              'FastKirana Grocery Darkstore is currently closed. Orders cannot be placed right now.',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        );
                        return;
                      }

                      final closedRestItem = currentCart.items.firstWhereOrNull(
                        (i) => isRestaurantProduct(i.product) && !RestaurantScheduleHelper.isProductRestaurantOpen(i.product, storeSettings: settings),
                      );
                      if (hasRestaurant && closedRestItem != null) {
                        final rName = closedRestItem.product.restaurant?.name ?? 'Restaurant';
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppDesignSystem.rose500,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: Text(
                              '$rName is currently closed for new orders.',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final user = ref.read(authProvider).value;
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');

                    if (!context.mounted) return;

                    if (user == null && (token == null || token.isEmpty)) {
                      await Navigator.push(
                        context,
                        FadeSlideRoute(page: const LoginScreen()),
                      );

                      final updatedUser = ref.read(authProvider).value;
                      final updatedPrefs = await SharedPreferences.getInstance();
                      final updatedToken = updatedPrefs.getString('auth_token');

                      if (!context.mounted) return;

                      if (updatedUser == null && (updatedToken == null || updatedToken.isEmpty)) {
                        return;
                      }
                    }

                    await Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: CheckoutScreen(
                          cookingInstruction: cookingInstruction.isNotEmpty ? cookingInstruction : null,
                          couponCode: appliedCoupon,
                          discountAmount: couponDiscount,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: !tier.isServiceable
                          ? const LinearGradient(colors: [AppDesignSystem.slate400, AppDesignSystem.slate500])
                          : const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (!tier.isServiceable ? AppDesignSystem.slate400 : const Color(0xFF16A34A))
                              .withValues(alpha: 0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            !tier.isServiceable ? 'Outside 5km Zone' : 'Proceed to Checkout',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            !tier.isServiceable ? Icons.block_rounded : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
