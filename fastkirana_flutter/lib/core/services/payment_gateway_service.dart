import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'logger_service.dart';

typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse response);
typedef PaymentFailureCallback = void Function(PaymentFailureResponse response);
typedef ExternalWalletCallback = void Function(ExternalWalletResponse response);

/// Reusable Razorpay Gateway Controller that abstracts native checkout bindings
class PaymentGatewayService {
  Razorpay? _razorpay;
  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onError;
  ExternalWalletCallback? _onWallet;

  bool get isSupported => !kIsWeb;

  /// Initializes the payment gateway listeners
  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onError,
    ExternalWalletCallback? onWallet,
  }) {
    if (!isSupported) return;

    _onSuccess = onSuccess;
    _onError = onError;
    _onWallet = onWallet;

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    LoggerService.info('Razorpay payment success: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handleError(PaymentFailureResponse response) {
    LoggerService.warning('Razorpay payment error: [${response.code}] ${response.message}');
    _onError?.call(response);
  }

  void _handleWallet(ExternalWalletResponse response) {
    LoggerService.info('Razorpay external wallet selected: ${response.walletName}');
    _onWallet?.call(response);
  }

  /// Opens the native Razorpay checkout sheet with the given configuration options
  void openCheckout(Map<String, dynamic> options) {
    if (!isSupported || _razorpay == null) {
      LoggerService.warning('Razorpay is not supported on this platform or not initialized');
      return;
    }
    _razorpay!.open(options);
  }

  /// Cleanly releases listeners and closes native bridges
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _onSuccess = null;
    _onError = null;
    _onWallet = null;
  }
}
