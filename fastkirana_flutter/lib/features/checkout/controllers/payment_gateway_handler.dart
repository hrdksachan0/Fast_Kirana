import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../data/models/checkout_draft.dart';

typedef PaymentSuccessCallback = void Function(String cfOrderId);
typedef PaymentErrorCallback = void Function(CFErrorResponse errorResponse, String cfOrderId);

/// Dedicated handler encapsulating Cashfree Payment Gateway lifecycle,
/// session building, UPI intent invocation, and server-side verification polling.
class PaymentGatewayHandler {
  final Dio dio;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();

  PaymentGatewayHandler({required this.dio});

  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    if (!kIsWeb) {
      _cfService.setCallback(onSuccess, onError);
    }
  }

  /// Initiates Cashfree payment order creation and launches intent or web checkout.
  /// Returns the initiated Cashfree orderId, or null on failure.
  Future<String?> launchPayment({
    required double amount,
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
    Future<void> Function(String cfOrderId)? onBeforeLaunch,
  }) async {
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^\d]'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final hasValidEmail = customerEmail != null && customerEmail.contains('@') && customerEmail.contains('.');

    try {
      final cfRes = await dio.post(
        '/api/payment/cashfree/create-order',
        data: {
          'amount': amount,
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

        // Persist pending attempt before launching external SDK
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_pending_cf_order_id', cfOrderId);
          await prefs.setString('active_pending_cf_amount', amount.toString());
        } catch (_) {}

        // Durably record accepted draft before launching external payment SDK
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

        // 1. Direct UPI Intent
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
          return cfOrderId;
        } catch (upiErr) {
          debugPrint('Cashfree UPI Intent error, using WebCheckout fallback: $upiErr');
        }

        // 2. Web Checkout fallback
        if (!upiLaunched) {
          final cfPayment = CFWebCheckoutPaymentBuilder()
              .setSession(session)
              .setTheme(theme)
              .build();

          _cfService.doPayment(cfPayment);
          return cfOrderId;
        }
      }
    } catch (cfErr) {
      debugPrint('Cashfree launch error: $cfErr');
    }
    return null;
  }

  /// Verifies payment on backend with up to [maxAttempts] retries
  Future<PaymentVerificationResult> verifyPayment(String cfOrderId, {int maxAttempts = 3}) async {
    bool hadNetworkOrTimeoutError = false;
    String? lastKnownStatus;
    String? lastMessage;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      try {
        final verifyRes = await dio.post(
          '/api/payment/cashfree/verify',
          data: {'orderId': cfOrderId, 'cfOrderId': cfOrderId},
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        hadNetworkOrTimeoutError = false;
        if (verifyRes.statusCode == 200 && verifyRes.data != null) {
          final data = verifyRes.data;
          if (data['isPaid'] == true || data['paymentStatus'] == 'PAID') {
            final paymentId = data['cfPaymentId']?.toString() ?? 'CF_$cfOrderId';
            // Do NOT clear active_pending_cf_order_id here; keep recovery intact until backend order placement ACK
            return PaymentVerificationResult(
              status: PaymentVerificationStatus.paid,
              paymentId: paymentId,
            );
          }
          lastKnownStatus = data['paymentStatus']?.toString().toUpperCase();
          lastMessage = data['message']?.toString();

          if (lastKnownStatus == 'FAILED' ||
              lastKnownStatus == 'CANCELLED' ||
              lastKnownStatus == 'USER_DROPPED' ||
              lastKnownStatus == 'EXPIRED' ||
              lastKnownStatus == 'NOT_PAID' ||
              lastKnownStatus == 'ACTIVE') {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_pending_cf_order_id');
              await prefs.remove('active_pending_cf_amount');
            } catch (_) {}
            return PaymentVerificationResult(
              status: PaymentVerificationStatus.failed,
              message: lastMessage ?? 'Payment was cancelled or not completed.',
            );
          }

          if (lastKnownStatus == 'PENDING') {
            // Still in flight with bank/UPI, continue polling attempts
            continue;
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

    if (lastKnownStatus == 'PENDING') {
      return const PaymentVerificationResult(
        status: PaymentVerificationStatus.pending,
        message: 'Payment is awaiting confirmation from your bank/UPI app.',
      );
    }

    return PaymentVerificationResult(
      status: PaymentVerificationStatus.failed,
      message: lastMessage ?? 'Payment was not completed.',
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

  /// Reads persisted pending Cashfree order ID if any exists
  static Future<String?> getPendingCfOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('active_pending_cf_order_id');
    } catch (_) {
      return null;
    }
  }

  /// Reads persisted pending Cashfree order amount if any exists
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
  final String? message;

  const PaymentVerificationResult({
    required this.status,
    this.paymentId,
    this.message,
  });

  bool get isPaid => status == PaymentVerificationStatus.paid;
  bool get isPending => status == PaymentVerificationStatus.pending;
  bool get isFailed => status == PaymentVerificationStatus.failed;
  bool get isUnavailable => status == PaymentVerificationStatus.verificationUnavailable;
}
