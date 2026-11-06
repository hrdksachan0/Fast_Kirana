import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/design_system.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../core/services/location_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/zepto_connectivity_pill.dart';
import '../../providers/store_hub_provider.dart';
import '../../core/utils/app_connectivity.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'controllers/checkout_controller.dart';
import 'widgets/checkout_trust_badges.dart';
import 'widgets/checkout_delivery_address_card.dart';
import 'widgets/checkout_bill_breakdown.dart';
import 'widgets/checkout_savings_banner.dart';
import 'widgets/checkout_receiver_card.dart';
import 'widgets/checkout_placing_order_overlay.dart';
import 'widgets/checkout_items_review_card.dart';
import 'widgets/checkout_payment_selector_sheet.dart';
import 'widgets/checkout_bottom_bar.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/address_selector_sheet.dart';
import '../../data/models/address.dart';
import 'widgets/proximity_delivery_guard_sheet.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double discountAmount;
  final String? couponCode;
  final String? cookingInstruction;
  final double tipAmount;

  const CheckoutScreen({
    super.key,
    this.discountAmount = 0.0,
    this.couponCode,
    this.cookingInstruction,
    this.tipAmount = 0.0,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _deliveryNotesController = TextEditingController();
  bool _isCheckingConnection = false;
  double? _userDistanceFromAddressMeters;
  bool _hasCalculatedProximity = false;

  void _calculateProximity(Address? address) async {
    if (address == null || !mounted) return;
    if (address.latitude == null || address.longitude == null) return;
    if (LocationService.isCoordinateAnomalous(address.latitude, address.longitude, pincode: address.pincode)) {
      if (mounted) {
        setState(() {
          _userDistanceFromAddressMeters = null;
        });
      }
      return;
    }

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          address.latitude!,
          address.longitude!,
        );
        setState(() {
          _userDistanceFromAddressMeters = dist;
        });
      }
    } catch (_) {
      // Graceful fallback
    }
  }

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
        tipAmount: widget.tipAmount,
      );
    });
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    super.dispose();
  }

  void _showWalletEligibilitySheet(int neededAmount) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Referral Bonus Unlock',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Minimum order of ₹99 is required to use your wallet discount. Add ₹$neededAmount more items to save instantly!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Bounceable(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '+ Add More Items',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfflineSheet(VoidCallback onRetry) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.wifi_off_rounded, color: Color(0xFFE20A22), size: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Internet Connection',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your mobile data or Wi-Fi to proceed with your payment securely.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Bounceable(
              onTap: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Retry Connection',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    if (!_hasCalculatedProximity && selectedAddress != null) {
      _hasCalculatedProximity = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateProximity(selectedAddress);
      });
    }

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
    final hasGrocery = items.any((i) => i.product.restaurant == null && i.product.restaurantId == null);
    final hasRestaurant = items.any((i) => i.product.restaurant != null || i.product.restaurantId != null);
    final isCombined = hasGrocery && hasRestaurant;

    final deliveryFee = checkoutState.deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final handlingFee = checkoutState.deliveryMethod == 'PICKUP'
        ? 0.0
        : (isCombined ? (storeSettings?.combinedMiscFee ?? 5.0) : (storeSettings?.miscFee ?? 5.0));
    final handlingLabel = isCombined
        ? (storeSettings?.combinedMiscFeeLabel ?? 'Combined Handling Fee')
        : (storeSettings?.miscFeeLabel ?? 'Handling Fee');
    final grandTotalBeforeWallet = (subtotal + deliveryFee + handlingFee + widget.tipAmount - widget.discountAmount).clamp(0.0, 999999.0);
    final wallet = ref.watch(walletNotifierProvider);
    final double realCash = wallet.balance;
    final double promoCash = wallet.promoBalance;
    const double minPromoOrderValue = 99.0;
    final bool canUsePromo = subtotal >= minPromoOrderValue;
    // Deposited real cash (Cashfree/refunds) has ZERO minimum order value!
    // Referral / promo cash unlocks when subtotal >= ₹99.
    final double walletUsable = realCash + (canUsePromo ? promoCash : 0.0);
    final bool isEligibleForWallet = walletUsable > 0;
    final double walletDeduction = (checkoutState.useWalletBalance && isEligibleForWallet)
        ? (walletUsable >= grandTotalBeforeWallet ? grandTotalBeforeWallet : walletUsable)
        : 0.0;
    final grandTotal = (grandTotalBeforeWallet - walletDeduction).clamp(0.0, 999999.0);

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

    String outletTitle = 'FastMinute Express Store';
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
      child: Stack(
        children: [
          Scaffold(
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
                      // 0. Pending Payment Recovery Banner
                      if (checkoutState.pendingCashfreeOrderId != null &&
                          checkoutState.pendingCashfreeOrderId!.isNotEmpty &&
                          (checkoutState.pendingGrandTotal == null ||
                              (checkoutState.pendingGrandTotal! - grandTotal).abs() < 1.0)) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.amber50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.amber300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: AppDesignSystem.amber800, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Previous payment attempt of ₹${(checkoutState.pendingGrandTotal ?? grandTotal).toStringAsFixed(2)} was not completed.',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppDesignSystem.amber900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: checkoutState.isPlacingOrder
                                        ? null
                                        : () => controller.cancelPendingPaymentSession(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppDesignSystem.slate700,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      'Dismiss & Pay Now',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: checkoutState.isPlacingOrder
                                        ? null
                                        : () => controller.checkPendingPaymentStatus(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppDesignSystem.amber800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      elevation: 0,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      checkoutState.isPlacingOrder ? 'Checking...' : 'Check Status',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. Delivery Address Card
                      CheckoutDeliveryAddressCard(
                        selectedAddress: selectedAddress,
                        tier: tier,
                        userDistanceMeters: _userDistanceFromAddressMeters,
                        onAddressChanged: (addr) {
                          ref.read(selectedAddressProvider.notifier).state = addr;
                          _calculateProximity(addr);
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
                        distanceMeters: _userDistanceFromAddressMeters,
                        onProximitySheetRequested: () async {
                          if (selectedAddress == null || _userDistanceFromAddressMeters == null) return;
                          final action = await ProximityDeliveryGuardSheet.show(
                            context: context,
                            address: selectedAddress,
                            distanceMeters: _userDistanceFromAddressMeters!,
                          );
                          if (!context.mounted) return;
                          if (action == ProximityGuardAction.continueWithAddress) {
                          } else if (action == ProximityGuardAction.switchToCurrentLocation) {
                            await AddressSelectorSheet.show(
                              context,
                              activeAddress: selectedAddress,
                              onAddressSelected: (addr) {
                                ref.read(selectedAddressProvider.notifier).state = addr;
                                _calculateProximity(addr);
                              },
                            );
                          } else if (action == ProximityGuardAction.orderForSomeoneElse) {
                            CheckoutReceiverCard.showEditReceiverModal(
                              context: context,
                              isOrderingForSomeone: checkoutState.customReceiverName != null || checkoutState.customReceiverPhone != null,
                              customerName: customerName,
                              customerPhone: customerPhone,
                              onReceiverDetailsSaved: (name, phone) {
                                controller.setReceiverDetails(name, phone);
                              },
                            );
                          }
                        },
                        onAddressChangeRequested: () async {
                          HapticFeedback.selectionClick();
                          await AddressSelectorSheet.show(
                            context,
                            activeAddress: selectedAddress,
                            onAddressSelected: (addr) {
                              ref.read(selectedAddressProvider.notifier).state = addr;
                              _calculateProximity(addr);
                            },
                          );
                        },
                        onReceiverDetailsSaved: (name, phone) {
                          controller.setReceiverDetails(name, phone);
                        },
                      ),
                      const SizedBox(height: 14),

                      // 4. Cart Items Review Card
                      CheckoutItemsReviewCard(items: items),
                      const SizedBox(height: 14),


                      // 6. FastMinute Wallet Split-Payment Toggle Card
                      if (wallet.totalUsable > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: !isEligibleForWallet
                                ? const Color(0xFFF8FAFC)
                                : (checkoutState.useWalletBalance ? const Color(0xFFF0FDF4) : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: !isEligibleForWallet
                                  ? AppDesignSystem.slate200
                                  : (checkoutState.useWalletBalance ? AppDesignSystem.emerald600 : AppDesignSystem.slate200),
                              width: (isEligibleForWallet && checkoutState.useWalletBalance) ? 1.5 : 1.1,
                            ),
                            boxShadow: AppDesignSystem.shadowSm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: !isEligibleForWallet
                                      ? const Color(0xFFF1F5F9)
                                      : (checkoutState.useWalletBalance ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('👛', style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'FastMinute Wallet',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13.5),
                                            fontWeight: FontWeight.w800,
                                            color: isEligibleForWallet ? slateDark : AppDesignSystem.slate500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isEligibleForWallet ? const Color(0xFFDCFCE7) : AppDesignSystem.slate200,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '₹${walletUsable.toStringAsFixed(0)}',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9.5),
                                              fontWeight: FontWeight.w800,
                                              color: isEligibleForWallet ? const Color(0xFF15803D) : AppDesignSystem.slate600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      !isEligibleForWallet
                                          ? 'Min. order ₹99 required to use referral bonus (Add ₹${(minPromoOrderValue - subtotal).toInt()} more)'
                                          : (checkoutState.useWalletBalance
                                              ? (walletUsable >= grandTotalBeforeWallet
                                                  ? '₹${grandTotalBeforeWallet.toStringAsFixed(0)} deducted • 100% covered!'
                                                  : '-₹${walletUsable.toStringAsFixed(0)} deducted • Pay ₹${grandTotal.toStringAsFixed(0)} left')
                                              : (realCash > 0 && promoCash > 0 && !canUsePromo
                                                  ? '₹${realCash.toStringAsFixed(0)} Real Cash ready • Add ₹${(minPromoOrderValue - subtotal).toInt()} more for ₹${promoCash.toStringAsFixed(0)} bonus'
                                                  : 'Tap switch to apply wallet balance')),
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        color: !isEligibleForWallet
                                            ? const Color(0xFFB45309)
                                            : (checkoutState.useWalletBalance ? const Color(0xFF047857) : slateMuted),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isEligibleForWallet && checkoutState.useWalletBalance,
                                activeThumbColor: const Color(0xFF059669),
                                onChanged: isEligibleForWallet
                                    ? (val) {
                                        HapticFeedback.lightImpact();
                                        controller.setUseWalletBalance(val);
                                      }
                                    : (val) {
                                        HapticFeedback.heavyImpact();
                                          _showWalletEligibilitySheet((minPromoOrderValue - subtotal).toInt());
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 7. Detailed Bill Summary
                      CheckoutBillBreakdown(
                        subtotal: subtotal,
                        deliveryFee: deliveryFee,
                        handlingFee: handlingFee,
                        handlingLabel: handlingLabel,
                        packagingFee: handlingFee,
                        packagingLabel: handlingLabel,
                        discountAmount: widget.discountAmount,
                        walletAmountUsed: walletDeduction,
                        grandTotal: grandTotal,
                        tipAmount: widget.tipAmount,
                        tier: tier,
                      ),
                      const SizedBox(height: 14),

                      // 8. Trust Badges
                      const CheckoutTrustBadges(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Floating Dynamic Island connectivity pill
                const ZeptoConnectivityPill(),
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
                child: Builder(
                  builder: (context) {
                    final activeCart = cart ?? Cart(
                      id: 'c',
                      userId: 'u',
                      items: items,
                      couponDiscount: 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    void openPaymentSheet() {
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
                    }

                    Future<void> handleProceedToPay() async {
                      // 1. Serviceability Check against store delivery radius limit
                      if (selectedAddress != null && !tier.isServiceable) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tier.distanceKm > 0.0
                                  ? 'âš ï¸ Selected address is outside our 5.0 km delivery zone ( km). Delivery unavailable.'
                                  : 'âš ï¸ Selected address is not serviceable. Please change delivery address.',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppDesignSystem.red600,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // Proximity reminder is permanently highlighted at the top via Zepto Speech Bubble.
                      // Proceed to Pay proceeds directly to payment without any blocking popup sheets!
                      openPaymentSheet();
                    }

                    Future<void> retryConnectionAndProceed() async {
                      if (_isCheckingConnection) return;
                      setState(() => _isCheckingConnection = true);
                      try {
                        final isOnline = await ref.read(connectivityProvider).checkConnection();
                        if (!context.mounted) return;
                        final transports = ref.read(connectivityProvider).results;
                        final hasActiveTransport = transports.any((r) => r != ConnectivityResult.none);
                        if (isOnline || hasActiveTransport) {
                          handleProceedToPay();
                        } else {
                          _showOfflineSheet(handleProceedToPay);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          final transports = ref.read(connectivityProvider).results;
                          if (transports.any((r) => r != ConnectivityResult.none)) {
                            handleProceedToPay();
                          }
                        }
                      } finally {
                        if (mounted) setState(() => _isCheckingConnection = false);
                      }
                    }

                    return CheckoutBottomBar(
                      grandTotal: grandTotal,
                      isPlacingOrder: checkoutState.isPlacingOrder,
                      isOffline: !ref.watch(connectivityProvider).isOnline,
                      isCheckingConnection: _isCheckingConnection,
                      onRetryConnection: retryConnectionAndProceed,
                      onProceedToPay: handleProceedToPay,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      // FULL-SCREEN IMMERSIVE OVERLAY (Zepto / Swiggy style: covers AppBar + Body + BottomBar!)
      if (checkoutState.isPlacingOrder)
        Positioned.fill(
          child: CheckoutPlacingOrderOverlay(
            key: const ValueKey('full_screen_placing_overlay'),
            totalAmount: grandTotal,
            isCod: checkoutState.selectedPayment == 'cod',
            onCancel: () => controller.cancelPlacingOrder(context),
          ),
        ),
    ],
  ),
);
  }
}
