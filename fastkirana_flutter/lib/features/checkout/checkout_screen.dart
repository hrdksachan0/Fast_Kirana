import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/config/app_config.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../data/models/order.dart';
import '../../data/models/store_settings.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/network/api_client.dart';
import '../orders/orders_screen.dart';
import '../checkout/order_success_screen.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../widgets/empty_state.dart';
import '../../providers/store_hub_provider.dart';
import 'widgets/checkout_trust_badges.dart';
import 'widgets/payment_failed_cod_sheet.dart';
import 'widgets/checkout_delivery_address_card.dart';
import 'widgets/checkout_bill_breakdown.dart';
import 'widgets/checkout_packaging_selector.dart';
import 'widgets/checkout_delivery_instructions.dart';
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
  final String _deliveryMethod = 'DELIVERY'; // 'DELIVERY' | 'PICKUP'
  String _selectedPayment = 'cod'; // Default: Cash on Delivery ('cod' | 'online')
  String _selectedPackaging = 'NORMAL'; // 'NORMAL' (FREE ₹0) | 'PREMIUM' (+₹15)
  final int _selectedAddressIndex = 0;
  String _deliveryInstruction = '🔔 Ring Bell';
  final Set<String> _selectedDeliveryInstructions = {'ring_bell'};
  final TextEditingController _deliveryNotesController = TextEditingController();
  bool _isPlacingOrder = false;
  String? _customReceiverName;
  String? _customReceiverPhone;
  String? _pendingOrderId;
  String? _pendingRazorpayOrderId;
  Cart? _pendingCart;
  double? _pendingGrandTotal;
  Razorpay? _razorpay;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  String? _pendingCashfreeOrderId;

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  void initState() {
    super.initState();
    if (widget.cookingInstruction != null && widget.cookingInstruction!.trim().isNotEmpty) {
      _deliveryInstruction = '📝 Note: ${widget.cookingInstruction!.trim()} | 🔔 Ring Bell';
    }
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

      _cfService.setCallback(_handleCashfreeSuccess, _handleCashfreeError);
    }
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    if (!kIsWeb) {
      _razorpay?.clear();
    }
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();
    final cart = _pendingCart ?? ref.read(cartProvider).value;
    if (cart == null) {
      if (mounted) setState(() => _isPlacingOrder = false);
      return;
    }

    final dio = ref.read(dioProvider);

    // Cryptographic signature verification with backend
    if (response.paymentId != null) {
      try {
        final targetId = _pendingOrderId ?? _pendingRazorpayOrderId ?? response.orderId;
        if (targetId != null) {
          await dio.post('/api/payment/razorpay/verify-signature', data: {
            'orderId': targetId,
            'razorpay_order_id': response.orderId ?? _pendingRazorpayOrderId,
            'razorpay_payment_id': response.paymentId,
            'razorpay_signature': response.signature ?? '',
          });
        }
      } catch (e) {
        debugPrint('Razorpay signature verification note: $e');
      }
    }

    await _completeOrderPlacement(
      cart,
      paymentId: response.paymentId ?? 'RZP_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _isPlacingOrder = false);

    final isCancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    final errorMsg = isCancelled
        ? 'Payment cancelled. You can retry or pay with Cash on Delivery (COD).'
        : 'Payment could not be completed (${response.message ?? "Transaction declined"}). Please retry or choose COD.';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isCancelled ? AppDesignSystem.warning : primaryRed,
          content: Row(
            children: [
              Icon(
                isCancelled ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMsg,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: Responsive.scaledFontSize(context, 12)),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) setState(() => _isPlacingOrder = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.blue700,
          content: Text(
            'Redirecting to ${response.walletName ?? "external wallet"} to complete your payment...',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleCashfreeSuccess(String cfOrderId) async {
    HapticFeedback.heavyImpact();
    final cart = _pendingCart ?? ref.read(cartProvider).value;
    if (cart == null) {
      if (mounted) setState(() => _isPlacingOrder = false);
      return;
    }

    if (mounted) setState(() => _isPlacingOrder = true);
    final dio = ref.read(dioProvider);

    // Cryptographic & Server-Side Verification with Cashfree Gateway
    bool verifiedPaid = false;
    String? resolvedPaymentId;

    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      try {
        final verifyRes = await dio.post(
          '/api/payment/cashfree/verify',
          data: {'orderId': cfOrderId, 'cfOrderId': cfOrderId},
          options: Options(
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        if (verifyRes.statusCode == 200 && verifyRes.data != null) {
          final data = verifyRes.data;
          if (data['isPaid'] == true || data['paymentStatus'] == 'PAID') {
            verifiedPaid = true;
            resolvedPaymentId = data['cfPaymentId']?.toString() ?? 'CF_$cfOrderId';
            break;
          }
        }
      } catch (e) {
        debugPrint('Cashfree verification check attempt $attempt note: $e');
      }
    }

    if (!verifiedPaid || resolvedPaymentId == null) {
      debugPrint('❌ Cashfree payment verification failed or user cancelled in UPI app (cfOrderId: $cfOrderId)');
      if (mounted) setState(() => _isPlacingOrder = false);

      final total = _pendingGrandTotal ?? cart.subtotal;
      if (mounted && total > 0) {
        await PaymentFailedCodSheet.show(
          context: context,
          grandTotal: total,
          onRetryPayment: () {
            if (mounted) {
              _pendingCashfreeOrderId = null;
              _handlePlaceOrder(cart);
            }
          },
          onCancelOrder: () {
            if (mounted) {
              setState(() => _isPlacingOrder = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppDesignSystem.rose600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Text(
                    'Payment was cancelled. Order has not been placed.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              );
            }
          },
          onConfirmCod: () async {
            if (mounted) {
              setState(() {
                _selectedPayment = 'cod';
                _isPlacingOrder = true;
              });
              await _completeOrderPlacement(cart);
            }
          },
        );
      }
      return;
    }

    await _completeOrderPlacement(
      cart,
      paymentId: resolvedPaymentId,
    );
  }

  Future<void> _handleCashfreeError(CFErrorResponse errorResponse, String cfOrderId) async {
    HapticFeedback.lightImpact();

    // 1. Verify with backend first — in case user paid in UPI app (PhonePe/GPay) and WebCheckout dismissed
    try {
      final dio = ref.read(dioProvider);
      final verifyRes = await dio.post(
        '/api/payment/cashfree/verify',
        data: {'orderId': cfOrderId, 'cfOrderId': cfOrderId},
        options: Options(sendTimeout: const Duration(seconds: 4), receiveTimeout: const Duration(seconds: 4)),
      );
      if (verifyRes.data != null && (verifyRes.data['isPaid'] == true || verifyRes.data['paymentStatus'] == 'PAID')) {
        debugPrint('✅ Payment verified as PAID on server despite error callback! Routing to success...');
        await _handleCashfreeSuccess(cfOrderId);
        return;
      }
    } catch (vErr) {
      debugPrint('Cashfree error verify check note: $vErr');
    }

    if (mounted) setState(() => _isPlacingOrder = false);

    final total = _pendingGrandTotal ?? 0.0;
    final cart = _pendingCart ?? ref.read(cartProvider).value;

    // 2. Open 60-second Fallback Sheet: If customer stops -> cancel order; else convert to COD or retry
    if (mounted && total > 0 && cart != null) {
      await PaymentFailedCodSheet.show(
        context: context,
        grandTotal: total,
        onRetryPayment: () {
          if (mounted) {
            _pendingCashfreeOrderId = null;
            _handlePlaceOrder(cart);
          }
        },
        onCancelOrder: () {
          if (mounted) {
            setState(() => _isPlacingOrder = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppDesignSystem.rose600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text(
                  'Order was cancelled. No amount was debited.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            );
          }
        },
        onConfirmCod: () async {
          if (mounted) {
            setState(() {
              _selectedPayment = 'cod';
              _isPlacingOrder = true;
            });
            await _completeOrderPlacement(cart);
          }
        },
      );
      return;
    }

    final errorMsg = (errorResponse.getMessage() ?? '').toLowerCase();
    final displayMsg = errorMsg.isNotEmpty
        ? errorMsg
        : 'Payment cancelled or could not be completed. Please retry or choose Cash on Delivery (COD).';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.warning,
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayMsg,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: Responsive.scaledFontSize(context, 12),
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handlePlaceOrder(Cart cart) async {
    if (_isPlacingOrder) return;
    setState(() => _isPlacingOrder = true);
    HapticFeedback.heavyImpact();

    final settings = ref.read(storeSettingsProvider).valueOrNull ?? const StoreSettings();
    final hasGrocery = cart.items.any((i) => !isRestaurantProduct(i.product));
    final hasRestaurant = cart.items.any((i) => isRestaurantProduct(i.product));

    if (hasGrocery && !settings.groceryMartOpen) {
      setState(() => _isPlacingOrder = false);
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

    final closedRestItem = cart.items
        .where((it) => isRestaurantProduct(it.product) && !RestaurantScheduleHelper.isProductRestaurantOpen(it.product, storeSettings: settings))
        .firstOrNull;
    if (hasRestaurant && closedRestItem != null) {
      setState(() => _isPlacingOrder = false);
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

    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);
    final subtotal = cart.subtotal;
    RestaurantInfo? cartRestaurant;
    for (final item in cart.items) {
      if (item.product.restaurant != null &&
          item.product.restaurant!.lat != null &&
          item.product.restaurant!.lng != null) {
        cartRestaurant = item.product.restaurant;
        break;
      }
    }

    final storeSettings = ref.read(storeSettingsProvider).valueOrNull;
    final nearestHub = ref.read(currentStoreHubProvider);
    final tier = LocationService.getTierForAddress(
      selectedAddress,
      subtotal,
      originLat: cartRestaurant?.lat,
      originLng: cartRestaurant?.lng,
      maxRadius: cartRestaurant?.deliveryRadiusKm,
      settings: storeSettings,
      storeName: cartRestaurant?.name ?? nearestHub.name,
    );

    if (_deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final originLabel = cartRestaurant != null ? cartRestaurant.name : 'our central hub';
      final maxRad = (cartRestaurant?.deliveryRadiusKm ?? 5.0).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Delivery is currently limited to a maximum of $maxRad km from $originLabel. (Selected location is ${tier.distanceKm.toStringAsFixed(1)} km away)',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
      return;
    }

    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    // If Online Razorpay Payment is selected
    if (_selectedPayment == 'online') {
      // Edge Case 1: Free order (100% discount / promo)
      if (grandTotal <= 0.0) {
        setState(() => _isPlacingOrder = true);
        await _completeOrderPlacement(cart, paymentId: 'FREE_PROMO_${DateTime.now().millisecondsSinceEpoch}');
        return;
      }

      // Edge Case 2: Below minimum threshold for online gateway (₹1.00)
      if (grandTotal < 1.0) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            content: Text('Minimum amount for online payment is ₹1.00', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // On Mobile, open direct Cashfree PG Drop Checkout with Server Preflight (Razorpay fallback)
      if (!kIsWeb) {
        setState(() => _isPlacingOrder = true);
        _pendingCart = cart;
        _pendingGrandTotal = grandTotal;

        final user = ref.read(authProvider).value;
        final prefs = await SharedPreferences.getInstance();
        final rawPhone = user?.phone ?? prefs.getString('user_phone') ?? '';
        final digitsOnly = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
        final cleanPhone = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
        final userEmail = user?.email;
        final hasValidEmail = userEmail != null && userEmail.contains('@') && userEmail.contains('.');
        final customerName = user?.name ?? 'FastKirana Customer';

        // 1. Primary Gateway: Cashfree PG Drop Checkout
        bool cashfreeLaunched = false;
        try {
          final dio = ref.read(dioProvider);
          final cfRes = await dio.post(
            '/api/payment/cashfree/create-order',
            data: {
              'amount': grandTotal,
              if (_pendingCashfreeOrderId != null) 'orderId': _pendingCashfreeOrderId,
              'customerPhone': cleanPhone.length == 10 ? cleanPhone : '9999999999',
              if (hasValidEmail) 'customerEmail': userEmail.trim(),
              'customerName': customerName,
            },
            options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
          );

          if (cfRes.data != null && cfRes.data['paymentSessionId'] != null) {
            final paymentSessionId = cfRes.data['paymentSessionId'].toString();
            final cfOrderId = cfRes.data['orderId']?.toString() ?? 'cf_${DateTime.now().millisecondsSinceEpoch}';
            _pendingCashfreeOrderId = cfOrderId;

            const env = AppConfig.cashfreeEnv == 'SANDBOX' ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION;
            final session = CFSessionBuilder()
                .setEnvironment(env)
                .setOrderId(cfOrderId)
                .setPaymentSessionId(paymentSessionId)
                .build();

            final theme = CFThemeBuilder()
                .setNavigationBarBackgroundColorColor("#E20A22")
                .setNavigationBarTextColor("#FFFFFF")
                .setButtonBackgroundColor("#E20A22")
                .setButtonTextColor("#FFFFFF")
                .setPrimaryTextColor("#0F172A")
                .setBackgroundColor("#FFFFFF")
                .setPrimaryFont("Inter")
                .build();

            // 🚀 First attempt Direct UPI Intent (PhonePe/GPay/Paytm instant 1-tap native deep link)
            bool upiLaunched = false;
            try {
              final upi = CFUPIBuilder()
                  .setChannel(CFUPIChannel.INTENT_WITH_UI)
                  .build();

              final cfUpiPayment = CFUPIPaymentBuilder()
                  .setSession(session)
                  .setUPI(upi)
                  .build();

              _cfService.doPayment(cfUpiPayment);
              upiLaunched = true;
              cashfreeLaunched = true;
              return;
            } catch (upiErr) {
              debugPrint('Cashfree UPI Intent error, using WebCheckout fallback: $upiErr');
            }

            // 🛡️ Reliable WebCheckout Fallback
            if (!upiLaunched) {
              final cfPayment = CFWebCheckoutPaymentBuilder()
                  .setSession(session)
                  .setTheme(theme)
                  .build();

              _cfService.doPayment(cfPayment);
              cashfreeLaunched = true;
              return;
            }
          }
        } catch (cfErr) {
          debugPrint('Cashfree launch error: $cfErr');
        }

        // Exclusively Cashfree: If launch failed, trigger 60s fallback sheet for COD conversion
        if (!cashfreeLaunched) {
          if (mounted) setState(() => _isPlacingOrder = false);
          if (mounted && grandTotal > 0) {
            await PaymentFailedCodSheet.show(
              context: context,
              grandTotal: grandTotal,
              onRetryPayment: () {
                if (mounted) {
                  _pendingCashfreeOrderId = null;
                  _handlePlaceOrder(cart);
                }
              },
              onCancelOrder: () {
                if (mounted) {
                  setState(() => _isPlacingOrder = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppDesignSystem.rose600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Text(
                        'Order was cancelled. No amount was debited.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  );
                }
              },
              onConfirmCod: () async {
                if (mounted) {
                  setState(() {
                    _selectedPayment = 'cod';
                    _isPlacingOrder = true;
                  });
                  await _completeOrderPlacement(cart);
                }
              },
            );
            return;
          }
        }
      }

      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            content: Text(
              'Online payment is supported on the mobile app. Please select Cash on Delivery.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Cash on Delivery (COD) Order Placement
    setState(() => _isPlacingOrder = true);
    await _completeOrderPlacement(cart);
  }

  Future<void> _completeOrderPlacement(Cart cart, {String? paymentId}) async {
    // 🛡️ Anti-Fraud & Payment Integrity Guard:
    // If online payment is selected, strictly require a valid paymentId from payment gateway SDK (unless 100% free promo)
    if (_selectedPayment == 'online') {
      final isFreePromo = (widget.discountAmount >= cart.subtotal && cart.subtotal > 0) || (_pendingGrandTotal != null && _pendingGrandTotal! <= 0);
      if ((paymentId == null || paymentId.trim().isEmpty) && !isFreePromo) {
        if (mounted) {
          setState(() => _isPlacingOrder = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: primaryRed,
              content: Text(
                'Payment verification failed. Your order has not been placed. Please retry or choose Cash on Delivery.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final subtotal = cart.subtotal;
    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    RestaurantInfo? cartRestaurant;
    for (final item in cart.items) {
      if (item.product.restaurant != null &&
          item.product.restaurant!.lat != null &&
          item.product.restaurant!.lng != null) {
        cartRestaurant = item.product.restaurant;
        break;
      }
    }

    final storeSettings = ref.read(storeSettingsProvider).valueOrNull;
    final nearestHub = ref.read(currentStoreHubProvider);
    final tier = LocationService.getTierForAddress(
      selectedAddress,
      subtotal,
      originLat: cartRestaurant?.lat,
      originLng: cartRestaurant?.lng,
      maxRadius: cartRestaurant?.deliveryRadiusKm,
      settings: storeSettings,
      storeName: cartRestaurant?.name ?? nearestHub.name,
    );

    if (_deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final originLabel = cartRestaurant != null ? cartRestaurant.name : 'our central hub';
      final maxRad = (cartRestaurant?.deliveryRadiusKm ?? 5.0).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Delivery is currently limited to a maximum of $maxRad km from $originLabel. (Selected address is ${tier.distanceKm.toStringAsFixed(1)} km away)',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
      return;
    }

    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 0.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    final selectedAddr = _deliveryMethod == 'PICKUP'
        ? '🏬 Self Pickup: FastKirana Darkstore Counter'
        : (selectedAddress != null
            ? selectedAddress.fullAddress
            : 'Ghatampur Express Zone');

    final user = ref.read(authProvider).value;
    final prefs = await SharedPreferences.getInstance();
    final userId = user?.id ?? prefs.getString('user_id') ?? '';
    final buyerPhone = user?.phone?.isNotEmpty == true
        ? user!.phone!
        : (prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '');
    final buyerName = user?.name?.isNotEmpty == true
        ? user!.name!
        : (prefs.getString('user_name') ?? 'FastKirana Customer');

    final isOrderForSomeone = _customReceiverName?.isNotEmpty == true || _customReceiverPhone?.isNotEmpty == true;

    final receiverName = _customReceiverName?.isNotEmpty == true
        ? _customReceiverName!
        : (user?.name?.isNotEmpty == true
            ? user!.name!
            : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                ? selectedAddress.label
                : 'FastKirana Customer'));

    final receiverPhone = _customReceiverPhone?.isNotEmpty == true
        ? _customReceiverPhone!
        : (user?.phone?.isNotEmpty == true
            ? user!.phone!
            : (buyerPhone.isNotEmpty ? buyerPhone : (selectedAddress?.phone.isNotEmpty == true ? selectedAddress!.phone : '')));

    final instructionLabels = <String>[];
    for (final preset in CheckoutDeliveryInstructions.presets) {
      if (_selectedDeliveryInstructions.contains(preset.id)) {
        instructionLabels.add('${preset.icon} ${preset.title}');
      }
    }
    final customNote = _deliveryNotesController.text.trim();
    if (customNote.isNotEmpty) {
      instructionLabels.add('📍 Note: $customNote');
    }
    if (widget.cookingInstruction != null && widget.cookingInstruction!.trim().isNotEmpty) {
      instructionLabels.add('🍳 Kitchen: ${widget.cookingInstruction!.trim()}');
    }

    String orderNotes = instructionLabels.isNotEmpty
        ? instructionLabels.join(' | ')
        : (_deliveryInstruction.isNotEmpty ? _deliveryInstruction : '🔔 Ring Bell');
    if (isOrderForSomeone) {
      final forStr = '🎁 Order for: $receiverName${receiverPhone.isNotEmpty ? ' ($receiverPhone)' : ''}';
      orderNotes = '$forStr | $orderNotes';
    }

    // Extract real restaurant or store fulfillment dynamically from cart items
    final hasRestaurant = cart.items.any((i) => isRestaurantProduct(i.product));
    final hasGrocery = cart.items.any((i) => !isRestaurantProduct(i.product));
    String shopName = 'FastKirana Dark Store';
    String? restaurantId;
    for (final item in cart.items) {
      if (item.product.restaurant != null && item.product.restaurant!.name.isNotEmpty) {
        shopName = item.product.restaurant!.name;
        restaurantId = item.product.restaurantId ?? item.product.restaurant!.id;
        break;
      }
      if (item.product.restaurantId != null && item.product.restaurantId!.isNotEmpty) {
        restaurantId = item.product.restaurantId;
        break;
      }
    }

    final orderId = 'FK-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000)}';

    final newOrder = Order(
      id: orderId,
      readableId: orderId,
      userId: userId,
      addressId: selectedAddress?.id ?? 'addr_default',
      restaurantId: restaurantId,
      shopName: shopName,
      status: OrderStatus.adminPending,
      subtotal: subtotal,
      discount: widget.discountAmount,
      deliveryFee: deliveryFee,
      taxes: 0,
      miscFee: packagingFee,
      total: grandTotal,
      paymentMethod: _selectedPayment == 'online' ? PaymentMethod.upi : PaymentMethod.cod,
      paymentStatus: paymentId != null ? 'PAID' : 'PENDING',
      deliveryMethod: _deliveryMethod,
      customerName: receiverName,
      customerPhone: receiverPhone,
      customerAddress: selectedAddr,
      notes: orderNotes,
      couponCode: widget.couponCode,
      createdAt: DateTime.now(),
      items: cart.items.map<OrderItem>((i) {
        final rawId = i.product.id;
        final cleanId = rawId.startsWith('item_') ? rawId.replaceFirst('item_', '') : rawId;
        final baseProductId = cleanId.contains('_') ? cleanId.split('_')[0] : cleanId;
        return OrderItem(
          id: 'item_${i.product.id}',
          productId: baseProductId,
          name: i.product.name,
          price: i.product.price,
          quantity: i.quantity,
          imageUrl: i.product.imageUrl,
          selectedVariant: i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
        );
      }).toList(),
    );

    // 1. Post to backend Next.js API for Web App Admin & Database sync
    var placedOrder = newOrder;
    try {
      final nearestHub = ref.read(currentStoreHubProvider);
      final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;
      final apiPayload = {
        ...newOrder.toJson(),
        'userId': userId,
        'userPhone': buyerPhone,
        'userName': buyerName,
        'buyerPhone': buyerPhone,
        'buyerName': buyerName,
        'isOrderForSomeone': isOrderForSomeone,
        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
        'customerName': receiverName,
        'customerPhone': receiverPhone,
        'phone': buyerPhone.isNotEmpty ? buyerPhone : receiverPhone,
        'storeId': nearestHub.id,
        'addressId': selectedAddress?.id ?? 'addr_default',
        'paymentMethod': _selectedPayment == 'online' ? 'UPI' : 'COD',
        'paymentStatus': isOnlinePaid ? 'PAID' : 'PENDING',
        'paymentId': paymentId,
        'cfOrderId': _pendingCashfreeOrderId,
        'deliveryMethod': _deliveryMethod,
        'notes': orderNotes,
        'couponCode': widget.couponCode,
        'discount': widget.discountAmount,
        'customerAddress': selectedAddr,
        'latitude': selectedAddress?.latitude,
        'longitude': selectedAddress?.longitude,
        'lat': selectedAddress?.latitude,
        'lng': selectedAddress?.longitude,
        'shopName': (hasGrocery && hasRestaurant) ? 'FastKirana Dark Store' : shopName,
        'packagingOption': _selectedPackaging,
        'packagingFee': packagingFee,
        'items': cart.items.map((i) => {
          'productId': i.product.id,
          'quantity': i.quantity,
          'price': i.product.price,
          'name': i.product.name,
          'selectedVariant': i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
          'variant': i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
          'unit': i.product.unit,
          'restaurantId': i.product.restaurantId ?? i.product.restaurant?.id,
          'menuSection': i.product.menuSection,
          'tags': i.product.tags,
          'product': {
            'id': i.product.id,
            'name': i.product.name,
            'price': i.product.price,
            'imageUrl': i.product.imageUrl,
            'slug': i.product.slug,
            'unit': i.product.unit,
            'restaurantId': i.product.restaurantId ?? i.product.restaurant?.id,
            'menuSection': i.product.menuSection,
            'tags': i.product.tags,
          }
        }).toList(),
      };
      final res = await ref.read(dioProvider).post('/api/orders', data: apiPayload);
      if (res.data != null) {
        final data = res.data;
        String? serverReadableId = data['readableId']?.toString();
        String? serverId = data['id']?.toString();

        final created = data['order'] ?? (data['orders'] is List && (data['orders'] as List).isNotEmpty ? data['orders'][0] : null);
        if (created is Map) {
          serverReadableId = created['readableId']?.toString() ?? serverReadableId;
          serverId = created['id']?.toString() ?? serverId;
        }

        if (serverReadableId != null && serverReadableId.isNotEmpty) {
          placedOrder = placedOrder.copyWith(
            id: serverId ?? placedOrder.id,
            readableId: serverReadableId,
          );
        }

        // If multiple orders were created (e.g. 1255-G Grocery + 1255-R Restaurant)
        if (data['orders'] is List && (data['orders'] as List).isNotEmpty) {
          final repo = OrderRepository(ref.read(dioProvider));
          for (final raw in data['orders']) {
            if (raw is Map<String, dynamic>) {
              try {
                final ord = Order.fromJson(raw);
                await repo.savePlacedOrderLocally(ord);
              } catch (e, _) { LoggerService.error('CheckoutScreen: silent catch', e); }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Backend sync notice: $e');
      final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;

      // 🛡️ WORST-CASE CRASH PROTECTION:
      // If customer has ALREADY PAID via Razorpay (money deducted from bank/UPI),
      // we MUST NEVER tell them "Order Failed" or allow double deduction!
      // We save the order locally, clear the cart, and proceed to OrderSuccessScreen.
      // Server-side Razorpay webhook will automatically sync the order in the database.
      if (isOnlinePaid) {
        debugPrint('Emergency Payment Recovery: Order $orderId was paid ($paymentId) but backend sync had error $e. Recovering gracefully.');
        await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);
      } else {
        if (mounted) {
          setState(() => _isPlacingOrder = false);
          String errorMsg = 'Failed to place order. Please check your connection and try again.';
          if (e is DioException) {
            final serverErr = e.response?.data;
            if (serverErr is Map && serverErr['error'] != null) {
              errorMsg = serverErr['error'].toString();
            } else if (serverErr is String && serverErr.isNotEmpty) {
              errorMsg = serverErr;
            }
          }
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.red600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                errorMsg,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }
        return;
      }
    }

    // 2. Save the primary order locally
    await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);

    // 3. Automated KOT Remote Broadcast: DISABLED by business rule.
    // KOT is strictly controlled by Admin and is ONLY dispatched when Admin clicks "Send KOT".


    // Celebratory Haptic Feedback
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));

    // ─── CLEAR CART IMMEDIATELY AFTER ORDER IS CONFIRMED ───
    await ref.read(cartProvider.notifier).clearCart();
    ref.invalidate(ordersProvider(userId));
    ref.invalidate(ordersProvider(''));
    ref.invalidate(ordersProvider('admin'));

    if (!mounted) return;

    final successPage = OrderSuccessScreen(
      orderId: placedOrder.displayId,
      totalAmount: grandTotal,
      deliveryAddress: selectedAddr,
      paymentMethod: _selectedPayment == 'online' ? 'RAZORPAY (PAID)' : 'CASH ON DELIVERY',
      order: placedOrder,
    );

    Navigator.pushReplacement(
      context,
      FadeSlideRoute(page: successPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;

    if (!_isPlacingOrder && (cart == null || cart.items.isEmpty)) {
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
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

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
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final packagingLabel = _selectedPackaging == 'PREMIUM' ? 'Premium Thermal Packaging' : 'Standard Packaging';
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    final user = ref.watch(authProvider).value;
    final customerName = _customReceiverName?.isNotEmpty == true
        ? _customReceiverName!
        : (user?.name?.isNotEmpty == true
            ? user!.name!
            : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                ? selectedAddress.label
                : 'Customer'));
    final customerPhone = _customReceiverPhone?.isNotEmpty == true
        ? _customReceiverPhone!
        : (user?.phone ?? selectedAddress?.phone ?? '');

    // Store / Outlet name
    String outletTitle = 'FastKirana Express Store';
    for (final item in items) {
      if (item.product.restaurant != null && item.product.restaurant!.name.isNotEmpty) {
        outletTitle = item.product.restaurant!.name;
        break;
      }
    }

    // Savings Calculation
    double mrpTotal = 0;
    for (final i in items) {
      final mrp = i.product.mrp > 0 ? i.product.mrp : i.product.price;
      mrpTotal += mrp * i.quantity;
    }
    final totalSavings = (mrpTotal - subtotal + widget.discountAmount).clamp(0.0, 99999.0);

    return PopScope(
      canPop: !_isPlacingOrder,
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
            onPressed: _isPlacingOrder ? null : () => Navigator.pop(context),
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
                padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), Responsive.scale(context, 12), Responsive.horizontalPadding(context), 100),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 📍 HIGH-VISIBILITY PROMINENT DELIVERY ADDRESS CARD (Swiggy Hero Style)
                  CheckoutDeliveryAddressCard(
                    selectedAddress: selectedAddress,
                    tier: tier,
                    onAddressChanged: (addr) {
                      ref.read(selectedAddressProvider.notifier).state = addr;
                      setState(() {});
                    },
                  ),

                  // 2. ✨ TOP SAVINGS BANNER
                  if (totalSavings > 0) ...[
                    CheckoutSavingsBanner(totalSavings: totalSavings),
                    const SizedBox(height: 12),
                  ],

                  // 3. 🎁 RECEIVER INFO CARD
                  CheckoutReceiverCard(
                    customerName: customerName,
                    customerPhone: customerPhone,
                    isOrderingForSomeone: _customReceiverName != null || _customReceiverPhone != null,
                    onReceiverDetailsSaved: (name, phone) {
                      setState(() {
                        _customReceiverName = name;
                        _customReceiverPhone = phone;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. 🍱 CART ITEMS REVIEW CARD
                  CheckoutItemsReviewCard(items: items),
                  const SizedBox(height: 14),

                  // 5. ✨ COMPLETE YOUR MEAL (Cross-Sell / Frequently Bought Together)
                  CheckoutCompleteYourMeal(items: items),
                  const SizedBox(height: 14),

                  // 6. 🍱 Packaging Preference
                  CheckoutPackagingSelector(
                    selectedPackaging: _selectedPackaging,
                    onPackagingChanged: (val) => setState(() => _selectedPackaging = val),
                  ),
                  const SizedBox(height: 14),

                  // 7. 🧾 Detailed Bill Summary
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

                  // 8. 🛡️ FastKirana Buyer Protection & Trust Badges
                  const CheckoutTrustBadges(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 🌟 Smooth Full-Screen Processing Overlay on Order Placement
            if (_isPlacingOrder)
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
                isPlacingOrder: _isPlacingOrder,
                onProceedToPay: () {
                  final activeCart = cart ?? Cart(id: 'c', userId: 'u', items: items, couponDiscount: 0.0, createdAt: DateTime.now(), updatedAt: DateTime.now());
                  CheckoutPaymentSelectorSheet.show(
                    context: context,
                    selectedPayment: _selectedPayment,
                    grandTotal: grandTotal,
                    isPlacingOrder: _isPlacingOrder,
                    onPaymentChanged: (method) {
                      setState(() => _selectedPayment = method);
                    },
                    onConfirm: () => _handlePlaceOrder(activeCart),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ));
  }
}