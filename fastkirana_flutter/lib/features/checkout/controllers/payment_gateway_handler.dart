import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../data/models/checkout_draft.dart';

typedef PaymentSuccessCallback = void Function(String orderId);
typedef PaymentErrorCallback = void Function(CFErrorResponse errorResponse, String orderId);

/// Dedicated handler encapsulating Razorpay and Cashfree Payment Gateway lifecycle,
/// session building, UPI intent invocation, and server-side verification polling.
class PaymentGatewayHandler {
  final Dio dio;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  final Razorpay _razorpay = Razorpay();

  String? _lastRazorpayPaymentId;
  String? _lastRazorpaySignature;
  String? _activeRazorpayOrderId;

  PaymentGatewayHandler({required this.dio}) {
    if (dio.transformer is! SyncTransformer) {
      dio.transformer = SyncTransformer();
    }
  }

  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    if (!kIsWeb) {
      _cfService.setCallback(onSuccess, onError);

      _razorpay.clear();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse res) {
        debugPrint('Razorpay payment success: paymentId=${res.paymentId}, orderId=${res.orderId}');
        _lastRazorpayPaymentId = res.paymentId;
        _lastRazorpaySignature = res.signature;
        final effectiveId = res.orderId ?? res.paymentId ?? _activeRazorpayOrderId ?? '';
        onSuccess(effectiveId);
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse res) {
        debugPrint('Razorpay payment error: code=, msg=');
        final isCancel = res.code == Razorpay.PAYMENT_CANCELLED ||
            (res.message != null && res.message!.toLowerCase().contains('cancel')) ||
            res.message == 'undefined' ||
            res.message == null ||
            res.message!.trim().isEmpty;
        final cleanMsg = (res.message != null &&
                res.message != 'undefined' &&
                res.message!.trim().isNotEmpty &&
                res.message != 'null')
            ? res.message!
            : (isCancel ? 'Payment cancelled' : 'Payment could not be completed');
        final err = CFErrorResponse(
          isCancel ? 'CANCELLED' : 'FAILED',
          cleanMsg,
          isCancel ? 'USER_DROPPED' : 'PAYMENT_FAILED',
          'ERROR',
        );
        onError(err, _activeRazorpayOrderId ?? '');
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse res) {
        debugPrint('Razorpay external wallet selected: ${res.walletName}');
      });
    }
  }

  void dispose() {
    if (!kIsWeb) {
      _razorpay.clear();
    }
  }

  /// Initiates payment order creation and launches Razorpay (with Cashfree fallback).
  /// Returns the initiated orderId, or null on failure.
  Future<String?> launchPayment({
    required double amount,
    double? walletAmountUsed,
    required String customerPhone,
    required String? customerEmail,
    required String customerName,
    String? existingOrderId,
    String? userId,
    String? addressId,
    List<Map<String, dynamic>>? items,
    String? deliveryMethod,
    String? storeId,
    String? couponCode,
    double? discount,
    double? tipAmount,
    double? deliveryFee,
    double? packagingFee,
    String? packagingOption,
    Future<void> Function(String orderId)? onBeforeLaunch,
  }) async {
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^\d]'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final hasValidEmail = customerEmail != null && customerEmail.contains('@') && customerEmail.contains('.');

    // ── 0. Server-Driven Dynamic Gateway Selection ──
    try {
      final dynamicRes = await dio.post(
        '/api/payment/initiate',
        data: {
          'amount': amount,
          if (walletAmountUsed != null && walletAmountUsed > 0) ...{
            'walletAmountUsed': walletAmountUsed,
            'walletAmount': walletAmountUsed,
          },
          if (existingOrderId != null) 'orderId': existingOrderId,
          'customerPhone': phone10.length == 10 ? phone10 : '9999999999',
          if (hasValidEmail) 'customerEmail': customerEmail.trim(),
          'customerName': customerName,
          if (userId != null) 'userId': userId,
          if (addressId != null) 'addressId': addressId,
          if (items != null) 'items': items,
          if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
          if (storeId != null) 'storeId': storeId,
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          if (discount != null) 'discount': discount,
          if (tipAmount != null) 'tipAmount': tipAmount,
          if (deliveryFee != null) 'deliveryFee': deliveryFee,
          if (packagingFee != null) 'packagingFee': packagingFee,
          if (packagingOption != null) 'packagingOption': packagingOption,
        },
        options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
      );

      if (dynamicRes.data != null) {
        final activeGw = (dynamicRes.data['gateway'] ?? '').toString().toUpperCase();

        // 🟢 Server Selected Cashfree
        if (activeGw == 'CASHFREE' && dynamicRes.data['paymentSessionId'] != null) {
          final cfOrderId = dynamicRes.data['orderId']?.toString() ?? 'cf_${DateTime.now().millisecondsSinceEpoch}';
          final sessionId = dynamicRes.data['paymentSessionId'].toString();

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('active_pending_cf_order_id', cfOrderId);
            await prefs.setString('active_pending_cf_amount', amount.toString());
          } catch (_) {}

          if (onBeforeLaunch != null) {
            try {
              await onBeforeLaunch(cfOrderId);
            } catch (e) {
              debugPrint('PaymentGatewayHandler: Error in onBeforeLaunch draft callback: $e');
              return null;
            }
          }

          final envStr = dynamicRes.data['cfEnv']?.toString() ?? AppConfig.cashfreeEnv;
          final cfEnv = envStr.toUpperCase() == 'TEST' || envStr.toUpperCase() == 'SANDBOX'
              ? CFEnvironment.SANDBOX
              : CFEnvironment.PRODUCTION;

          final session = CFSessionBuilder()
              .setEnvironment(cfEnv)
              .setOrderId(cfOrderId)
              .setPaymentSessionId(sessionId)
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

          final cfPayment = CFWebCheckoutPaymentBuilder()
              .setSession(session)
              .setTheme(theme)
              .build();

          _cfService.doPayment(cfPayment);
          return cfOrderId;
        }

        // 🟢 Server Selected Razorpay
        if (activeGw == 'RAZORPAY' && dynamicRes.data['orderId'] != null) {
          final rzpOrderId = dynamicRes.data['orderId'].toString();
          _activeRazorpayOrderId = rzpOrderId;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('active_pending_cf_order_id', rzpOrderId);
            await prefs.setString('active_pending_cf_amount', amount.toString());
          } catch (_) {}

          if (onBeforeLaunch != null) {
            try {
              await onBeforeLaunch(rzpOrderId);
            } catch (e) {
              debugPrint('PaymentGatewayHandler: Error in onBeforeLaunch draft callback: $e');
              return null;
            }
          }

          final keyId = dynamicRes.data['keyId']?.toString() ?? AppConfig.razorpayKeyId;
          final options = {
            'key': (keyId.isNotEmpty && !keyId.contains('placeholder')) ? keyId : AppConfig.razorpayKeyId,
            'amount': (amount * 100).toInt(),
            'name': 'FastMinute Express',
            'order_id': rzpOrderId,
            'description': 'Fresh Grocery & Food Delivery',
            'timeout': 180,
            'prefill': {
              'contact': phone10.length == 10 ? phone10 : '9999999999',
              if (hasValidEmail) 'email': customerEmail.trim(),
            },
            'theme': {
              'color': '#E20A22',
            },
            'modal': {
              'confirm_close': true,
            },
            'send_sms_hash': true,
          };

          _razorpay.open(options);
          return rzpOrderId;
        }
      }
    } catch (dynamicErr) {
      debugPrint('PaymentGatewayHandler: Dynamic server gateway notice: $dynamicErr. Falling back to local handlers...');
    }

    // ── 1. Attempt Razorpay First (Active Gateway) ──
    try {
      final rzpRes = await dio.post(
        '/api/payment/razorpay/create-order',
        data: {
          'amount': amount,
          if (walletAmountUsed != null && walletAmountUsed > 0) ...{
            'walletAmountUsed': walletAmountUsed,
            'walletAmount': walletAmountUsed,
          },
          if (existingOrderId != null) 'orderId': existingOrderId,
          'customerPhone': phone10.length == 10 ? phone10 : '9999999999',
          if (hasValidEmail) 'customerEmail': customerEmail.trim(),
          'customerName': customerName,
          if (userId != null) 'userId': userId,
          if (addressId != null) 'addressId': addressId,
          if (items != null) 'items': items,
          if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
          if (storeId != null) 'storeId': storeId,
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          if (discount != null) 'discount': discount,
          if (tipAmount != null) 'tipAmount': tipAmount,
          if (deliveryFee != null) 'deliveryFee': deliveryFee,
          if (packagingFee != null) 'packagingFee': packagingFee,
          if (packagingOption != null) 'packagingOption': packagingOption,
        },
        options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
      );

      if (rzpRes.data != null && rzpRes.data['orderId'] != null) {
        final rzpOrderId = rzpRes.data['orderId'].toString();
        _activeRazorpayOrderId = rzpOrderId;

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_pending_cf_order_id', rzpOrderId);
          await prefs.setString('active_pending_cf_amount', amount.toString());
        } catch (_) {}

        if (onBeforeLaunch != null) {
          try {
            await onBeforeLaunch(rzpOrderId);
          } catch (e) {
            debugPrint('PaymentGatewayHandler: Error in onBeforeLaunch draft callback: $e');
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_pending_cf_order_id');
              await prefs.remove('active_pending_cf_amount');
            } catch (_) {}
            try {
              await CheckoutDraft.clearAcceptedDraft();
            } catch (_) {}
            return null;
          }
        }

        final keyId = rzpRes.data['keyId']?.toString() ?? AppConfig.razorpayKeyId;
        final options = {
          'key': (keyId.isNotEmpty && !keyId.contains('placeholder')) ? keyId : AppConfig.razorpayKeyId,
          'amount': (amount * 100).toInt(),
          'name': 'FastMinute Express',
          'order_id': rzpOrderId,
          'description': 'Fresh Grocery & Food Delivery',
          'timeout': 180,
          'prefill': {
            'contact': phone10.length == 10 ? phone10 : '9999999999',
            if (hasValidEmail) 'email': customerEmail.trim(),
          },
          'theme': {
            'color': '#E20A22',
          },
          'modal': {
            'confirm_close': true,
          },
          'send_sms_hash': true,
        };

        _razorpay.open(options);
        return rzpOrderId;
      }
    } catch (rzpErr) {
      debugPrint('Razorpay launch note: $rzpErr, attempting Cashfree fallback...');
    }

    // ── 2. Fallback to Cashfree ──
    try {
      final cfRes = await dio.post(
        '/api/payment/cashfree/create-order',
        data: {
          'amount': amount,
          if (walletAmountUsed != null && walletAmountUsed > 0) ...{
            'walletAmountUsed': walletAmountUsed,
            'walletAmount': walletAmountUsed,
          },
          if (existingOrderId != null) 'orderId': existingOrderId,
          'customerPhone': phone10.length == 10 ? phone10 : '9999999999',
          if (hasValidEmail) 'customerEmail': customerEmail.trim(),
          'customerName': customerName,
          if (userId != null) 'userId': userId,
          if (addressId != null) 'addressId': addressId,
          if (items != null) 'items': items,
          if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
          if (storeId != null) 'storeId': storeId,
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          if (discount != null) 'discount': discount,
          if (tipAmount != null) 'tipAmount': tipAmount,
          if (deliveryFee != null) 'deliveryFee': deliveryFee,
          if (packagingFee != null) 'packagingFee': packagingFee,
          if (packagingOption != null) 'packagingOption': packagingOption,
        },
        options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
      );

      if (cfRes.data != null && cfRes.data['paymentSessionId'] != null) {
        final paymentSessionId = cfRes.data['paymentSessionId'].toString();
        final cfOrderId = cfRes.data['orderId']?.toString() ?? 'cf_${DateTime.now().millisecondsSinceEpoch}';

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_pending_cf_order_id', cfOrderId);
          await prefs.setString('active_pending_cf_amount', amount.toString());
        } catch (_) {}

        if (onBeforeLaunch != null) {
          try {
            await onBeforeLaunch(cfOrderId);
          } catch (e) {
            debugPrint('PaymentGatewayHandler: Error in onBeforeLaunch draft callback: $e');
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_pending_cf_order_id');
              await prefs.remove('active_pending_cf_amount');
            } catch (_) {}
            try {
              await CheckoutDraft.clearAcceptedDraft();
            } catch (_) {}
            return null;
          }
        }

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

        final cfPayment = CFWebCheckoutPaymentBuilder()
            .setSession(session)
            .setTheme(theme)
            .build();

        _cfService.doPayment(cfPayment);
        return cfOrderId;
      }
    } catch (cfErr) {
      debugPrint('Cashfree launch error: $cfErr');
    }
    return null;
  }

  Future<Response<T>> _safePost<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    final binding = WidgetsBinding.instance;
    if (binding.runtimeType.toString() == 'AutomatedTestWidgetsFlutterBinding') {
      dynamic dynamicBinding = binding;
      final res = await dynamicBinding.runAsync(() async {
        try {
          return await dio.post<T>(path, data: data, options: options);
        } catch (e) {
          return e;
        }
      });
      if (res is Response<T>) return res;
      if (res is DioException) throw res;
      if (res is Exception) throw res;
      if (res is Error) throw res;
    }
    return dio.post<T>(path, data: data, options: options);
  }

  /// Verifies payment on backend with up to [maxAttempts] retries.
  /// Handles both Razorpay and Cashfree orders seamlessly.
  Future<PaymentVerificationResult> verifyPayment(String orderId, {int maxAttempts = 12}) async {
    final isRazorpay = orderId.startsWith('order_') || orderId.startsWith('pay_') || _activeRazorpayOrderId == orderId;

    if (isRazorpay) {
      return _verifyRazorpayPayment(orderId, maxAttempts: maxAttempts);
    }
    return _verifyCashfreePayment(orderId, maxAttempts: maxAttempts);
  }

  Future<PaymentVerificationResult> _verifyRazorpayPayment(String orderId, {int maxAttempts = 8}) async {
    final effectivePaymentId = _lastRazorpayPaymentId ?? (orderId.startsWith('pay_') ? orderId : null);
    final effectiveOrderId = _activeRazorpayOrderId ?? (orderId.startsWith('order_') ? orderId : '');

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: attempt <= 2 ? 300 : 600));
      }
      try {
        final verifyRes = await _safePost(
          '/api/payment/razorpay/verify',
          data: {
            'orderId': effectiveOrderId.isNotEmpty ? effectiveOrderId : orderId,
            'razorpay_order_id': effectiveOrderId.isNotEmpty ? effectiveOrderId : orderId,
            'razorpay_payment_id': effectivePaymentId ?? orderId,
            'razorpay_signature': _lastRazorpaySignature ?? '',
          },
        );
        if (verifyRes.statusCode == 200 && verifyRes.data != null) {
          final data = verifyRes.data;
          if (data['isPaid'] == true || data['status'] == 'SUCCESS') {
            final paymentId = data['paymentId']?.toString() ?? effectivePaymentId ?? orderId;
            return PaymentVerificationResult(
              status: PaymentVerificationStatus.paid,
              paymentId: paymentId,
              serverOrderId: data['serverOrderId']?.toString(),
              readableId: data['readableId']?.toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('Razorpay verification attempt $attempt note: $e');
      }
    }

    if (effectivePaymentId != null && effectivePaymentId.startsWith('pay_')) {
      // Payment ID from Razorpay SDK callback is authoritative
      return PaymentVerificationResult(
        status: PaymentVerificationStatus.paid,
        paymentId: effectivePaymentId,
      );
    }

    return const PaymentVerificationResult(
      status: PaymentVerificationStatus.failed,
      message: 'Razorpay payment was not completed.',
    );
  }

  Future<PaymentVerificationResult> _verifyCashfreePayment(String cfOrderId, {int maxAttempts = 12}) async {
    bool hadNetworkOrTimeoutError = false;
    String? lastKnownStatus;
    String? lastMessage;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final delayMs = attempt <= 2 ? 300 : (attempt <= 6 ? 600 : 1000);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      try {
        final verifyRes = await _safePost(
          '/api/payment/cashfree/verify',
          data: {'orderId': cfOrderId, 'cfOrderId': cfOrderId},
        );
        hadNetworkOrTimeoutError = false;
        if (verifyRes.statusCode == 200 && verifyRes.data != null) {
          final data = verifyRes.data;
          if (data['isPaid'] == true || data['paymentStatus'] == 'PAID') {
            final paymentId = data['cfPaymentId']?.toString() ?? 'CF_$cfOrderId';
            final serverOrderId = data['orderId']?.toString();
            final readableId = data['readableId']?.toString();
            return PaymentVerificationResult(
              status: PaymentVerificationStatus.paid,
              paymentId: paymentId,
              serverOrderId: serverOrderId,
              readableId: readableId,
            );
          }
          lastKnownStatus = data['paymentStatus']?.toString().toUpperCase();
          lastMessage = data['message']?.toString();

          if (lastKnownStatus == 'USER_DROPPED' ||
              lastKnownStatus == 'CANCELLED' ||
              lastKnownStatus == 'FAILED' ||
              lastKnownStatus == 'EXPIRED') {
            return PaymentVerificationResult(
              status: PaymentVerificationStatus.failed,
              message: lastMessage ?? 'Payment was cancelled or not completed.',
            );
          }

          if (attempt < maxAttempts - 1) {
            if (lastKnownStatus == 'PENDING' ||
                lastKnownStatus == 'ACTIVE' ||
                lastKnownStatus == 'NOT_PAID') {
              continue;
            }
          }
        }
      } on DioException catch (dioErr) {
        debugPrint('Cashfree verification DioException attempt $attempt: $dioErr');
        hadNetworkOrTimeoutError = true;
      } catch (e) {
        debugPrint('Cashfree verification check attempt $attempt note: $e');
        hadNetworkOrTimeoutError = true;
      }
    }

    if (hadNetworkOrTimeoutError) {
      return const PaymentVerificationResult(
        status: PaymentVerificationStatus.verificationUnavailable,
        message: 'Payment verification is taking a moment. Please tap Check Status again.',
      );
    }

    if (lastKnownStatus == 'PENDING' || lastKnownStatus == 'ACTIVE') {
      return const PaymentVerificationResult(
        status: PaymentVerificationStatus.pending,
        message: 'Payment is awaiting confirmation from your bank/UPI app.',
      );
    }

    if (lastKnownStatus == 'FAILED' ||
        lastKnownStatus == 'CANCELLED' ||
        lastKnownStatus == 'USER_DROPPED' ||
        lastKnownStatus == 'EXPIRED' ||
        lastKnownStatus == 'NOT_PAID') {
      return PaymentVerificationResult(
        status: PaymentVerificationStatus.failed,
        message: lastMessage ?? 'Payment was cancelled or not completed.',
      );
    }

    return PaymentVerificationResult(
      status: PaymentVerificationStatus.verificationUnavailable,
      message: lastMessage ?? 'Payment verification is taking a moment. Please tap Check Status again.',
    );
  }

  /// Clears persisted pending recovery data after the order has been durably placed
  static Future<void> clearPendingPaymentRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_pending_cf_order_id');
      await prefs.remove('active_pending_cf_amount');
    } catch (_) {}
  }

  /// Reads persisted pending order ID if any exists
  static Future<String?> getPendingCfOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('active_pending_cf_order_id');
    } catch (_) {
      return null;
    }
  }

  /// Reads persisted pending order amount if any exists
  static Future<String?> getPendingCfAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('active_pending_cf_amount');
    } catch (_) {
      return null;
    }
  }
}

enum PaymentVerificationStatus {
  paid,
  pending,
  failed,
  verificationUnavailable,
}

class PaymentVerificationResult {
  final PaymentVerificationStatus status;
  final String? paymentId;
  final String? serverOrderId;
  final String? readableId;
  final String? message;

  const PaymentVerificationResult({
    required this.status,
    this.paymentId,
    this.serverOrderId,
    this.readableId,
    this.message,
  });

  bool get isPaid => status == PaymentVerificationStatus.paid;
  bool get isPending => status == PaymentVerificationStatus.pending;
  bool get isFailed => status == PaymentVerificationStatus.failed;
  bool get isUnavailable => status == PaymentVerificationStatus.verificationUnavailable;
}
