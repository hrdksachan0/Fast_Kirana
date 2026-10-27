import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'payment_gateway_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/tracer_service.dart';
import '../../../core/services/customer_sound_service.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/utils/app_connectivity.dart';
import '../../../data/models/cart.dart';
import '../../../data/models/checkout_draft.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/store_settings.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/store_hub_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../orders/orders_screen.dart';
import '../order_success_screen.dart';
import '../widgets/payment_failed_cod_sheet.dart';
import '../widgets/checkout_delivery_instructions.dart';

// ─── State ──────────────────────────────────────────────────────────────────

const _sentinel = Object();

class CheckoutState {
  final bool isPlacingOrder;
  final String selectedPayment; // 'cod' | 'online'
  final bool useWalletBalance;
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
    this.useWalletBalance = true,
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
    bool? useWalletBalance,
    String? selectedPackaging,
    String? deliveryMethod,
    int? selectedAddressIndex,
    String? deliveryInstruction,
    Set<String>? selectedDeliveryInstructions,
    String? customReceiverName,
    String? customReceiverPhone,
    Object? pendingOrderId = _sentinel,
    Object? pendingCashfreeOrderId = _sentinel,
    Object? pendingCart = _sentinel,
    Object? pendingGrandTotal = _sentinel,
    bool clearReceiverDetails = false,
  }) {
    return CheckoutState(
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      selectedPayment: selectedPayment ?? this.selectedPayment,
      useWalletBalance: useWalletBalance ?? this.useWalletBalance,
      selectedPackaging: selectedPackaging ?? this.selectedPackaging,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      selectedAddressIndex: selectedAddressIndex ?? this.selectedAddressIndex,
      deliveryInstruction: deliveryInstruction ?? this.deliveryInstruction,
      selectedDeliveryInstructions: selectedDeliveryInstructions ?? this.selectedDeliveryInstructions,
      customReceiverName: clearReceiverDetails ? null : (customReceiverName ?? this.customReceiverName),
      customReceiverPhone: clearReceiverDetails ? null : (customReceiverPhone ?? this.customReceiverPhone),
      pendingOrderId: identical(pendingOrderId, _sentinel) ? this.pendingOrderId : pendingOrderId as String?,
      pendingCashfreeOrderId: identical(pendingCashfreeOrderId, _sentinel) ? this.pendingCashfreeOrderId : pendingCashfreeOrderId as String?,
      pendingCart: identical(pendingCart, _sentinel) ? this.pendingCart : pendingCart as Cart?,
      pendingGrandTotal: identical(pendingGrandTotal, _sentinel) ? this.pendingGrandTotal : pendingGrandTotal as double?,
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
  late final PaymentGatewayHandler _paymentHandler = PaymentGatewayHandler(dio: ref.read(dioProvider));
  BuildContext? _currentContext;
  static final Set<String> _acknowledgedOrderIds = {};
  static final Map<String, Future<void>> _activeOrderCompletions = {};

  // Parameters cached for payment callbacks
  double _discountAmount = 0.0;
  String? _couponCode;
  String? _cookingInstruction;
  double _tipAmount = 0.0;
  String _customDeliveryNotes = '';
  bool _isHandlingPaymentDismissal = false;

  CheckoutController(this.ref) : super(const CheckoutState());

  void init({
    required BuildContext context,
    double discountAmount = 0.0,
    String? couponCode,
    String? cookingInstruction,
    double tipAmount = 0.0,
  }) {
    _currentContext = context;
    _discountAmount = discountAmount;
    _couponCode = couponCode;
    _cookingInstruction = cookingInstruction;
    _tipAmount = tipAmount;

    if (cookingInstruction != null && cookingInstruction.trim().isNotEmpty) {
      state = state.copyWith(
        deliveryInstruction: '📝 Note: ${cookingInstruction.trim()} | 🔔 Ring Bell',
      );
    }

    _paymentHandler.initialize(
      onSuccess: _onCashfreeSuccess,
      onError: _onCashfreeError,
    );

    PaymentGatewayHandler.getPendingCfOrderId().then((pendingId) async {
      final draft = await CheckoutDraft.loadAcceptedDraft();
      final effectivePendingId = (pendingId != null && pendingId.isNotEmpty) ? pendingId : draft?.cfOrderId;
      if (effectivePendingId != null && effectivePendingId.isNotEmpty) {
        final currentCart = ref.read(cartProvider).value ?? Cart.empty();
        final amountStr = await PaymentGatewayHandler.getPendingCfAmount();
        final pendingAmount = amountStr != null ? double.tryParse(amountStr) : draft?.grandTotal;

        // Swiggy/Blinkit rule: If cart changed (different items or amount), discard stale pending payment session immediately!
        final bool isCartConsistent = currentCart.items.isNotEmpty &&
            draft != null &&
            draft.items.length == currentCart.items.length &&
            (pendingAmount != null && (pendingAmount - (currentCart.subtotal + draft.deliveryFee + draft.packagingFee)).abs() < 1.0);

        if (!isCartConsistent) {
          await PaymentGatewayHandler.clearPendingPaymentRecovery();
          await CheckoutDraft.clearAcceptedDraft();
          state = state.copyWith(
            pendingCashfreeOrderId: null,
            pendingGrandTotal: null,
            pendingCart: null,
          );
          return;
        }
        try {
          final verification = await _paymentHandler.verifyPayment(effectivePendingId, maxAttempts: 3);
          if (verification.isPaid && verification.paymentId != null) {
            await PaymentGatewayHandler.clearPendingPaymentRecovery();
            await CheckoutDraft.clearAcceptedDraft();
            state = state.copyWith(
              isPlacingOrder: false,
              pendingCashfreeOrderId: null,
              pendingGrandTotal: null,
              pendingCart: null,
            );
            if (_currentContext != null && _currentContext!.mounted) {
              await completeOrderPlacement(
                _currentContext!,
                draft: draft,
                cart: ref.read(cartProvider).value ?? Cart.empty(),
                paymentId: verification.paymentId,
                serverOrderId: verification.serverOrderId,
                serverReadableId: verification.readableId,
              );
            }
            return;
          } else if (verification.isFailed) {
            // ONLY confirmed terminal failed / cancelled / expired unpaid attempts can be cleared!
            await PaymentGatewayHandler.clearPendingPaymentRecovery();
            await CheckoutDraft.clearAcceptedDraft();
            state = state.copyWith(
              pendingCashfreeOrderId: null,
              pendingGrandTotal: null,
              pendingCart: null,
            );
            return;
          }
        } catch (_) {
          // Network error/timeout/exception: retain recovery
        }

        // Webhook check: If order was already inserted into PostgreSQL, auto-recover and navigate to success!
        try {
          final dio = ref.read(dioProvider);
          final cleanCf = effectivePendingId.trim();
          final checkRes = await dio.get('/api/orders', queryParameters: {'cfOrderId': cleanCf});
          if (checkRes.statusCode == 200 && checkRes.data is List && (checkRes.data as List).isNotEmpty) {
            final existingOrderData = (checkRes.data as List).first;
            final existingOrder = Order.fromJson(existingOrderData);
            await PaymentGatewayHandler.clearPendingPaymentRecovery();
            await CheckoutDraft.clearAcceptedDraft();
            state = state.copyWith(
              isPlacingOrder: false,
              pendingCashfreeOrderId: null,
              pendingGrandTotal: null,
              pendingCart: null,
            );
            if (_currentContext != null && _currentContext!.mounted) {
              // ignore: use_build_context_synchronously
            await _finishOrderPlacement(
                placedOrder: existingOrder,
                grandTotal: existingOrder.total,
                selectedAddr: existingOrder.customerAddress ?? '',
                userId: existingOrder.userId,
                context: _currentContext,
              );
            }
            return;
          }
        } catch (_) {}

        // PENDING, ACTIVE, timeout, unavailable, or unknown results:
        // PRESERVE recovery and display banner!
        state = state.copyWith(
          pendingCashfreeOrderId: effectivePendingId,
          pendingGrandTotal: pendingAmount,
        );
      }
    });
  }

  // ─── State Modifiers ───────────────────────────────────────────────────────

  void setPaymentMethod(String method) {
    state = state.copyWith(selectedPayment: method);
  }

  void setUseWalletBalance(bool use) {
    state = state.copyWith(useWalletBalance: use);
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
    final draft = await CheckoutDraft.loadAcceptedDraft();
    final cart = state.pendingCart ?? ref.read(cartProvider).value;
    if (cart == null && draft == null) {
      state = state.copyWith(isPlacingOrder: false);
      return;
    }

    // Ensure placing overlay is dismissed so only the sleek high-trust payment dialog shows
    state = state.copyWith(isPlacingOrder: false);

    // 1. High-trust fullscreen confirmation dialog
    bool dialogShown = false;
    final navContext = _currentContext ?? AppRouter.navigatorKey.currentContext;

    void dismissConfirmingDialog() {
      try {
        AppRouter.navigatorKey.currentState?.popUntil((route) => route.settings.name != 'payment_confirming_dialog');
      } catch (_) {}
    }

    if (navContext != null && navContext.mounted) {
      dialogShown = true;
      showDialog(
        context: navContext,
        barrierDismissible: true,
        routeSettings: const RouteSettings(name: 'payment_confirming_dialog'),
        builder: (dialogCtx) => PopScope(
          canPop: true,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A344)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirming Payment...',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Securing your order with the kitchen.\nPlease do not press back.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    PaymentVerificationResult? verification;
    try {
      // 2. Fast poll backend (at most 4 attempts ~1.5s)
      verification = await _paymentHandler.verifyPayment(cfOrderId, maxAttempts: 4);
    } catch (vErr) {
      debugPrint('Cashfree verification error: $vErr');
    } finally {
      // GUARANTEED: Dialog is ALWAYS dismissed!
      if (dialogShown) {
        dismissConfirmingDialog();
      }
    }

    final verifiedPaid = verification?.isPaid == true;
    final resolvedPaymentId = verification?.paymentId;

    final context = _currentContext ?? AppRouter.navigatorKey.currentContext;
    if (!verifiedPaid || resolvedPaymentId == null) {
      debugPrint('❌ Cashfree payment verification status: ${verification?.status} (cfOrderId: $cfOrderId)');

      // 3. Webhook fallback check: If server webhook already created the order in DB, discover it and navigate directly to success!
      try {
        final dio = ref.read(dioProvider);
        final cleanCf = cfOrderId.trim();
        final checkRes = await dio.get('/api/orders', queryParameters: {'cfOrderId': cleanCf});
        if (checkRes.statusCode == 200 && checkRes.data is List && (checkRes.data as List).isNotEmpty) {
          final matchingOrderData = (checkRes.data as List).firstWhere(
            (o) {
              if (o is! Map) return false;
              final oNotes = o['notes']?.toString() ?? '';
              final oCf = o['cfOrderId']?.toString() ?? '';
              final oReadable = o['readableId']?.toString() ?? '';
              final oId = o['id']?.toString() ?? '';
              return oNotes.contains(cleanCf) || oCf == cleanCf || oReadable == cleanCf || oId == cleanCf;
            },
            orElse: () => null,
          );
          if (matchingOrderData != null) {
            final existingOrder = Order.fromJson(matchingOrderData);
            await PaymentGatewayHandler.clearPendingPaymentRecovery();
            await CheckoutDraft.clearAcceptedDraft();
            state = state.copyWith(
              isPlacingOrder: false,
              pendingCashfreeOrderId: null,
              pendingGrandTotal: null,
              pendingCart: null,
            );
            final activeCtx = (context != null && context.mounted)
                ? context
                : AppRouter.navigatorKey.currentContext;
            // ignore: use_build_context_synchronously
            await _finishOrderPlacement(
              placedOrder: existingOrder,
              grandTotal: existingOrder.total,
              selectedAddr: existingOrder.customerAddress ?? '',
              userId: existingOrder.userId,
              orderedItems: (existingOrder.items ?? []).map((i) => i.toJson()).toList(),
              context: activeCtx,
            );
            return;
          }
        }
      } catch (checkErr) {
        debugPrint('Post-verify DB order check note: $checkErr');
      }

      // Swiggy/Blinkit rule: If not paid, user cancelled, backed out, or failed payment.
      // Immediately clear all pending session, recovery, and draft so NO amber recovery banner displays!
      await PaymentGatewayHandler.clearPendingPaymentRecovery();
      await CheckoutDraft.clearAcceptedDraft();
      state = state.copyWith(
        isPlacingOrder: false,
        pendingCashfreeOrderId: null,
        pendingGrandTotal: null,
        pendingCart: null,
      );

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.slate800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Payment was cancelled or not completed. Your items are saved in your cart.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 4. Payment verified! Clear recovery flags immediately so warning banner NEVER displays
    await PaymentGatewayHandler.clearPendingPaymentRecovery();
    await CheckoutDraft.clearAcceptedDraft();
    state = state.copyWith(
      isPlacingOrder: false,
      pendingCashfreeOrderId: null,
      pendingGrandTotal: null,
      pendingCart: null,
    );

    final activeContext = (_currentContext != null && _currentContext!.mounted)
        ? _currentContext
        : AppRouter.navigatorKey.currentContext;

    // Always complete order placement to backend API even if UI context was detached/unmounted during UPI app switch
    // ignore: use_build_context_synchronously
    await completeOrderPlacement(
      activeContext,
      draft: draft,
      cart: cart ?? Cart.empty(),
      paymentId: resolvedPaymentId,
      serverOrderId: verification?.serverOrderId,
      serverReadableId: verification?.readableId,
    );
  }

  Future<void> _onCashfreeError(CFErrorResponse errorResponse, String cfOrderId) async {
    HapticFeedback.lightImpact();

    PaymentVerificationResult? fastVerify;
    try {
      // Quick verification: check if server already marked order PAID (e.g., slow SDK callback)
      fastVerify = await _paymentHandler.verifyPayment(cfOrderId, maxAttempts: 6);
      if (fastVerify.isPaid) {
        debugPrint('✅ Payment verified as PAID on server despite error callback! Routing to success...');
        await _onCashfreeSuccess(cfOrderId);
        return;
      }
    } catch (vErr) {
      debugPrint('Cashfree error verify check note: $vErr');
    }

    final rawMsg = errorResponse.getMessage() ?? '';
    final rawCode = errorResponse.getCode() ?? '';
    final rawStatus = errorResponse.getStatus() ?? '';
    final msg = rawMsg.toUpperCase();
    final code = rawCode.toUpperCase();
    final status = rawStatus.toUpperCase();

    final isUserBackout = msg.contains('USER_DROPPED') ||
        msg.contains('CANCEL') ||
        msg.contains('BACK') ||
        code.contains('USER_DROPPED') ||
        code.contains('CANCEL') ||
        code.contains('BACK') ||
        status.contains('USER_DROPPED') ||
        status.contains('CANCEL');

    final total = state.pendingGrandTotal ?? 0.0;
    final cart = state.pendingCart ?? ref.read(cartProvider).value;
    final context = _currentContext;

    // Swiggy/Blinkit rule: Always cleanly reset in-flight state and clear pending payment session
    await PaymentGatewayHandler.clearPendingPaymentRecovery();
    await CheckoutDraft.clearAcceptedDraft();
    state = state.copyWith(
      isPlacingOrder: false,
      pendingCashfreeOrderId: null,
      pendingGrandTotal: null,
      pendingCart: null,
    );

    // If user deliberately pressed back or dropped out, return gracefully without scary modals
    if (isUserBackout) {
      debugPrint('ℹ️ User dropped or cancelled Cashfree payment ($cfOrderId). Returning cleanly to checkout.');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.slate800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Payment was cancelled. Your cart items are saved.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Prompt customer immediately with options: Retry Payment, Convert to COD, or Cancel Order
    if (context != null && context.mounted && total > 0 && cart != null) {
      await PaymentFailedCodSheet.show(
        context: context,
        grandTotal: total,
        onRetryPayment: () async {
          await PaymentGatewayHandler.clearPendingPaymentRecovery();
          await CheckoutDraft.clearAcceptedDraft();
          state = state.copyWith(
            isPlacingOrder: false,
            pendingCashfreeOrderId: null,
            pendingGrandTotal: null,
            pendingCart: null,
          );
          if (context.mounted) {
            handlePlaceOrder(context, cart: cart);
          }
        },
        onCancelOrder: () async {
          await PaymentGatewayHandler.clearPendingPaymentRecovery();
          await CheckoutDraft.clearAcceptedDraft();
          state = state.copyWith(
            isPlacingOrder: false,
            pendingCashfreeOrderId: null,
            pendingGrandTotal: null,
            pendingCart: null,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppDesignSystem.rose600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text(
                  'Payment attempt was not completed. Your items are saved in your cart.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            );
          }
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
    if (state.pendingCashfreeOrderId != null && state.pendingCashfreeOrderId!.isNotEmpty) {
      final verification = await _paymentHandler.verifyPayment(state.pendingCashfreeOrderId!, maxAttempts: 1);
      if (verification.isPaid && verification.paymentId != null) {
        final draft = await CheckoutDraft.loadAcceptedDraft();
        if (context.mounted) {
          await completeOrderPlacement(
            context,
            draft: draft,
            cart: state.pendingCart ?? ref.read(cartProvider).value ?? Cart.empty(),
            paymentId: verification.paymentId,
          );
        }
        return;
      }
      // If payment was not completed/paid, clear previous attempt and allow fresh placement
      await PaymentGatewayHandler.clearPendingPaymentRecovery();
      await CheckoutDraft.clearAcceptedDraft();
      state = state.copyWith(
        pendingCashfreeOrderId: null,
        pendingGrandTotal: null,
        pendingCart: null,
      );
    }
    TracerService.startTrace('customer_checkout_tap', attributes: {
      'cart_subtotal': cart.subtotal,
      'items_count': cart.items.length,
      'payment_method': state.selectedPayment,
      'delivery_method': state.deliveryMethod,
    });
    state = state.copyWith(isPlacingOrder: true);
    HapticFeedback.heavyImpact();
    _currentContext = context;
    if (customDeliveryNotes != null) _customDeliveryNotes = customDeliveryNotes;

    // Fast connectivity check: Verify active network transport immediately without blocking HTTP healthz probe
    final connectivity = ref.read(connectivityProvider);
    final hasActiveTransport = connectivity.results.isEmpty || connectivity.results.any((r) => r != ConnectivityResult.none);
    if (!mounted) return;
    if (!context.mounted || (!hasActiveTransport && !connectivity.isOnline)) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Connect to the internet to confirm prices and place your order.'),
        ));
      }
      return;
    }

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
              'FastMinute Grocery Darkstore is currently closed. Orders cannot be placed right now.',
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

    if (state.deliveryMethod != 'PICKUP' && selectedAddress == null) {
      state = state.copyWith(isPlacingOrder: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.rose600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text(
              'Please select or add a delivery address to place your order.',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        );
      }
      return;
    }

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

    final isCombined = hasGrocery && hasRestaurant;

    final deliveryFee = state.deliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee;
    final basePackagingFee = state.deliveryMethod == 'PICKUP'
        ? 0.0
        : (isCombined ? (storeSettings?.combinedMiscFee ?? 5.0) : (storeSettings?.miscFee ?? 5.0));
    final packagingFee = state.selectedPackaging == 'PREMIUM' ? 15.0 : basePackagingFee;
    final grandTotalBeforeWallet = (subtotal + deliveryFee + packagingFee + _tipAmount - _discountAmount).clamp(0.0, 999999.0);

    final walletState = ref.read(walletNotifierProvider);
    final double walletUsable = walletState.totalUsable;
    const double minWalletOrderValue = 199.0;
    final bool isEligibleForWallet = subtotal >= minWalletOrderValue;
    final double walletAmountUsed = (state.useWalletBalance && isEligibleForWallet)
        ? (walletUsable >= grandTotalBeforeWallet ? grandTotalBeforeWallet : walletUsable)
        : 0.0;
    final grandTotal = (grandTotalBeforeWallet - walletAmountUsed).clamp(0.0, 999999.0);

    // 4A. Full Wallet Payment Auto-Route
    if (walletAmountUsed >= grandTotalBeforeWallet && grandTotalBeforeWallet > 0) {
      await completeOrderPlacement(context, cart: cart, paymentId: 'WALLET_${DateTime.now().millisecondsSinceEpoch}');
      return;
    }

    // 4B. Online Payment Gateway Trigger
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

        final itemsPayload = cart.items.map((i) {
          final isRest = isRestaurantProduct(i.product);
          final itemRestId = i.product.restaurantId ??
              i.product.restaurant?.id ??
              (isRest ? (RestaurantRegistry.find(getOutletName(i.product))?.id ?? 'REST-101') : null);
          return {
            'productId': i.product.id,
            'quantity': i.quantity,
            'price': i.product.price,
            'name': i.product.name,
            'selectedVariant': i.selectedVariant ?? (i.product.unit.isNotEmpty ? i.product.unit : null),
            'restaurantId': itemRestId,
            'imageUrl': i.product.imageUrl,
          };
        }).toList();

        final initialDraft = CheckoutDraft(
          hubId: nearestHub.id,
          deliveryMethod: state.deliveryMethod,
          selectedAddress: selectedAddress,
          selectedAddressIndex: state.selectedAddressIndex,
          customReceiverName: state.customReceiverName,
          customReceiverPhone: state.customReceiverPhone,
          selectedDeliveryInstructions: state.selectedDeliveryInstructions,
          cookingInstruction: _cookingInstruction,
          customDeliveryNotes: _customDeliveryNotes,
          couponCode: _couponCode,
          discountAmount: _discountAmount,
          tipAmount: _tipAmount,
          deliveryFee: deliveryFee,
          packagingFee: packagingFee,
          selectedPackaging: state.selectedPackaging,
          selectedPayment: state.selectedPayment,
          isFrozenForPayment: true,
          activePaymentSessionId: state.pendingCashfreeOrderId,
          items: itemsPayload,
          grandTotal: grandTotal,
          cfOrderId: state.pendingCashfreeOrderId,
        );

        final cfOrderId = await _paymentHandler.launchPayment(
          amount: grandTotal,
          customerPhone: cleanPhone.isNotEmpty ? cleanPhone : rawPhone,
          customerEmail: hasValidEmail ? userEmail : null,
          customerName: customerName,
          existingOrderId: null, // Swiggy/Blinkit rule: Cart checkout ALWAYS launches fresh Cashfree session
          userId: user?.id,
          addressId: selectedAddress?.id,
          items: itemsPayload,
          deliveryMethod: state.deliveryMethod,
          storeId: nearestHub.id,
          couponCode: _couponCode,
          discount: _discountAmount,
          tipAmount: _tipAmount,
          deliveryFee: deliveryFee,
          packagingFee: packagingFee,
          packagingOption: state.selectedPackaging,
          onBeforeLaunch: (launchedOrderId) async {
            final draftWithId = initialDraft.copyWith(
              activePaymentSessionId: launchedOrderId,
              cfOrderId: launchedOrderId,
            );
            await CheckoutDraft.saveAcceptedDraft(draftWithId);
            state = state.copyWith(
              pendingCashfreeOrderId: launchedOrderId,
              pendingGrandTotal: grandTotal,
            );
          },
        );

        if (cfOrderId != null) {
          state = state.copyWith(
            pendingCashfreeOrderId: cfOrderId,
            isPlacingOrder: false,
          );
          return;
        }

        state = state.copyWith(isPlacingOrder: false);
          if (context.mounted && grandTotal > 0) {
            await PaymentFailedCodSheet.show(
              context: context,
              grandTotal: grandTotal,
              onRetryPayment: () async {
                await PaymentGatewayHandler.clearPendingPaymentRecovery();
                await CheckoutDraft.clearAcceptedDraft();
                state = state.copyWith(
                  isPlacingOrder: false,
                  pendingCashfreeOrderId: null,
                  pendingGrandTotal: null,
                  pendingCart: null,
                );
                if (context.mounted) {
                  handlePlaceOrder(context, cart: cart);
                }
              },
              onCancelOrder: () async {
                await PaymentGatewayHandler.clearPendingPaymentRecovery();
                await CheckoutDraft.clearAcceptedDraft();
                state = state.copyWith(
                  isPlacingOrder: false,
                  pendingCashfreeOrderId: null,
                  pendingGrandTotal: null,
                  pendingCart: null,
                );
                if (context.mounted) {
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
                await PaymentGatewayHandler.clearPendingPaymentRecovery();
                await CheckoutDraft.clearAcceptedDraft();
                state = state.copyWith(
                  selectedPayment: 'cod',
                  isPlacingOrder: true,
                  pendingCashfreeOrderId: null,
                  pendingGrandTotal: null,
                  pendingCart: null,
                );
                await completeOrderPlacement(context, cart: cart);
              },
            );
            return;
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
    BuildContext? context, {
    Cart? cart,
    CheckoutDraft? draft,
    String? paymentId,
    String? serverOrderId,
    String? serverReadableId,
  }) async {
    final effectiveCart = cart ?? ref.read(cartProvider).value ?? Cart.empty();

    // Swiggy/Blinkit rule: Only use draft items if the draft explicitly matches this confirmed payment
    // and cart items/amount; otherwise, the active cart items represent what the customer actually chose!
    final bool isDraftValid = draft != null &&
        draft.items.isNotEmpty &&
        (effectiveCart.items.isEmpty ||
            ((draft.cfOrderId != null &&
                    paymentId != null &&
                    (paymentId.contains(draft.cfOrderId!) || draft.cfOrderId!.contains(paymentId))) &&
                (draft.items.length == effectiveCart.items.length)));

    final hasDraftItems = isDraftValid;
    final subtotal = hasDraftItems
        ? draft.items.fold<double>(0.0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1))
        : effectiveCart.subtotal;

    final effectiveDiscount = draft?.discountAmount ?? _discountAmount;
    final effectiveTip = draft?.tipAmount ?? _tipAmount;
    final effectiveCoupon = draft?.couponCode ?? _couponCode;
    final effectiveDeliveryMethod = draft?.deliveryMethod ?? state.deliveryMethod;
    final effectivePackaging = draft?.selectedPackaging ?? state.selectedPackaging;
    var effectivePayment = (draft != null && draft.selectedPayment.isNotEmpty)
        ? draft.selectedPayment
        : state.selectedPayment;

    // Anti-Fraud check
    if (effectivePayment == 'online') {
      final isFreePromo = (effectiveDiscount >= subtotal && subtotal > 0) ||
          (state.pendingGrandTotal != null && state.pendingGrandTotal! <= 0);
      if ((paymentId == null || paymentId.trim().isEmpty) && !isFreePromo) {
        state = state.copyWith(isPlacingOrder: false);
        if (context != null && context.mounted) {
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

    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = draft?.selectedAddress ??
        ref.read(selectedAddressProvider) ??
        (state.selectedAddressIndex < addresses.length ? addresses[state.selectedAddressIndex] : null);

    if (effectiveDeliveryMethod != 'PICKUP' && selectedAddress == null) {
      state = state.copyWith(isPlacingOrder: false);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.rose600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text(
              'Please select or add a delivery address to complete your order.',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        );
      }
      return;
    }

    RestaurantInfo? cartRestaurant;
    for (final item in effectiveCart.items) {
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

    if (effectiveDeliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      state = state.copyWith(isPlacingOrder: false);
      if (context != null && context.mounted) {
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

    final hasGrocery = hasDraftItems
        ? draft.items.any((i) => (i['restaurantId'] == null || i['restaurantId'].toString().isEmpty))
        : effectiveCart.items.any((i) => !isRestaurantProduct(i.product));
    final hasRestaurant = hasDraftItems
        ? draft.items.any((i) => (i['restaurantId'] != null && i['restaurantId'].toString().isNotEmpty))
        : effectiveCart.items.any((i) => isRestaurantProduct(i.product));
    final isCombined = hasGrocery && hasRestaurant;

    final deliveryFee = (draft != null && draft.hasFeeBreakdown)
        ? draft.deliveryFee
        : (effectiveDeliveryMethod == 'PICKUP' ? 0.0 : tier.deliveryFee);
    final basePackagingFee = effectiveDeliveryMethod == 'PICKUP'
        ? 0.0
        : (isCombined ? (storeSettings?.combinedMiscFee ?? 5.0) : (storeSettings?.miscFee ?? 5.0));
    final packagingFee = (draft != null && draft.hasFeeBreakdown)
        ? draft.packagingFee
        : (effectivePackaging == 'PREMIUM' ? 15.0 : basePackagingFee);
    final grandTotalBeforeWallet = (draft != null && draft.grandTotal > 0)
        ? draft.grandTotal
        : (subtotal + deliveryFee + packagingFee + effectiveTip - effectiveDiscount).clamp(0.0, 999999.0);

    final selectedAddr = effectiveDeliveryMethod == 'PICKUP'
        ? '🏬 Self Pickup: FastMinute Darkstore Counter'
        : (selectedAddress != null ? selectedAddress.fullAddress : 'Ghatampur Express Zone');

    final user = ref.read(authProvider).value;
    final prefs = await SharedPreferences.getInstance();
    final userId = user?.id ?? prefs.getString('user_id') ?? '';
    final buyerPhone = user?.phone?.isNotEmpty == true
        ? user!.phone!
        : (prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '');
    final buyerName = user?.name?.isNotEmpty == true
        ? user!.name!
        : (prefs.getString('user_name') ?? 'FastMinute Customer');

    final isOrderForSomeone = (draft?.customReceiverName?.isNotEmpty == true || draft?.customReceiverPhone?.isNotEmpty == true) ||
        (state.customReceiverName?.isNotEmpty == true || state.customReceiverPhone?.isNotEmpty == true);

    final receiverName = draft?.customReceiverName?.isNotEmpty == true
        ? draft!.customReceiverName!
        : (state.customReceiverName?.isNotEmpty == true
            ? state.customReceiverName!
            : (user?.name?.isNotEmpty == true
                ? user!.name!
                : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                    ? selectedAddress.label
                    : 'FastMinute Customer')));

    final receiverPhone = draft?.customReceiverPhone?.isNotEmpty == true
        ? draft!.customReceiverPhone!
        : (state.customReceiverPhone?.isNotEmpty == true
            ? state.customReceiverPhone!
            : (user?.phone?.isNotEmpty == true
                ? user!.phone!
                : (buyerPhone.isNotEmpty ? buyerPhone : (selectedAddress?.phone.isNotEmpty == true ? selectedAddress!.phone : ''))));

    final instructionLabels = <String>[];
    final activeInstructions = draft?.selectedDeliveryInstructions ?? state.selectedDeliveryInstructions;
    for (final preset in CheckoutDeliveryInstructions.presets) {
      if (activeInstructions.contains(preset.id)) {
        instructionLabels.add('${preset.icon} ${preset.title}');
      }
    }
    final customNote = (draft?.customDeliveryNotes ?? _customDeliveryNotes).trim();
    if (customNote.isNotEmpty) {
      instructionLabels.add('📍 Note: $customNote');
    }
    final cookingNote = (draft?.cookingInstruction ?? _cookingInstruction)?.trim() ?? '';
    if (cookingNote.isNotEmpty) {
      instructionLabels.add('🍳 Kitchen: $cookingNote');
    }
    if (effectiveTip > 0) {
      instructionLabels.add('💰 Delivery Partner Tip: ₹${effectiveTip.toInt()}');
    }

    String orderNotes = instructionLabels.isNotEmpty
        ? instructionLabels.join(' | ')
        : (state.deliveryInstruction.isNotEmpty ? state.deliveryInstruction : '🔔 Ring Bell');
    if (isOrderForSomeone) {
      final forStr = '🎁 Order for: $receiverName${receiverPhone.isNotEmpty ? ' ($receiverPhone)' : ''}';
      orderNotes = '$forStr | $orderNotes';
    }

    final effectiveCfOrderId = draft?.cfOrderId ?? state.pendingCashfreeOrderId;
    if (effectiveCfOrderId != null && effectiveCfOrderId.isNotEmpty) {
      final cfTag = '[CF_ORDER:$effectiveCfOrderId]';
      if (!orderNotes.contains(cfTag)) {
        orderNotes = '$orderNotes | $cfTag';
      }
    }

    String shopName = 'FastMinute Dark Store';
    String? restaurantId;
    if (hasDraftItems) {
      for (final item in draft.items) {
        if (item['restaurantId'] != null && item['restaurantId'].toString().isNotEmpty) {
          restaurantId = item['restaurantId'].toString();
          shopName = 'Restaurant Kitchen';
          break;
        }
      }
    } else {
      for (final item in effectiveCart.items) {
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
    }
    // Safety fallback: If cart contains restaurant items, ensure valid non-null restaurantId
    if (hasRestaurant && (restaurantId == null || restaurantId.isEmpty)) {
      restaurantId = 'REST-101';
      shopName = 'A.S. Restaurant & Cafe';
    }

    final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;
    final orderId = serverReadableId ?? 'FK-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000)}';

    final List<OrderItem> orderItemsList = hasDraftItems
        ? draft.items.map<OrderItem>((i) {
            final rawId = i['productId']?.toString() ?? 'item_unknown';
            final cleanId = rawId.startsWith('item_') ? rawId.replaceFirst('item_', '') : rawId;
            final baseProductId = cleanId.contains('_') ? cleanId.split('_')[0] : cleanId;
            return OrderItem(
              id: 'item_${i['productId']}',
              productId: baseProductId,
              name: i['name']?.toString() ?? 'Product',
              price: (i['price'] as num?)?.toDouble() ?? 0.0,
              quantity: (i['quantity'] as num?)?.toInt() ?? 1,
              imageUrl: i['imageUrl']?.toString() ?? '',
              selectedVariant: i['selectedVariant']?.toString(),
            );
          }).toList()
        : effectiveCart.items.map<OrderItem>((i) {
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
          }).toList();

    final walletState = ref.read(walletNotifierProvider);
    final double walletUsable = walletState.totalUsable;
    const double minWalletOrderValue = 199.0;
    final bool isEligibleForWallet = subtotal >= minWalletOrderValue;
    final double walletAmountUsed = (state.useWalletBalance && isEligibleForWallet)
        ? (walletUsable >= grandTotalBeforeWallet ? grandTotalBeforeWallet : walletUsable)
        : 0.0;
    final double grandTotal = (grandTotalBeforeWallet - walletAmountUsed).clamp(0.0, 999999.0);
    final bool isFullWalletPay = (walletAmountUsed >= grandTotalBeforeWallet && grandTotalBeforeWallet > 0) ||
        (paymentId != null && paymentId.startsWith('WALLET_'));
    if (isFullWalletPay) {
      effectivePayment = 'wallet';
    }

    final newOrder = Order(
      id: serverOrderId ?? orderId,
      readableId: serverReadableId ?? orderId,
      userId: userId,
      addressId: selectedAddress?.id ?? 'addr_default',
      restaurantId: restaurantId,
      shopName: shopName,
      status: (isOnlinePaid || effectivePayment == 'wallet') ? OrderStatus.confirmed : OrderStatus.adminPending,
      subtotal: subtotal,
      discount: effectiveDiscount,
      deliveryFee: deliveryFee,
      taxes: 0,
      miscFee: packagingFee + effectiveTip,
      total: grandTotal,
      paymentMethod: effectivePayment == 'online'
          ? PaymentMethod.upi
          : (effectivePayment == 'wallet' ? PaymentMethod.wallet : PaymentMethod.cod),
      paymentStatus: (isOnlinePaid || effectivePayment == 'wallet') ? 'PAID' : 'PENDING',
      deliveryMethod: effectiveDeliveryMethod,
      customerName: receiverName,
      customerPhone: receiverPhone,
      customerAddress: selectedAddr,
      notes: orderNotes,
      couponCode: effectiveCoupon,
      createdAt: DateTime.now(),
      items: orderItemsList,
    );

    final List<Map<String, dynamic>> itemsPayload = hasDraftItems
        ? draft.items
        : effectiveCart.items.map((i) {
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
          }).toList();

    var placedOrder = newOrder;

    // ⚡ FAST-TRACK: If server already created and auto-recovered the order during payment verification,
    // skip the redundant POST /api/orders roundtrip and navigate instantly to OrderSuccessScreen!
    if (serverOrderId != null && serverOrderId.isNotEmpty) {
      placedOrder = placedOrder.copyWith(
        id: serverOrderId,
        readableId: serverReadableId ?? serverOrderId,
      );
      debugPrint('⚡ Fast-track order completion: order #${placedOrder.readableId} ($serverOrderId) already confirmed on server.');

      // Save local order copy asynchronously
      unawaited(OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder));

      final activeContext = (context != null && context.mounted)
          ? context
          : AppRouter.navigatorKey.currentContext;

      await _finishOrderPlacement(
        placedOrder: placedOrder,
        grandTotal: grandTotal,
        selectedAddr: selectedAddr,
        userId: userId,
        orderedItems: itemsPayload,
        context: activeContext,
      );
      return;
    }

    Map<String, dynamic>? apiPayload;
    try {
      apiPayload = {
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
        'storeId': (draft != null && draft.hubId != null && draft.hubId!.isNotEmpty) ? draft.hubId! : nearestHub.id,
        'addressId': selectedAddress?.id ?? 'addr_default',
        'paymentMethod': effectivePayment == 'online'
            ? 'UPI'
            : (effectivePayment == 'wallet' ? 'WALLET' : 'COD'),
        'paymentStatus': (isOnlinePaid || effectivePayment == 'wallet') ? 'PAID' : 'PENDING',
        'paymentId': paymentId,
        'cfOrderId': effectiveCfOrderId,
        'traceId': TracerService.activeTraceId,
        'spanId': TracerService.activeSpanId,
        'deliveryMethod': effectiveDeliveryMethod,
        'notes': orderNotes,
        'couponCode': effectiveCoupon,
        'discount': effectiveDiscount,
        'customerAddress': selectedAddr,
        'latitude': selectedAddress?.latitude,
        'longitude': selectedAddress?.longitude,
        'lat': selectedAddress?.latitude,
        'lng': selectedAddress?.longitude,
        'shopName': (hasGrocery && hasRestaurant) ? 'FastMinute Dark Store' : shopName,
        'restaurantId': restaurantId,
        'packagingOption': effectivePackaging,
        'packagingFee': packagingFee,
        'tipAmount': effectiveTip,
        'walletAmountUsed': walletAmountUsed,
        'items': itemsPayload,
      };

      final acceptedDraftToSave = draft ?? CheckoutDraft(
        hubId: (draft != null && draft.hubId != null && draft.hubId!.isNotEmpty) ? draft.hubId! : nearestHub.id,
        deliveryMethod: effectiveDeliveryMethod,
        selectedAddress: selectedAddress,
        selectedAddressIndex: state.selectedAddressIndex,
        customReceiverName: receiverName,
        customReceiverPhone: receiverPhone,
        selectedDeliveryInstructions: activeInstructions,
        cookingInstruction: cookingNote,
        customDeliveryNotes: customNote,
        couponCode: effectiveCoupon,
        discountAmount: effectiveDiscount,
        tipAmount: effectiveTip,
        deliveryFee: deliveryFee,
        packagingFee: packagingFee,
        selectedPackaging: effectivePackaging,
        selectedPayment: effectivePayment,
        isFrozenForPayment: isOnlinePaid,
        activePaymentSessionId: effectiveCfOrderId,
        items: itemsPayload,
        grandTotal: grandTotal,
        cfOrderId: effectiveCfOrderId,
      );
      // Fast dispatch: persist draft asynchronously without blocking the immediate HTTP POST call
      unawaited(CheckoutDraft.saveAcceptedDraft(acceptedDraftToSave));

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

        // Cache all server orders asynchronously without delaying instant screen navigation
        if (data['orders'] is List && (data['orders'] as List).isNotEmpty) {
          final rawOrders = List<dynamic>.from(data['orders']);
          unawaited(() async {
            final repo = OrderRepository(ref.read(dioProvider));
            for (final raw in rawOrders) {
              if (raw is Map<String, dynamic>) {
                try {
                  final ord = Order.fromJson(raw);
                  await repo.savePlacedOrderLocally(ord);
                } catch (e, _) { LoggerService.error('CheckoutController: savePlacedOrderLocally', e); }
              }
            }
          }());
        }
      }
    } catch (e) {
      debugPrint('Backend sync notice: $e');
      final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;

      // 🛡️ CONFIRMED PAYMENT: If paid online, save locally and proceed directly to Order Success!
      if (isOnlinePaid) {
        debugPrint('🛡️ Payment Confirmed ($paymentId): Order placed, clearing recovery and proceeding to Order Success.');
        try {
          await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);
        } catch (saveErr, st) {
          LoggerService.error('CheckoutController: savePlacedOrderLocally emergency', saveErr, st);
        }
        await PaymentGatewayHandler.clearPendingPaymentRecovery();
        await CheckoutDraft.clearAcceptedDraft();
        state = state.copyWith(
          isPlacingOrder: false,
          pendingCashfreeOrderId: null,
          pendingGrandTotal: null,
          pendingCart: null,
        );
        if (apiPayload != null) {
          unawaited(_retryOrderSync(
            apiPayload,
            localOrder: placedOrder,
            grandTotal: grandTotal,
            selectedAddr: selectedAddr,
            userId: userId,
          ));
        }
        // Do NOT return! Proceed directly to _finishOrderPlacement so customer always sees OrderSuccessScreen!
      } else {
        state = state.copyWith(isPlacingOrder: false);
        if (context != null && context.mounted) {
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

    final activeContext = (context != null && context.mounted)
        ? context
        : AppRouter.navigatorKey.currentContext;

    // ignore: use_build_context_synchronously
    await _finishOrderPlacement(
      placedOrder: placedOrder,
      grandTotal: grandTotal,
      selectedAddr: selectedAddr,
      userId: userId,
      orderedItems: itemsPayload,
      context: activeContext,
    );
  }

  Future<void> _finishOrderPlacement({
    required Order placedOrder,
    required double grandTotal,
    required String selectedAddr,
    required String userId,
    List<Map<String, dynamic>>? orderedItems,
    BuildContext? context,
  }) async {
    // Subtle pleasant confirmation chime and haptic sensation immediately
    unawaited(CustomerSoundService.instance.playOrderSuccessSound());

    // Update state to unblock UI immediately
    state = state.copyWith(
      isPlacingOrder: false,
      pendingCashfreeOrderId: null,
      pendingGrandTotal: null,
      pendingCart: null,
    );

    // Guaranteed instant cart clearance on placement to ensure zero leftover items
    final orderId = placedOrder.id;
    unawaited(ref.read(cartProvider.notifier).clearCart(orderId: orderId));
    // Refresh customer wallet balance
    unawaited(ref.read(walletNotifierProvider.notifier).fetchBalance());

    // Fast-track navigation to OrderSuccessScreen using active or root navigator key
    final rootContext = (context != null && context.mounted) ? context : AppRouter.navigatorKey.currentContext;
    final nav = AppRouter.navigatorKey.currentState;
    final successPage = OrderSuccessScreen(
      orderId: placedOrder.displayId,
      totalAmount: grandTotal,
      deliveryAddress: selectedAddr,
      paymentMethod: placedOrder.paymentMethod == PaymentMethod.wallet
          ? 'WALLET (PAID)'
          : (placedOrder.paymentMethod == PaymentMethod.upi ? 'CASHFREE (PAID)' : 'CASH ON DELIVERY'),
      order: placedOrder,
    );

    if (rootContext != null && rootContext.mounted) {
      try {
        Navigator.pushReplacement(
          rootContext,
          FadeSlideRoute(page: successPage),
        );
      } catch (_) {
        nav?.pushReplacement(FadeSlideRoute(page: successPage));
      }
    } else if (nav != null && nav.mounted) {
      nav.pushReplacement(
        FadeSlideRoute(page: successPage),
      );
    }

    // Background asynchronous durable tasks (local cache, cart cleanup, draft clearance)
    unawaited(() async {
      try {
        await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);
        await PaymentGatewayHandler.clearPendingPaymentRecovery();
        await CheckoutDraft.clearAcceptedDraft();

        Future<void>? inFlight = _activeOrderCompletions[orderId];
        if (inFlight != null) {
          await inFlight;
          return;
        }

        final completer = Completer<void>();
        _activeOrderCompletions[orderId] = completer.future;

        try {
          bool isAlreadyAcked = _acknowledgedOrderIds.contains(orderId);
          if (!isAlreadyAcked) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final ackList = prefs.getStringList('acknowledged_order_ids') ?? [];
              if (ackList.contains(orderId)) {
                isAlreadyAcked = true;
                _acknowledgedOrderIds.add(orderId);
              }
            } catch (_) {}
          }
          if (!isAlreadyAcked) {
            try {
              final cartRepo = ref.read(cartRepoProvider);
              final appliedDeltas = await cartRepo.getAppliedOrderDeltas();
              if (appliedDeltas.contains(orderId)) {
                isAlreadyAcked = true;
                _acknowledgedOrderIds.add(orderId);
              }
            } catch (_) {}
          }

          if (isAlreadyAcked) {
            LoggerService.info('CheckoutController: Order $orderId already acknowledged, skipping duplicate cart subtraction.');
          } else {
            // Unconditionally clear the placed cart to ensure zero leftover items
            await ref.read(cartProvider.notifier).clearCart(orderId: orderId);

            _acknowledgedOrderIds.add(orderId);
            try {
              final prefs = await SharedPreferences.getInstance();
              final ackList = prefs.getStringList('acknowledged_order_ids') ?? [];
              if (!ackList.contains(orderId)) {
                ackList.add(orderId);
                if (ackList.length > 50) ackList.removeAt(0);
                await prefs.setStringList('acknowledged_order_ids', ackList);
              }
            } catch (_) {}
          }
        } finally {
          completer.complete();
          _activeOrderCompletions.remove(orderId);
        }

        ref.invalidate(ordersProvider(userId));
        ref.invalidate(ordersProvider(''));
        ref.invalidate(ordersProvider('admin'));
      } catch (bgErr) {
        LoggerService.error('CheckoutController: background post-placement cleanup error', bgErr);
      }
    }());
  }

  Future<void> _retryOrderSync(
    Map<String, dynamic> apiPayload, {
    required Order localOrder,
    required double grandTotal,
    required String selectedAddr,
    required String userId,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Future.delayed(Duration(seconds: attempt * 2));
        final res = await ref.read(dioProvider).post('/api/orders', data: apiPayload);
        if (res.statusCode == 200 || res.statusCode == 201) {
          debugPrint('✅ Background order sync succeeded on retry $attempt!');
          var confirmedOrder = localOrder;
          if (res.data != null && res.data is Map) {
            final data = res.data as Map<String, dynamic>;
            String? serverReadableId = data['readableId']?.toString();
            String? serverId = data['id']?.toString();

            final created = data['order'] ?? (data['orders'] is List && (data['orders'] as List).isNotEmpty ? data['orders'][0] : null);
            if (created is Map) {
              serverReadableId = created['readableId']?.toString() ?? serverReadableId;
              serverId = created['id']?.toString() ?? serverId;
            }

            if (serverReadableId != null && serverReadableId.isNotEmpty) {
              confirmedOrder = confirmedOrder.copyWith(
                id: serverId ?? confirmedOrder.id,
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
                  } catch (e, _) {
                    LoggerService.error('CheckoutController: savePlacedOrderLocally', e);
                  }
                }
              }
            }
          }

          await _finishOrderPlacement(
            placedOrder: confirmedOrder,
            grandTotal: grandTotal,
            selectedAddr: selectedAddr,
            userId: userId,
            orderedItems: (apiPayload['items'] as List?)?.cast<Map<String, dynamic>>(),
            context: _currentContext,
          );
          break;
        }
      } catch (err) {
        debugPrint('Background order sync retry $attempt note: $err');
      }
    }
  }

  Future<void> checkPendingPaymentStatus(BuildContext context) async {
    final cfOrderId = state.pendingCashfreeOrderId ?? await PaymentGatewayHandler.getPendingCfOrderId();
    if (cfOrderId == null || cfOrderId.isEmpty) return;

    if (state.isPlacingOrder) return;
    state = state.copyWith(isPlacingOrder: true);
    try {
      final verification = await _paymentHandler.verifyPayment(cfOrderId, maxAttempts: 2);
      if (verification.isPaid && verification.paymentId != null) {
        final draft = await CheckoutDraft.loadAcceptedDraft();
        final currentCart = state.pendingCart ?? ref.read(cartProvider).value;
        if (!context.mounted) {
          state = state.copyWith(isPlacingOrder: false);
          return;
        }
        await completeOrderPlacement(
          context,
          draft: draft,
          cart: currentCart ?? Cart.empty(),
          paymentId: verification.paymentId,
          serverOrderId: verification.serverOrderId,
          serverReadableId: verification.readableId,
        );
      } else if (verification.isFailed) {
        await PaymentGatewayHandler.clearPendingPaymentRecovery();
        await CheckoutDraft.clearAcceptedDraft();
        state = state.copyWith(
          isPlacingOrder: false,
          pendingCashfreeOrderId: null,
          pendingGrandTotal: null,
          pendingCart: null,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.rose600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Payment verification failed or was cancelled. You may try again or select Cash on Delivery.',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }
      } else {
        // Pending, unavailable, or unknown: PRESERVE recovery!
        state = state.copyWith(
          isPlacingOrder: false,
          pendingCashfreeOrderId: cfOrderId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.amber800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                verification.message ?? 'Payment confirmation is still pending with your bank. We will continue checking.',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isPlacingOrder: false,
        pendingCashfreeOrderId: cfOrderId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.amber800,
            content: Text('Could not reach payment gateway: $e. Recovery retained.'),
          ),
        );
      }
    }
  }

  Future<void> cancelPendingPaymentSession(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (_isHandlingPaymentDismissal || state.isPlacingOrder) return;
    _isHandlingPaymentDismissal = true;
    state = state.copyWith(isPlacingOrder: true);

    String? cfOrderId;
    try {
      cfOrderId = state.pendingCashfreeOrderId ?? await PaymentGatewayHandler.getPendingCfOrderId();
      if (cfOrderId == null || cfOrderId.isEmpty) {
        await PaymentGatewayHandler.clearPendingPaymentRecovery();
        await CheckoutDraft.clearAcceptedDraft();
        if (mounted) {
          state = state.copyWith(
            isPlacingOrder: false,
            pendingCashfreeOrderId: null,
            pendingGrandTotal: null,
            pendingCart: null,
          );
        }
        return;
      }

      final verification = await _paymentHandler.verifyPayment(cfOrderId, maxAttempts: 1);
      if (verification.isPaid && verification.paymentId != null) {
        // Reconcile original attempt without marking it cancelled!
        if (mounted) {
          state = state.copyWith(
            isPlacingOrder: false,
            pendingCashfreeOrderId: cfOrderId,
          );
        }
        if (context.mounted) {
          final draft = await CheckoutDraft.loadAcceptedDraft();
          if (!context.mounted) return;
          final currentCart = state.pendingCart ?? Cart.empty();
          await completeOrderPlacement(
            context,
            draft: draft,
            cart: currentCart,
            paymentId: verification.paymentId,
            serverOrderId: verification.serverOrderId,
            serverReadableId: verification.readableId,
          );
        }
        return;
      }

      // 2. User explicitly tapped "Dismiss & Pay Now"
      // Clear previous unconfirmed/cancelled attempt and allow immediate fresh payment
      await PaymentGatewayHandler.clearPendingPaymentRecovery();
      await CheckoutDraft.clearAcceptedDraft();

      final prefs = await SharedPreferences.getInstance();
      final cancelledList = prefs.getStringList('cancelled_payment_attempts') ?? [];
      if (!cancelledList.contains(cfOrderId)) {
        cancelledList.add(cfOrderId);
        await prefs.setStringList('cancelled_payment_attempts', cancelledList);
      }

      final activeCart = state.pendingCart ?? ref.read(cartProvider).value ?? Cart.empty();

      if (mounted) {
        state = state.copyWith(
          isPlacingOrder: false,
          pendingCashfreeOrderId: null,
          pendingGrandTotal: null,
          pendingCart: null,
        );
      }

      // Immediately launch a fresh payment attempt if cart has items!
      if (context.mounted && activeCart.items.isNotEmpty) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.emerald600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Starting a fresh payment attempt...',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
        await handlePlaceOrder(context, cart: activeCart);
      } else if (context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.slate800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Previous attempt cleared. You can now place your order.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
        }
      }
    } catch (e) {
      await PaymentGatewayHandler.clearPendingPaymentRecovery();
      await CheckoutDraft.clearAcceptedDraft();
      if (mounted) {
        state = state.copyWith(
          isPlacingOrder: false,
          pendingCashfreeOrderId: null,
          pendingGrandTotal: null,
          pendingCart: null,
        );
      }
      if (context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.slate800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Previous attempt cleared. You can now place your order.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
        }
      }
    } finally {
      _isHandlingPaymentDismissal = false;
      if (mounted && state.isPlacingOrder) {
        state = state.copyWith(isPlacingOrder: false);
      }
    }
  }
}
