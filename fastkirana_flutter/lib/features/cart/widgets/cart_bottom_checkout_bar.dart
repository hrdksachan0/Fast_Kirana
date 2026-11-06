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
import '../../../core/services/secure_storage_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../widgets/unserviceable_location_banner.dart';
import '../../auth/login_screen.dart';
import '../../checkout/checkout_screen.dart';

/// Pinned Bottom Checkout Bar with Total Bill and Swiggy-Style Store Status
class CartBottomCheckoutBar extends ConsumerWidget {
  final double totalSavings;
  final double grandTotal;
  final double subtotal;
  final double deliveryFee;
  final DeliveryTierInfo tier;
  final double couponDiscount;
  final String? appliedCoupon;
  final String cookingInstruction;
  final double selectedTip;
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
    this.selectedTip = 0.0,
    required this.onViewBreakdown,
  });

  void _showStoreClosedSheet(
    BuildContext context, {
    required bool isGroceryClosed,
    required String storeName,
    required String openTime,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.nightlight_round, color: Color(0xFFE11D48), size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isGroceryClosed ? 'FastMinute Darkstore is Resting 💤' : '$storeName is Closed',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isGroceryClosed
                  ? 'Delivery will resume at $openTime. Aapke cart items safe hain, store open hote hi 1-tap me order place kar sakte hain.'
                  : 'This store is currently not taking orders. Cart items will remain saved.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Got it, Keep Cart',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCart = ref.watch(cartProvider).value;
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final groceryOpenTime = settings?.raw['grocery_open_time']?.toString() ?? '6:00 AM';

    final hasGrocery = currentCart?.items.any((i) => !isRestaurantProduct(i.product)) ?? false;
    final hasRestaurant = currentCart?.items.any((i) => isRestaurantProduct(i.product)) ?? false;

    final closedRestItem = currentCart?.items.firstWhereOrNull(
      (i) => isRestaurantProduct(i.product) && !RestaurantScheduleHelper.isProductRestaurantOpen(i.product, storeSettings: settings),
    );

    final isGroceryClosed = hasGrocery && !isGroceryOpen;
    final isRestaurantClosed = hasRestaurant && closedRestItem != null;
    final isStoreClosed = isGroceryClosed || isRestaurantClosed;
    final closedStoreName = closedRestItem?.product.restaurant?.name ?? 'Restaurant';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Swiggy Style Seamless Integrated Store Closed Strip ───
          if (isStoreClosed) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2), // Soft Rose 50
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.nightlight_round, size: 14, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isGroceryClosed
                          ? 'Darkstore is resting · Orders open at $groceryOpenTime'
                          : '$closedStoreName is closed for new orders',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFBE123C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Total Bill & Checkout Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
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
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();

                    if (!tier.isServiceable) {
                      HapticFeedback.heavyImpact();
                      UnserviceableLocationBanner.showUnserviceableModal(context, ref, tier.distanceKm);
                      return;
                    }

                    if (isStoreClosed) {
                      _showStoreClosedSheet(
                        context,
                        isGroceryClosed: isGroceryClosed,
                        storeName: closedStoreName,
                        openTime: groceryOpenTime,
                      );
                      return;
                    }

                    final user = ref.read(authProvider).value;
                    final prefs = await SharedPreferences.getInstance();
                    final secureToken = await SecureStorageService.instance.getAuthToken();
                    final token = (secureToken != null && secureToken.isNotEmpty)
                        ? secureToken
                        : prefs.getString('auth_token');

                    if (!context.mounted) return;

                    if (user == null && (token == null || token.isEmpty)) {
                      await Navigator.push(
                        context,
                        FadeSlideRoute(page: const LoginScreen()),
                      );

                      final updatedUser = ref.read(authProvider).value;
                      final updatedPrefs = await SharedPreferences.getInstance();
                      final updatedSecureToken = await SecureStorageService.instance.getAuthToken();
                      final updatedToken = (updatedSecureToken != null && updatedSecureToken.isNotEmpty)
                          ? updatedSecureToken
                          : updatedPrefs.getString('auth_token');

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
                          tipAmount: selectedTip,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: !tier.isServiceable
                          ? const LinearGradient(colors: [AppDesignSystem.slate400, AppDesignSystem.slate500])
                          : isStoreClosed
                              ? const LinearGradient(
                                  colors: [Color(0xFF475569), Color(0xFF334155)], // Sleek Slate Charcoal
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (!tier.isServiceable
                                  ? AppDesignSystem.slate400
                                  : isStoreClosed
                                      ? const Color(0xFF475569)
                                      : const Color(0xFF16A34A))
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
                            !tier.isServiceable
                                ? 'Outside 5km Zone'
                                : isStoreClosed
                                    ? (isGroceryClosed ? 'Store Closed' : 'Restaurant Closed')
                                    : 'Proceed to Checkout',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            !tier.isServiceable
                                ? Icons.block_rounded
                                : isStoreClosed
                                    ? Icons.access_time_rounded
                                    : Icons.arrow_forward_rounded,
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
