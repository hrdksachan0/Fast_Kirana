import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/design_system.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/services/location_service.dart';
import '../../widgets/empty_state.dart';
import '../../providers/store_hub_provider.dart';
import 'controllers/checkout_controller.dart';
import 'widgets/checkout_trust_badges.dart';
import 'widgets/checkout_delivery_address_card.dart';
import 'widgets/checkout_bill_breakdown.dart';
import 'widgets/checkout_packaging_selector.dart';
import 'widgets/checkout_savings_banner.dart';
import 'widgets/checkout_receiver_card.dart';
import 'widgets/checkout_complete_your_meal.dart';
import 'widgets/checkout_placing_order_overlay.dart';
import 'widgets/checkout_items_review_card.dart';
import 'widgets/checkout_payment_selector_sheet.dart';
import 'widgets/checkout_bottom_bar.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double discountAmount;
  final String? couponCode;
  final String? cookingInstruction;

  const CheckoutScreen({
    super.key,
    this.discountAmount = 0.0,
    this.couponCode,
    this.cookingInstruction,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _deliveryNotesController = TextEditingController();

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutControllerProvider.notifier).init(
        context: context,
        discountAmount: widget.discountAmount,
        couponCode: widget.couponCode,
        cookingInstruction: widget.cookingInstruction,
      );
    });
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);
    controller.updateContext(context);

    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;

    if (!checkoutState.isPlacingOrder && (cart == null || cart.items.isEmpty)) {
      return Scaffold(
        backgroundColor: AppDesignSystem.background,
        appBar: AppBar(backgroundColor: AppDesignSystem.background, elevation: 0),
        body: const EmptyState(
          emoji: '🛒',
          title: 'Your cart is empty',
          subtitle: 'Add some items to your cart\nbefore proceeding to checkout.',
          bgTint: AppDesignSystem.primaryBg,
          ctaLabel: 'Start Shopping',
        ),
      );
    }

    final items = cart?.items ?? [];
    final subtotal = cart?.subtotal ?? 0.0;
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.watch(selectedAddressProvider) ??
        (checkoutState.selectedAddressIndex < addresses.length ? addresses[checkoutState.selectedAddressIndex] : null);

    RestaurantInfo? cartRestaurant;
    for (final item in items) {
      if (item.product.restaurant != null &&
          item.product.restaurant!.lat != null &&
          item.product.restaurant!.lng != null) {
        cartRestaurant = item.product.restaurant;
        break;
      }
    }

    final storeSettings = ref.watch(storeSettingsProvider).valueOrNull;
    final nearestHub = ref.watch(currentStoreHubProvider);
    final tier = LocationService.getTierForAddress(
      selectedAddress,
      subtotal,
      originLat: cartRestaurant?.lat,
      originLng: cartRestaurant?.lng,
      maxRadius: cartRestaurant?.deliveryRadiusKm,
      settings: storeSettings,
      storeName: cartRestaurant?.name ?? nearestHub.name,
    );
    final deliveryFee = checkoutState.deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = checkoutState.selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final packagingLabel = checkoutState.selectedPackaging == 'PREMIUM' ? 'Premium Thermal Packaging' : 'Standard Packaging';
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    final user = ref.watch(authProvider).value;
    final customerName = checkoutState.customReceiverName?.isNotEmpty == true
        ? checkoutState.customReceiverName!
        : (user?.name?.isNotEmpty == true
            ? user!.name!
            : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                ? selectedAddress.label
                : 'Customer'));
    final customerPhone = checkoutState.customReceiverPhone?.isNotEmpty == true
        ? checkoutState.customReceiverPhone!
        : (user?.phone ?? selectedAddress?.phone ?? '');

    String outletTitle = 'FastKirana Express Store';
    for (final item in items) {
      if (item.product.restaurant != null && item.product.restaurant!.name.isNotEmpty) {
        outletTitle = item.product.restaurant!.name;
        break;
      }
    }

    double mrpTotal = 0;
    for (final i in items) {
      final mrp = i.product.mrp > 0 ? i.product.mrp : i.product.price;
      mrpTotal += mrp * i.quantity;
    }
    final totalSavings = (mrpTotal - subtotal + widget.discountAmount).clamp(0.0, 99999.0);

    return PopScope(
      canPop: !checkoutState.isPlacingOrder,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppDesignSystem.slate50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppDesignSystem.slate200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
            ),
            onPressed: checkoutState.isPlacingOrder ? null : () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 15.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                outletTitle,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: slateMuted,
                ),
              ),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppDesignSystem.slate200),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ResponsiveContainer(
            maxWidth: Responsive.wideMaxContentWidth,
            fillHeight: true,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    Responsive.horizontalPadding(context),
                    Responsive.scale(context, 12),
                    Responsive.horizontalPadding(context),
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Delivery Address Card
                      CheckoutDeliveryAddressCard(
                        selectedAddress: selectedAddress,
                        tier: tier,
                        onAddressChanged: (addr) {
                          ref.read(selectedAddressProvider.notifier).state = addr;
                        },
                      ),

                      // 2. Top Savings Banner
                      if (totalSavings > 0) ...[
                        CheckoutSavingsBanner(totalSavings: totalSavings),
                        const SizedBox(height: 12),
                      ],

                      // 3. Receiver Info Card
                      CheckoutReceiverCard(
                        customerName: customerName,
                        customerPhone: customerPhone,
                        isOrderingForSomeone: checkoutState.customReceiverName != null || checkoutState.customReceiverPhone != null,
                        onReceiverDetailsSaved: (name, phone) {
                          controller.setReceiverDetails(name, phone);
                        },
                      ),
                      const SizedBox(height: 14),

                      // 4. Cart Items Review Card
                      CheckoutItemsReviewCard(items: items),
                      const SizedBox(height: 14),

                      // 5. Complete Your Meal Cross-sell
                      CheckoutCompleteYourMeal(items: items),
                      const SizedBox(height: 14),

                      // 6. Packaging Preference
                      CheckoutPackagingSelector(
                        selectedPackaging: checkoutState.selectedPackaging,
                        onPackagingChanged: (val) => controller.setPackaging(val),
                      ),
                      const SizedBox(height: 14),

                      // 7. Detailed Bill Summary
                      CheckoutBillBreakdown(
                        subtotal: subtotal,
                        deliveryFee: deliveryFee,
                        packagingFee: packagingFee,
                        packagingLabel: packagingLabel,
                        discountAmount: widget.discountAmount,
                        grandTotal: grandTotal,
                        tier: tier,
                      ),
                      const SizedBox(height: 14),

                      // 8. Trust Badges
                      const CheckoutTrustBadges(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Processing Overlay
                if (checkoutState.isPlacingOrder)
                  const Positioned.fill(child: CheckoutPlacingOrderOverlay()),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppDesignSystem.slate200, width: 1.2)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Responsive.defaultMaxContentWidth),
                child: CheckoutBottomBar(
                  grandTotal: grandTotal,
                  isPlacingOrder: checkoutState.isPlacingOrder,
                  onProceedToPay: () {
                    final activeCart = cart ?? Cart(
                      id: 'c',
                      userId: 'u',
                      items: items,
                      couponDiscount: 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    CheckoutPaymentSelectorSheet.show(
                      context: context,
                      selectedPayment: checkoutState.selectedPayment,
                      grandTotal: grandTotal,
                      isPlacingOrder: checkoutState.isPlacingOrder,
                      onPaymentChanged: (method) {
                        controller.setPaymentMethod(method);
                      },
                      onConfirm: () {
                        controller.updateNotes(_deliveryNotesController.text);
                        controller.handlePlaceOrder(context, cart: activeCart);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}