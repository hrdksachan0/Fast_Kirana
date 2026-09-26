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
import '../../../core/config/app_config.dart';

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
        },
        options: Options(sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)),
      );

      if (cfRes.data != null && cfRes.data['paymentSessionId'] != null) {
        final paymentSessionId = cfRes.data['paymentSessionId'].toString();
        final cfOrderId = cfRes.data['orderId']?.toString() ?? 'cf_${DateTime.now().millisecondsSinceEpoch}';

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
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
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
            final paymentId = data['cfPaymentId']?.toString() ?? 'CF_$cfOrderId';
            return PaymentVerificationResult(isPaid: true, paymentId: paymentId);
          }
        }
      } catch (e) {
        debugPrint('Cashfree verification check attempt $attempt note: $e');
      }
    }
    return const PaymentVerificationResult(isPaid: false);
  }
}

class PaymentVerificationResult {
  final bool isPaid;
  final String? paymentId;

  const PaymentVerificationResult({required this.isPaid, this.paymentId});
}
