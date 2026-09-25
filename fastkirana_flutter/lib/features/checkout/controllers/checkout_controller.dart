import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/customer_sound_service.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/cart.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/store_settings.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/store_hub_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../orders/orders_screen.dart';
import '../order_success_screen.dart';
import '../widgets/payment_failed_cod_sheet.dart';
import '../widgets/checkout_delivery_instructions.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class CheckoutState {
  final bool isPlacingOrder;
  final String selectedPayment; // 'cod' | 'online'
  final String selectedPackaging; // 'NORMAL' | 'PREMIUM'
  final String deliveryMethod; // 'DELIVERY' | 'PICKUP'
  final int selectedAddressIndex;
  final String deliveryInstruction;
  final Set<String> selectedDeliveryInstructions;
  final String? customReceiverName;
  final String? customReceiverPhone;
  final String? pendingOrderId;
  final String? pendingCashfreeOrderId;
  final Cart? pendingCart;
  final double? pendingGrandTotal;

  const CheckoutState({
    this.isPlacingOrder = false,
    this.selectedPayment = 'cod',
    this.selectedPackaging = 'NORMAL',
    this.deliveryMethod = 'DELIVERY',
    this.selectedAddressIndex = 0,
    this.deliveryInstruction = '🔔 Ring Bell',
    this.selectedDeliveryInstructions = const {'ring_bell'},
    this.customReceiverName,
    this.customReceiverPhone,
    this.pendingOrderId,
    this.pendingCashfreeOrderId,
    this.pendingCart,
    this.pendingGrandTotal,
  });

  CheckoutState copyWith({
    bool? isPlacingOrder,
    String? selectedPayment,
    String? selectedPackaging,
    String? deliveryMethod,
    int? selectedAddressIndex,
    String? deliveryInstruction,
    Set<String>? selectedDeliveryInstructions,
    String? customReceiverName,
    String? customReceiverPhone,
    String? pendingOrderId,
    String? pendingCashfreeOrderId,
    Cart? pendingCart,
    double? pendingGrandTotal,
    bool clearReceiverDetails = false,
  }) {
    return CheckoutState(
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      selectedPayment: selectedPayment ?? this.selectedPayment,
      selectedPackaging: selectedPackaging ?? this.selectedPackaging,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      selectedAddressIndex: selectedAddressIndex ?? this.selectedAddressIndex,
      deliveryInstruction: deliveryInstruction ?? this.deliveryInstruction,
      selectedDeliveryInstructions: selectedDeliveryInstructions ?? this.selectedDeliveryInstructions,
      customReceiverName: clearReceiverDetails ? null : (customReceiverName ?? this.customReceiverName),
      customReceiverPhone: clearReceiverDetails ? null : (customReceiverPhone ?? this.customReceiverPhone),
      pendingOrderId: pendingOrderId ?? this.pendingOrderId,
      pendingCashfreeOrderId: pendingCashfreeOrderId ?? this.pendingCashfreeOrderId,
      pendingCart: pendingCart ?? this.pendingCart,
      pendingGrandTotal: pendingGrandTotal ?? this.pendingGrandTotal,
    );
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutState>((ref) {
  return CheckoutController(ref);
});

// ─── Controller ────────────────────────────────────────────────────────────

class CheckoutController extends StateNotifier<CheckoutState> {
  final Ref ref;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  BuildContext? _currentContext;

  // Parameters cached for payment callbacks
  double _discountAmount = 0.0;
  String? _couponCode;
  String? _cookingInstruction;
  String _customDeliveryNotes = '';

  CheckoutController(this.ref) : super(const CheckoutState());

  void init({
    required BuildContext context,
    double discountAmount = 0.0,
    String? couponCode,
    String? cookingInstruction,
  }) {
    _currentContext = context;
    _discountAmount = discountAmount;
    _couponCode = couponCode;
    _cookingInstruction = cookingInstruction;

    if (cookingInstruction != null && cookingInstruction.trim().isNotEmpty) {
      state = state.copyWith(
        deliveryInstruction: '📝 Note: ${cookingInstruction.trim()} | 🔔 Ring Bell',
      );
    }

    if (!kIsWeb) {
      _cfService.setCallback(_onCashfreeSuccess, _onCashfreeError);
    }
  }

  // ─── State Modifiers ───────────────────────────────────────────────────────

  void setPaymentMethod(String method) {
    state = state.copyWith(selectedPayment: method);
  }

  void setPackaging(String packaging) {
    state = state.copyWith(selectedPackaging: packaging);
  }

  void setDeliveryMethod(String method) {
    state = state.copyWith(deliveryMethod: method);
  }

  void setAddressIndex(int index) {
    state = state.copyWith(selectedAddressIndex: index);
  }

  void setDeliveryInstruction(String instruction) {
    state = state.copyWith(deliveryInstruction: instruction);
  }

  void toggleDeliveryInstruction(String id) {
    final updated = Set<String>.from(state.selectedDeliveryInstructions);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedDeliveryInstructions: updated);
  }

  void setReceiverDetails(String? name, String? phone) {
    state = state.copyWith(
      customReceiverName: name,
      customReceiverPhone: phone,
    );
  }

  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  void updateNotes(String notes) {
    _customDeliveryNotes = notes;
  }

  // ─── Cashfree Payment Handlers ─────────────────────────────────────────────

  Future<void> _onCashfreeSuccess(String cfOrderId) async {
    HapticFeedback.heavyImpact();
    final cart = state.pendingCart ?? ref.read(cartProvider).value;
    if (cart == null) {
      state = state.copyWith(isPlacingOrder: false);
      return;
    }

    state = state.copyWith(isPlacingOrder: true);
    final dio = ref.read(dioProvider);

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

    final context = _currentContext;
    if (!verifiedPaid || resolvedPaymentId == null) {
      debugPrint('❌ Cashfree payment verification failed or user cancelled in UPI app (cfOrderId: $cfOrderId)');
      state = state.copyWith(isPlacingOrder: false);

      final total = state.pendingGrandTotal ?? cart.subtotal;
      if (context != null && context.mounted && total > 0) {
        await PaymentFailedCodSheet.show(
          context: context,
          grandTotal: total,
          onRetryPayment: () {
            state = state.copyWith(pendingCashfreeOrderId: null);
            handlePlaceOrder(context, cart: cart);
          },
          onCancelOrder: () {
            state = state.copyWith(isPlacingOrder: false);
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
          },
          onConfirmCod: () async {
            state = state.copyWith(selectedPayment: 'cod', isPlacingOrder: true);
            await completeOrderPlacement(context, cart: cart);
          },
        );
      }
      return;
    }

    if (context != null && context.mounted) {
      await completeOrderPlacement(
        context,
        cart: cart,
        paymentId: resolvedPaymentId,
      );
    }
  }

  Future<void> _onCashfreeError(CFErrorResponse errorResponse, String cfOrderId) async {
    HapticFeedback.lightImpact();

    try {
      final dio = ref.read(dioProvider);
      final verifyRes = await dio.post(
        '/api/payment/cashfree/verify',
        data: {'orderId': cfOrderId, 'cfOrderId': cfOrderId},
        options: Options(sendTimeout: const Duration(seconds: 4), receiveTimeout: const Duration(seconds: 4)),
      );
      if (verifyRes.data != null && (verifyRes.data['isPaid'] == true || verifyRes.data['paymentStatus'] == 'PAID')) {
        debugPrint('✅ Payment verified as PAID on server despite error callback! Routing to success...');
        await _onCashfreeSuccess(cfOrderId);
        return;
      }
    } catch (vErr) {
      debugPrint('Cashfree error verify check note: $vErr');
    }

    state = state.copyWith(isPlacingOrder: false);

    final total = state.pendingGrandTotal ?? 0.0;
    final cart = state.pendingCart ?? ref.read(cartProvider).value;
    final context = _currentContext;

    if (context != null && context.mounted && total > 0 && cart != null) {
      await PaymentFailedCodSheet.show(
        context: context,
        grandTotal: total,
        onRetryPayment: () {
          state = state.copyWith(pendingCashfreeOrderId: null);
          handlePlaceOrder(context, cart: cart);
        },
        onCancelOrder: () {
          state = state.copyWith(isPlacingOrder: false);
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
        },
        onConfirmCod: () async {
          state = state.copyWith(selectedPayment: 'cod', isPlacingOrder: true);
          await completeOrderPlacement(context, cart: cart);
        },
      );
      return;
    }

    if (context != null && context.mounted) {
      final errorMsg = (errorResponse.getMessage() ?? '').toLowerCase();
      final displayMsg = errorMsg.isNotEmpty
          ? errorMsg
          : 'Payment cancelled or could not be completed. Please retry or choose Cash on Delivery (COD).';

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

  // ─── Order Placement Flow ──────────────────────────────────────────────────

  Future<void> handlePlaceOrder(
    BuildContext context, {
    required Cart cart,
    String? customDeliveryNotes,
  }) async {
    if (state.isPlacingOrder) return;
    state = state.copyWith(isPlacingOrder: true);
    HapticFeedback.heavyImpact();
    _currentContext = context;
    if (customDeliveryNotes != null) _customDeliveryNotes = customDeliveryNotes;

    final settings = ref.read(storeSettingsProvider).valueOrNull ?? const StoreSettings();
    final hasGrocery = cart.items.any((i) => !isRestaurantProduct(i.product));
    final hasRestaurant = cart.items.any((i) => isRestaurantProduct(i.product));

    // 1. Darkstore Check
    if (hasGrocery && !settings.groceryMartOpen) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
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
      }
      return;
    }

    // 2. Restaurant Open Check
    final closedRestItem = cart.items
        .where((it) => isRestaurantProduct(it.product) && !RestaurantScheduleHelper.isProductRestaurantOpen(it.product, storeSettings: settings))
        .firstOrNull;
    if (hasRestaurant && closedRestItem != null) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
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
      }
      return;
    }

    // 3. Location & Serviceability Tier Check
    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (state.selectedAddressIndex < addresses.length ? addresses[state.selectedAddressIndex] : null);
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

    if (state.deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
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
      }
      return;
    }

    final deliveryFee = state.deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = state.selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - _discountAmount).clamp(0.0, 999999.0);

    // 4. Online Payment Gateway Trigger
    if (state.selectedPayment == 'online') {
      if (grandTotal <= 0.0) {
        await completeOrderPlacement(context, cart: cart, paymentId: 'FREE_PROMO_${DateTime.now().millisecondsSinceEpoch}');
        return;
      }

      if (grandTotal < 1.0) {
        state = state.copyWith(isPlacingOrder: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.primary,
              content: Text('Minimum amount for online payment is ₹1.00', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!kIsWeb) {
        state = state.copyWith(
          isPlacingOrder: true,
          pendingCart: cart,
          pendingGrandTotal: grandTotal,
        );

        final user = ref.read(authProvider).value;
        final prefs = await SharedPreferences.getInstance();
        final rawPhone = user?.phone ?? prefs.getString('user_phone') ?? '';
        final digitsOnly = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
        final cleanPhone = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
        final userEmail = user?.email;
        final hasValidEmail = userEmail != null && userEmail.contains('@') && userEmail.contains('.');
        final customerName = user?.name ?? 'FastKirana Customer';

        bool cashfreeLaunched = false;
        try {
          final dio = ref.read(dioProvider);
          final cfRes = await dio.post(
            '/api/payment/cashfree/create-order',
            data: {
              'amount': grandTotal,
              if (state.pendingCashfreeOrderId != null) 'orderId': state.pendingCashfreeOrderId,
              'customerPhone': cleanPhone.length == 10 ? cleanPhone : '9999999999',
              if (hasValidEmail) 'customerEmail': userEmail.trim(),
              'customerName': customerName,
            },
            options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
          );

          if (cfRes.data != null && cfRes.data['paymentSessionId'] != null) {
            final paymentSessionId = cfRes.data['paymentSessionId'].toString();
            final cfOrderId = cfRes.data['orderId']?.toString() ?? 'cf_${DateTime.now().millisecondsSinceEpoch}';
            state = state.copyWith(pendingCashfreeOrderId: cfOrderId);

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

            // Direct UPI Intent
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

        if (!cashfreeLaunched) {
          state = state.copyWith(isPlacingOrder: false);
          if (context.mounted && grandTotal > 0) {
            await PaymentFailedCodSheet.show(
              context: context,
              grandTotal: grandTotal,
              onRetryPayment: () {
                state = state.copyWith(pendingCashfreeOrderId: null);
                handlePlaceOrder(context, cart: cart);
              },
              onCancelOrder: () {
                state = state.copyWith(isPlacingOrder: false);
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
              },
              onConfirmCod: () async {
                state = state.copyWith(selectedPayment: 'cod', isPlacingOrder: true);
                await completeOrderPlacement(context, cart: cart);
              },
            );
            return;
          }
        }
      }

      if (context.mounted) {
        state = state.copyWith(isPlacingOrder: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.primary,
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

    // Cash on Delivery (COD)
    await completeOrderPlacement(context, cart: cart);
  }

  // ─── Complete Order Placement ──────────────────────────────────────────────

  Future<void> completeOrderPlacement(
    BuildContext context, {
    required Cart cart,
    String? paymentId,
  }) async {
    // Anti-Fraud check
    if (state.selectedPayment == 'online') {
      final isFreePromo = (_discountAmount >= cart.subtotal && cart.subtotal > 0) ||
          (state.pendingGrandTotal != null && state.pendingGrandTotal! <= 0);
      if ((paymentId == null || paymentId.trim().isEmpty) && !isFreePromo) {
        state = state.copyWith(isPlacingOrder: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.primary,
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
        (state.selectedAddressIndex < addresses.length ? addresses[state.selectedAddressIndex] : null);

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

    if (state.deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
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
      }
      return;
    }

    final deliveryFee = state.deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final packagingFee = state.selectedPackaging == 'PREMIUM' ? 15.0 : 0.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - _discountAmount).clamp(0.0, 999999.0);

    final selectedAddr = state.deliveryMethod == 'PICKUP'
        ? '🏬 Self Pickup: FastKirana Darkstore Counter'
        : (selectedAddress != null ? selectedAddress.fullAddress : 'Ghatampur Express Zone');

    final user = ref.read(authProvider).value;
    final prefs = await SharedPreferences.getInstance();
    final userId = user?.id ?? prefs.getString('user_id') ?? '';
    final buyerPhone = user?.phone?.isNotEmpty == true
        ? user!.phone!
        : (prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '');
    final buyerName = user?.name?.isNotEmpty == true
        ? user!.name!
        : (prefs.getString('user_name') ?? 'FastKirana Customer');

    final isOrderForSomeone = state.customReceiverName?.isNotEmpty == true || state.customReceiverPhone?.isNotEmpty == true;

    final receiverName = state.customReceiverName?.isNotEmpty == true
        ? state.customReceiverName!
        : (user?.name?.isNotEmpty == true
            ? user!.name!
            : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                ? selectedAddress.label
                : 'FastKirana Customer'));

    final receiverPhone = state.customReceiverPhone?.isNotEmpty == true
        ? state.customReceiverPhone!
        : (user?.phone?.isNotEmpty == true
            ? user!.phone!
            : (buyerPhone.isNotEmpty ? buyerPhone : (selectedAddress?.phone.isNotEmpty == true ? selectedAddress!.phone : '')));

    final instructionLabels = <String>[];
    for (final preset in CheckoutDeliveryInstructions.presets) {
      if (state.selectedDeliveryInstructions.contains(preset.id)) {
        instructionLabels.add('${preset.icon} ${preset.title}');
      }
    }
    final customNote = _customDeliveryNotes.trim();
    if (customNote.isNotEmpty) {
      instructionLabels.add('📍 Note: $customNote');
    }
    if (_cookingInstruction != null && _cookingInstruction!.trim().isNotEmpty) {
      instructionLabels.add('🍳 Kitchen: ${_cookingInstruction!.trim()}');
    }

    String orderNotes = instructionLabels.isNotEmpty
        ? instructionLabels.join(' | ')
        : (state.deliveryInstruction.isNotEmpty ? state.deliveryInstruction : '🔔 Ring Bell');
    if (isOrderForSomeone) {
      final forStr = '🎁 Order for: $receiverName${receiverPhone.isNotEmpty ? ' ($receiverPhone)' : ''}';
      orderNotes = '$forStr | $orderNotes';
    }

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
      if (isRestaurantProduct(item.product)) {
        final reg = RestaurantRegistry.find(getOutletName(item.product));
        if (reg != null) {
          shopName = reg.name;
          restaurantId = reg.id;
          break;
        }
      }
    }
    // Safety fallback: If cart contains restaurant items, ensure valid non-null restaurantId
    if (hasRestaurant && (restaurantId == null || restaurantId.isEmpty)) {
      restaurantId = 'REST-101';
      shopName = 'A.S. Restaurant & Cafe';
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
      discount: _discountAmount,
      deliveryFee: deliveryFee,
      taxes: 0,
      miscFee: packagingFee,
      total: grandTotal,
      paymentMethod: state.selectedPayment == 'online' ? PaymentMethod.upi : PaymentMethod.cod,
      paymentStatus: paymentId != null ? 'PAID' : 'PENDING',
      deliveryMethod: state.deliveryMethod,
      customerName: receiverName,
      customerPhone: receiverPhone,
      customerAddress: selectedAddr,
      notes: orderNotes,
      couponCode: _couponCode,
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

    var placedOrder = newOrder;
    try {
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
        'paymentMethod': state.selectedPayment == 'online' ? 'UPI' : 'COD',
        'paymentStatus': isOnlinePaid ? 'PAID' : 'PENDING',
        'paymentId': paymentId,
        'cfOrderId': state.pendingCashfreeOrderId,
        'deliveryMethod': state.deliveryMethod,
        'notes': orderNotes,
        'couponCode': _couponCode,
        'discount': _discountAmount,
        'customerAddress': selectedAddr,
        'latitude': selectedAddress?.latitude,
        'longitude': selectedAddress?.longitude,
        'lat': selectedAddress?.latitude,
        'lng': selectedAddress?.longitude,
        'shopName': (hasGrocery && hasRestaurant) ? 'FastKirana Dark Store' : shopName,
        'restaurantId': restaurantId,
        'packagingOption': state.selectedPackaging,
        'packagingFee': packagingFee,
        'items': cart.items.map((i) {
          final isRest = isRestaurantProduct(i.product);
          final itemRestId = i.product.restaurantId ??
              i.product.restaurant?.id ??
              (isRest ? (RestaurantRegistry.find(getOutletName(i.product))?.id ?? restaurantId) : null);
          return {
            'productId': i.product.id,
            'quantity': i.quantity,
            'price': i.product.price,
            'name': i.product.name,
            'selectedVariant': i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
            'variant': i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
            'unit': i.product.unit,
            'restaurantId': itemRestId,
            'menuSection': i.product.menuSection,
            'tags': i.product.tags,
            'product': {
              'id': i.product.id,
              'name': i.product.name,
              'price': i.product.price,
              'imageUrl': i.product.imageUrl,
              'slug': i.product.slug,
              'unit': i.product.unit,
              'restaurantId': itemRestId,
              'menuSection': i.product.menuSection,
              'tags': i.product.tags,
            }
          };
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

        if (data['orders'] is List && (data['orders'] as List).isNotEmpty) {
          final repo = OrderRepository(ref.read(dioProvider));
          for (final raw in data['orders']) {
            if (raw is Map<String, dynamic>) {
              try {
                final ord = Order.fromJson(raw);
                await repo.savePlacedOrderLocally(ord);
              } catch (e, _) { LoggerService.error('CheckoutController: savePlacedOrderLocally', e); }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Backend sync notice: $e');
      final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;

      // 🛡️ EMERGENCY RECOVERY: If paid online, save locally and proceed
      if (isOnlinePaid) {
        debugPrint('Emergency Payment Recovery: Order $orderId was paid ($paymentId) but backend sync failed. Recovering gracefully.');
        await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);
      } else {
        state = state.copyWith(isPlacingOrder: false);
        if (context.mounted) {
          String errorMsg = 'Failed to place order. Please check your connection and try again.';
          if (e is DioException) {
            final serverErr = e.response?.data;
            if (serverErr is Map) {
              final msg = serverErr['detail'] ?? serverErr['error'] ?? serverErr['message'];
              if (msg != null && msg.toString().isNotEmpty) {
                errorMsg = msg.toString();
              }
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

    // Save primary order locally
    await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);

    // Subtle pleasant confirmation chime and haptic sensation
    unawaited(CustomerSoundService.instance.playOrderSuccessSound());
    await Future.delayed(const Duration(milliseconds: 200));

    // Clear cart and invalidate
    await ref.read(cartProvider.notifier).clearCart();
    ref.invalidate(ordersProvider(userId));
    ref.invalidate(ordersProvider(''));
    ref.invalidate(ordersProvider('admin'));

    if (!context.mounted) return;

    final successPage = OrderSuccessScreen(
      orderId: placedOrder.displayId,
      totalAmount: grandTotal,
      deliveryAddress: selectedAddr,
      paymentMethod: state.selectedPayment == 'online' ? 'CASHFREE (PAID)' : 'CASH ON DELIVERY',
      order: placedOrder,
    );

    Navigator.pushReplacement(
      context,
      FadeSlideRoute(page: successPage),
    );
  }
}
