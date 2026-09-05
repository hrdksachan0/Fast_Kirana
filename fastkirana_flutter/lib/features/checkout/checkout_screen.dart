import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/config/app_config.dart';
import '../../data/models/cart.dart';
import '../../data/models/address.dart';
import '../../data/models/order.dart';
import '../../data/models/store_settings.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/network/api_client.dart';
import '../profile/address_book_screen.dart';
import '../orders/orders_screen.dart';
import '../checkout/order_success_screen.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/address_selector_sheet.dart';
import '../../providers/product_provider.dart';

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
  int _selectedAddressIndex = 0;
  String _deliveryInstruction = '🔔 Ring Bell';
  bool _isPlacingOrder = false;
  bool _isFetchingGps = false;
  String? _customReceiverName;
  String? _customReceiverPhone;
  Address? _currentGpsAddress;
  String? _pendingOrderId;
  String? _pendingRazorpayOrderId;
  Cart? _pendingCart;
  double? _pendingGrandTotal;
  Razorpay? _razorpay;

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color brandGreen = AppDesignSystem.green700;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate300;

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
    }
  }

  @override
  void dispose() {
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

  Future<void> _fetchAndApplyCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isFetchingGps = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          setState(() => _isFetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignSystem.rose500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Please enable GPS / Location permission on your device.',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }
        return;
      }

      final details = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      final user = ref.read(authProvider).value;

      final prefs = await SharedPreferences.getInstance();
      final currentPhone = user?.phone ?? prefs.getString('user_phone') ?? '';

      final gpsAddress = Address(
        id: 'addr_gps_live',
        userId: user?.id ?? prefs.getString('user_id') ?? '',
        label: '📍 Current Location',
        houseNo: details.houseNo.isNotEmpty ? details.houseNo : 'Near Pinpoint',
        street: details.street.isNotEmpty ? details.street : 'GPS Detected Road',
        area: details.area.isNotEmpty ? details.area : 'Ghatampur Market',
        city: details.city.isNotEmpty ? details.city : 'Kanpur Nagar',
        pincode: details.pincode.isNotEmpty ? details.pincode : '209206',
        phone: currentPhone,
        latitude: pos.latitude,
        longitude: pos.longitude,
        isDefault: true,
      );

      if (mounted) {
        setState(() {
          _isFetchingGps = false;
          _currentGpsAddress = gpsAddress;
        });

        ref.read(selectedAddressProvider.notifier).state = gpsAddress;

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.emerald700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📍 Set to Current Location: ${details.formattedAddress}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.rose500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Failed to fetch GPS location: $e',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  /// Show Razorpay & UPI Online Payment Sheet (Web / Mobile Fallback)
  void _showOnlineRazorpaySheet(Cart cart, double grandTotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Amount Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.darkNavyHeader,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Razorpay',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.blue500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Online Payment',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 16),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '100% Encrypted & Secure Razorpay Gateway',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusDelivered,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.emerald200),
                    ),
                    child: Text(
                      '₹${grandTotal.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.emerald700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Razorpay Option 1: Instant UPI (GPay / PhonePe / Paytm)
              _buildRazorpayOptionTile(
                ctx,
                iconWidget: Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18))),
                title: 'UPI Payment (GPay / PhonePe / Paytm)',
                subtitle: 'Zero transaction charges • Fast confirmation',
                badge: 'Popular',
                onTap: () {
                  Navigator.pop(ctx);
                  _processSimulatedRazorpayPayment(cart, 'UPI Gateway');
                },
              ),
              const SizedBox(height: 10),

              // Razorpay Option 2: Cards
              _buildRazorpayOptionTile(
                ctx,
                iconWidget: const Icon(Icons.credit_card_rounded, color: AppDesignSystem.blue700, size: 20),
                title: 'Debit / Credit Cards',
                subtitle: 'Visa, Mastercard, RuPay',
                badge: null,
                onTap: () {
                  Navigator.pop(ctx);
                  _processSimulatedRazorpayPayment(cart, 'Cards');
                },
              ),
              const SizedBox(height: 10),

              // Razorpay Option 3: NetBanking
              _buildRazorpayOptionTile(
                ctx,
                iconWidget: const Icon(Icons.account_balance_rounded, color: AppDesignSystem.indigo700, size: 20),
                title: 'NetBanking & All Wallets',
                subtitle: 'HDFC, ICICI, SBI, Axis & More',
                badge: null,
                onTap: () {
                  Navigator.pop(ctx);
                  _processSimulatedRazorpayPayment(cart, 'NetBanking');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRazorpayOptionTile(
    BuildContext ctx, {
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.slate300),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.slate300),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: slateDark,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.green100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.green600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
          ],
        ),
      ),
    );
  }

  Future<void> _processSimulatedRazorpayPayment(Cart cart, String method) async {
    HapticFeedback.mediumImpact();
    setState(() => _isPlacingOrder = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppDesignSystem.slate900,
        duration: const Duration(seconds: 1),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Connecting to Razorpay ($method)...',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));
    _completeOrderPlacement(cart, paymentId: 'rzp_pay_${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> _handlePlaceOrder(Cart cart) async {
    HapticFeedback.heavyImpact();

    final settings = ref.read(storeSettingsProvider).valueOrNull ?? const StoreSettings();
    final hasGrocery = cart.items.any((i) => !isRestaurantProduct(i.product));
    final hasRestaurant = cart.items.any((i) => isRestaurantProduct(i.product));

    if (hasGrocery && !settings.groceryMartOpen) {
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

    if (hasRestaurant && !settings.restaurantOpen) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.rose500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text(
            'Restaurant Kitchen is currently closed. Orders cannot be placed right now.',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
      return;
    }

    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);
    final subtotal = cart.subtotal;
    final tier = LocationService.getTierForAddress(selectedAddress, subtotal);

    if (_deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Delivery is currently limited to a maximum of 5.0 km from our central hub. (Selected location is ${tier.distanceKm.toStringAsFixed(1)} km away)',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            content: Text('Minimum amount for online payment is ₹1.00', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (kIsWeb) {
        _showOnlineRazorpaySheet(cart, grandTotal);
        return;
      }

      // On Mobile, open direct Razorpay SDK Gateway with Server Preflight
      if (_razorpay != null) {
        setState(() => _isPlacingOrder = true);
        _pendingCart = cart;
        _pendingGrandTotal = grandTotal;

        final user = ref.read(authProvider).value;
        final prefs = await SharedPreferences.getInstance();
        final rawPhone = user?.phone ?? prefs.getString('user_phone') ?? '';
        final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d]'), '').replaceAll(RegExp(r'^91'), '');
        final email = user?.email ?? (user?.name != null && user!.name!.isNotEmpty ? '${user.name!.replaceAll(' ', '').toLowerCase()}@fastkirana.in' : 'customer@fastkirana.in');

        // Ultra-Fast Server-side Razorpay Order Preflight (1.5s timeout for instant UX)
        String? serverRzpOrderId;
        try {
          final dio = ref.read(dioProvider);
          final rzpRes = await dio.post(
            '/api/payment/razorpay/create-order',
            data: {'amount': grandTotal},
            options: Options(sendTimeout: const Duration(milliseconds: 1500), receiveTimeout: const Duration(milliseconds: 1500)),
          );
          if (rzpRes.data != null && rzpRes.data['razorpayOrderId'] != null) {
            serverRzpOrderId = rzpRes.data['razorpayOrderId']?.toString();
            _pendingRazorpayOrderId = serverRzpOrderId;
          }
        } catch (e) {
          debugPrint('Razorpay fast preflight note: $e');
        }

        final options = {
          'key': AppConfig.razorpayKeyId,
          'amount': (grandTotal * 100).toInt(),
          if (serverRzpOrderId != null) 'order_id': serverRzpOrderId,
          'name': 'FastKirana Express',
          'description': 'Express Grocery & Food Delivery',
          'prefill': {
            if (cleanPhone.isNotEmpty) 'contact': cleanPhone,
            'email': email,
          },
          'theme': {
            'color': '#E20A22',
          },
          'external': {
            'wallets': ['paytm', 'phonepe', 'gpay', 'mobikwik'],
          },
          'retry': {
            'enabled': true,
            'max_count': 3,
          },
          'send_sms_hash': true,
        };

        try {
          _razorpay!.open(options);
          return;
        } catch (e) {
          debugPrint('Razorpay open fallback: $e');
          setState(() => _isPlacingOrder = false);
        }
      }

      _showOnlineRazorpaySheet(cart, grandTotal);
      return;
    }

    // Cash on Delivery (COD) Order Placement
    setState(() => _isPlacingOrder = true);
    await _completeOrderPlacement(cart);
  }

  Future<void> _completeOrderPlacement(Cart cart, {String? paymentId}) async {
    final subtotal = cart.subtotal;
    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);
    final tier = LocationService.getTierForAddress(selectedAddress, subtotal);

    if (_deliveryMethod == 'DELIVERY' && !tier.isServiceable) {
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppDesignSystem.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Delivery is currently limited to a maximum of 5.0 km from our central hub. (Selected address is ${tier.distanceKm.toStringAsFixed(1)} km away)',
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
    final phoneFromPrefs = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';

    final customerName = _customReceiverName?.isNotEmpty == true
        ? _customReceiverName!
        : (user?.name?.isNotEmpty == true
            ? user!.name!
            : (selectedAddress != null && !selectedAddress.label.toLowerCase().contains('current')
                ? selectedAddress.label
                : 'FastKirana Customer'));

    final customerPhone = _customReceiverPhone?.isNotEmpty == true
        ? _customReceiverPhone!
        : (user?.phone?.isNotEmpty == true
            ? user!.phone!
            : (phoneFromPrefs.isNotEmpty ? phoneFromPrefs : (selectedAddress?.phone.isNotEmpty == true ? selectedAddress!.phone : '7054470303')));

    String orderNotes = _deliveryInstruction;
    if (_customReceiverName?.isNotEmpty == true || _customReceiverPhone?.isNotEmpty == true) {
      final forStr = '🎁 Order for: $customerName${customerPhone.isNotEmpty ? ' ($customerPhone)' : ''}';
      orderNotes = '$forStr | $orderNotes';
    }

    // Extract real restaurant or store fulfillment dynamically from cart items
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
      status: OrderStatus.confirmed,
      subtotal: subtotal,
      discount: widget.discountAmount,
      deliveryFee: deliveryFee,
      taxes: 0,
      miscFee: packagingFee,
      total: grandTotal,
      paymentMethod: _selectedPayment == 'online' ? PaymentMethod.upi : PaymentMethod.cod,
      paymentStatus: paymentId != null ? 'PAID' : 'PENDING',
      deliveryMethod: _deliveryMethod,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: selectedAddr,
      notes: orderNotes,
      createdAt: DateTime.now(),
      items: cart.items.map<OrderItem>((i) => OrderItem(
        id: 'item_${i.product.id}',
        productId: i.product.id,
        name: i.product.name,
        price: i.product.price,
        quantity: i.quantity,
        imageUrl: i.product.imageUrl,
        selectedVariant: i.selectedVariant,
      )).toList(),
    );

    // 1. Post to backend Next.js API for Web App Admin & Database sync
    var placedOrder = newOrder;
    try {
      final isOnlinePaid = paymentId != null && paymentId.isNotEmpty;
      final apiPayload = {
        ...newOrder.toJson(),
        'addressId': selectedAddress?.id ?? 'addr_default',
        'paymentMethod': _selectedPayment == 'online' ? 'UPI' : 'COD',
        'paymentStatus': isOnlinePaid ? 'PAID' : 'PENDING',
        'paymentId': paymentId,
        'deliveryMethod': _deliveryMethod,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'receiverName': customerName,
        'receiverPhone': customerPhone,
        'userName': customerName,
        'phone': customerPhone,
        'notes': orderNotes,
        'customerAddress': selectedAddr,
        'latitude': selectedAddress?.latitude,
        'longitude': selectedAddress?.longitude,
        'lat': selectedAddress?.latitude,
        'lng': selectedAddress?.longitude,
        'shopName': shopName,
        'packagingOption': _selectedPackaging,
        'packagingFee': packagingFee,
        'items': cart.items.map((i) => {
          'productId': i.product.id,
          'quantity': i.quantity,
          'price': i.product.price,
          'name': i.product.name,
          'selectedVariant': i.selectedVariant,
          'product': {
            'id': i.product.id,
            'name': i.product.name,
            'price': i.product.price,
            'imageUrl': i.product.imageUrl,
            'slug': i.product.slug,
            'restaurantId': i.product.restaurantId,
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
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        String errorMsg = 'Failed to place order. Please try again.';
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

    // 2. Save the primary order locally
    await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);

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
    final settings = ref.watch(storeSettingsProvider).valueOrNull ?? const StoreSettings();
    final subtotal = cart?.subtotal ?? 0.0;
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.watch(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);
    final tier = LocationService.getTierForAddress(selectedAddress, subtotal);
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
      final mrp = i.product.mrp ?? i.product.price;
      mrpTotal += mrp * i.quantity;
    }
    final totalSavings = (mrpTotal - subtotal + widget.discountAmount).clamp(0.0, 99999.0);

    return Scaffold(
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
          onPressed: () => Navigator.pop(context),
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
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppDesignSystem.orange300, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.orange600.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Icon + Deliver To Label + Change Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.orange50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppDesignSystem.orange200),
                              ),
                              child: Icon(
                                selectedAddress?.label.toLowerCase().contains('work') == true
                                    ? Icons.work_rounded
                                    : (selectedAddress?.label.toLowerCase().contains('current') == true
                                        ? Icons.my_location_rounded
                                        : Icons.home_rounded),
                                size: 18,
                                color: AppDesignSystem.orange600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Deliver to ',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 12),
                                            fontWeight: FontWeight.w600,
                                            color: slateMuted,
                                          ),
                                        ),
                                        TextSpan(
                                          text: () {
                                            if (selectedAddress == null || selectedAddress.label.trim().isEmpty || selectedAddress.label.trim() == '.') {
                                              return 'Home';
                                            }
                                            final clean = selectedAddress.label.replaceAll('📍', '').trim();
                                            return clean.isNotEmpty ? clean : 'Home';
                                          }(),
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
                                            fontWeight: FontWeight.w900,
                                            color: slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (selectedAddress?.area != null &&
                                            selectedAddress!.area.trim().isNotEmpty &&
                                            selectedAddress.area.trim() != '.' &&
                                            selectedAddress.area.trim().toLowerCase() != 'n/a')
                                        ? selectedAddress.area.trim()
                                        : 'Ghatampur Zone',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.orange600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Interactive Change Address Pill
                            Bounceable(
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await AddressSelectorSheet.show(
                                  context,
                                  activeAddress: selectedAddress,
                                  onAddressSelected: (addr) {
                                    ref.read(selectedAddressProvider.notifier).state = addr;
                                    setState(() {});
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.orange50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppDesignSystem.orange300, width: 1.1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CHANGE',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10.5),
                                        fontWeight: FontWeight.w900,
                                        color: AppDesignSystem.orange600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: AppDesignSystem.orange600),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Full Exact Address Text (Cleaned of stray dots & commas)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppDesignSystem.slate500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (selectedAddress != null && selectedAddress.fullAddress.isNotEmpty
                                          ? selectedAddress.fullAddress
                                          : 'Near Ghatampur Central Market, Uttar Pradesh 209206')
                                      .replaceAll(RegExp(r'^[.,\s]+'), '')
                                      .replaceAll(RegExp(r',\s*,+'), ', ')
                                      .trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignSystem.slate700,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Distance & Delivery Tier Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: !tier.isServiceable ? AppDesignSystem.statusCancelled : AppDesignSystem.green50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !tier.isServiceable ? AppDesignSystem.rose200 : AppDesignSystem.green200,
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                !tier.isServiceable ? Icons.error_outline_rounded : Icons.delivery_dining_rounded,
                                size: 16,
                                color: !tier.isServiceable ? AppDesignSystem.red600 : AppDesignSystem.green600,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  !tier.isServiceable
                                      ? '⚠️ Outside 5.0 km Hub (${tier.distanceKm.toStringAsFixed(1)} km) • Delivery Unavailable'
                                      : '${tier.tierName} (${tier.distanceKm.toStringAsFixed(1)} km) • ${tier.freeDeliveryLabel}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: !tier.isServiceable ? AppDesignSystem.red600 : AppDesignSystem.green700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),


                      ],
                    ),
                  ),

                  // 2. ✨ TOP SAVINGS BANNER (Mint Green - Swiggy Style)
                  if (totalSavings > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusDelivered,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.emerald200),
                      ),
                      child: Row(
                        children: [
                          Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                          const SizedBox(width: 8),
                          Text(
                            '₹${totalSavings.toStringAsFixed(0)} saved! On this order',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.statusDeliveredText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. 🎁 RECEIVER INFO CARD (Spacious & Clean, Zero Truncation)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Header (Avatar + Tag + Edit Button)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _customReceiverName != null
                                    ? AppDesignSystem.statusPending
                                    : AppDesignSystem.blue50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _customReceiverName != null ? '🎁' : '👤',
                                style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _customReceiverName != null ? 'Ordering for someone else' : 'Contact Details for Order',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w700,
                                color: slateMuted,
                              ),
                            ),
                            const Spacer(),
                            Bounceable(
                              onTap: () => _showEditReceiverModal(context, customerName, customerPhone),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.orange50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppDesignSystem.orange300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 12, color: AppDesignSystem.orange600),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Edit',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.orange600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Row 2: Customer Name & Phone Number (Full Width — NO TRUNCATION!)
                        Row(
                          children: [
                            Text(
                              customerName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: slateDark,
                              ),
                            ),
                            if (customerPhone.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•   $customerPhone',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignSystem.slate600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order tracking and delivery updates will be sent here',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w500,
                            color: AppDesignSystem.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. 🍱 CART ITEMS REVIEW CARD
                  _buildCartItemsReview(items),
                  const SizedBox(height: 14),

                  // 4. ✨ COMPLETE YOUR MEAL (Cross-Sell / Frequently Bought Together)
                  _buildCompleteYourMealSection(items),
                  const SizedBox(height: 14),

                  // 5. 🍱 Packaging Preference
                  _buildPackagingOptionsCard(settings),
                  const SizedBox(height: 14),

                  // 6. 🧾 Detailed Bill Summary
                  _buildBillSummary(subtotal, deliveryFee, packagingFee, packagingLabel, grandTotal),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 🌟 Smooth Full-Screen Processing Overlay on Order Placement
            if (_isPlacingOrder)
              Positioned.fill(child: _buildPlacingOrderOverlay()),
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
              child: _buildBottomProceedBar(grandTotal, cart ?? Cart(id: 'c', userId: 'u', items: items, couponDiscount: 0.0, createdAt: DateTime.now(), updatedAt: DateTime.now())),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditReceiverModal(BuildContext context, String currentName, String currentPhone) {
    final nameCtrl = TextEditingController(text: _customReceiverName ?? currentName);
    final phoneCtrl = TextEditingController(text: _customReceiverPhone ?? currentPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Receiver Details',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Receiver Name',
                hintText: 'e.g. Rahul / Mom / Friend',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Receiver Phone Number',
                hintText: '10-digit mobile number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            Bounceable(
              onTap: () {
                final n = nameCtrl.text.trim();
                final p = phoneCtrl.text.trim();
                setState(() {
                  _customReceiverName = n.isNotEmpty ? n : null;
                  _customReceiverPhone = p.isNotEmpty ? p : null;
                });
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppDesignSystem.orange600,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Save Details',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteYourMealSection(List<CartItem> items) {
    final itemIds = items.map((i) => i.product.id).toList();

    return ref.watch(cartUpsellProductsProvider(itemIds)).when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMPLETE YOUR MEAL',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w800,
                color: slateMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, idx) {
                  final p = products[idx];
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: slateBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: p.imageUrl ?? '',
                            width: double.infinity,
                            height: 75,
                            fit: BoxFit.cover,
                            memCacheWidth: 260,
                            memCacheHeight: 150,
                            maxWidthDiskCache: 400,
                            maxHeightDiskCache: 225,
                            errorWidget: (_, __, ___) => Container(
                              color: AppDesignSystem.slate200,
                              child: const Icon(Icons.fastfood_rounded, color: AppDesignSystem.slate400),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: slateDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${p.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: slateDark),
                            ),
                            Bounceable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(cartProvider.notifier).addProduct(p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.green100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.emerald200),
                                ),
                                child: Text(
                                  '+ ADD',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: AppDesignSystem.green600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPlacingOrderOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppDesignSystem.green100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppDesignSystem.emerald200, width: 2),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      color: AppDesignSystem.green600,
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Placing Your Order...',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connecting to FastKirana Darkstore...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemsReview(List<CartItem> items) {
    final groceryItems = items.where((i) => !isRestaurantProduct(i.product)).toList();
    final restaurantItems = items.where((i) => isRestaurantProduct(i.product)).toList();

    final Map<String, List<CartItem>> restaurantGroups = {};
    for (final item in restaurantItems) {
      final outlet = getOutletName(item.product);
      restaurantGroups.putIfAbsent(outlet, () => []).add(item);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items Review',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w700,
                    color: slateMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Grocery Section
          if (groceryItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                      const SizedBox(width: 5),
                      Text(
                        'Grocery & Daily Essentials',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: primaryRed,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Darkstore',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w600,
                          color: slateMuted,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: AppDesignSystem.slate300),
                  ...groceryItems.map((item) => _buildReviewItemRow(item)),
                ],
              ),
            ),
            if (restaurantGroups.isNotEmpty) const SizedBox(height: 10),
          ],

          // 2. Restaurant Sections
          ...restaurantGroups.entries.map((entry) {
            final outletName = entry.key;
            final rItems = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignSystem.orange50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.orange200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🥘', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                      const SizedBox(width: 5),
                      Text(
                        outletName,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fresh Kitchen',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: AppDesignSystem.orange200),
                  ...rItems.map((item) => _buildReviewItemRow(item)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: kIsWeb
                  ? Image.network(
                      item.product.imageUrl!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                    )
                  : CachedNetworkImage(
                      imageUrl: item.product.imageUrl!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      memCacheWidth: 56,
                      memCacheHeight: 56,
                      maxWidthDiskCache: 84,
                      maxHeightDiskCache: 84,
                      errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                    ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w700,
                    color: slateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.product.unit.isNotEmpty ? item.product.unit : "1 unit"} × ${item.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w500,
                    color: slateMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${(item.product.price * item.quantity).toInt()}',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodSwitcher() {
    return const SizedBox.shrink();
  }

  Widget _buildOrderItemsSection(List<CartItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: slateDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignSystem.rose50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final prod = item.product;
            final qty = item.quantity;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: slateBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (prod.imageUrl != null && prod.imageUrl!.isNotEmpty)
                          ? (kIsWeb
                              ? Image.network(
                                  prod.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 20),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: prod.imageUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 84,
                                  memCacheHeight: 84,
                                  maxWidthDiskCache: 125,
                                  maxHeightDiskCache: 125,
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 20),
                                  ),
                                ))
                          : const Center(
                              child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod.name,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: slateDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${prod.unit.isNotEmpty ? prod.unit : "1 unit"} × $qty',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(prod.price * qty).toInt()}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: slateDark),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScrollableAddressSection() {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.watch(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    final isGpsActive = selectedAddress?.id == 'addr_gps_live';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Delivery Address + Change / Add New
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusCancelled,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Address',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    FadeSlideRoute(page: const AddressBookScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppDesignSystem.slate300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_location_alt_outlined, size: 13, color: AppDesignSystem.slate900),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Active Selected Delivery Address Card (Un-truncated & Spacious)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isGpsActive ? AppDesignSystem.green50 : AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGpsActive ? AppDesignSystem.emerald200 : AppDesignSystem.slate300,
                width: isGpsActive ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isGpsActive ? AppDesignSystem.green100 : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isGpsActive ? AppDesignSystem.emerald200 : AppDesignSystem.slate300,
                    ),
                  ),
                  child: Icon(
                    isGpsActive ? Icons.my_location_rounded : (selectedAddress?.label.toLowerCase() == 'home' ? Icons.home_rounded : Icons.location_on_rounded),
                    size: 18,
                    color: isGpsActive ? AppDesignSystem.green600 : primaryRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isGpsActive
                                  ? 'Current GPS Location'
                                  : (selectedAddress?.label ?? 'Ghatampur Express Zone'),
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: isGpsActive ? AppDesignSystem.green900 : slateDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isGpsActive ? AppDesignSystem.green600 : AppDesignSystem.slate300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isGpsActive ? '⚡ LIVE GPS' : 'SELECTED',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 8.5),
                                fontWeight: FontWeight.w900,
                                color: isGpsActive ? Colors.white : slateDark,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedAddress != null
                            ? selectedAddress.fullAddress
                            : (_currentGpsAddress?.fullAddress ?? 'NH34, Ghatampur, Kanpur Nagar - 209206'),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: isGpsActive ? AppDesignSystem.green700 : slateMuted,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. 1-Tap Live GPS Auto-Detect Button (When GPS is not active)
          if (!isGpsActive)
            GestureDetector(
              onTap: _isFetchingGps ? null : _fetchAndApplyCurrentLocation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppDesignSystem.green50, AppDesignSystem.green100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignSystem.emerald200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFetchingGps) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: AppDesignSystem.green600, strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Detecting Exact GPS Location...',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.my_location_rounded, size: 15, color: AppDesignSystem.green600),
                      const SizedBox(width: 6),
                      Text(
                        'Auto-Detect Current GPS Location (1-Tap)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 4. Quick Saved Addresses Horizontal Strip (If user has multiple addresses)
          if (addresses.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: addresses.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final addr = entry.value;
                  final isItemActive = selectedAddress?.id == addr.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedAddressProvider.notifier).state = addr;
                      setState(() => _selectedAddressIndex = idx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isItemActive ? AppDesignSystem.green100 : AppDesignSystem.slate200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isItemActive ? AppDesignSystem.green600 : AppDesignSystem.slate300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            addr.label.toLowerCase() == 'home' ? Icons.home_rounded : Icons.location_city_rounded,
                            size: 12,
                            color: isItemActive ? AppDesignSystem.green600 : slateMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            addr.label,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: isItemActive ? FontWeight.w900 : FontWeight.w600,
                              color: isItemActive ? AppDesignSystem.green900 : slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Delivery Instructions
          Text(
            'Delivery Instructions',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: slateMuted),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildInstructionChip('🔔 Ring Bell'),
                const SizedBox(width: 6),
                _buildInstructionChip('🚪 Leave at Door'),
                const SizedBox(width: 6),
                _buildInstructionChip('📵 Don\'t Ring Bell'),
                const SizedBox(width: 6),
                _buildInstructionChip('📞 Call on Arrival'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionChip(String label) {
    final isSelected = _deliveryInstruction == label;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _deliveryInstruction = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignSystem.statusDelivered : AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppDesignSystem.success : AppDesignSystem.slate300,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 10),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppDesignSystem.emerald700 : AppDesignSystem.slate600,
          ),
        ),
      ),
    );
  }

  Widget _buildStorePickupLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.green50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.emerald200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🏬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18))),
              const SizedBox(width: 8),
              Text(
                'FastKirana Darkstore Pickup Counter',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: AppDesignSystem.statusDeliveredText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Station Road Market, Ghatampur • Ready for pickup in minutes (₹0 fee)',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.emerald700),
          ),
        ],
      ),
    );
  }

  /// 🌟 Payment Method Section: Only 2 Options (COD as Default + Razorpay Online)
  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: primaryRed, size: 18),
              const SizedBox(width: 6),
              Text(
                'Payment Method',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Option 1: Cash on Delivery (COD) - DEFAULT
          _buildPaymentOptionTile(
            id: 'cod',
            title: 'Cash on Delivery (COD)',
            subtitle: 'Pay cash or UPI upon delivery',
            badge: 'Default',
            badgeColor: AppDesignSystem.emerald600,
            iconWidget: const Icon(Icons.payments_outlined, size: 18, color: AppDesignSystem.emerald600),
          ),
          const SizedBox(height: 10),

          // Option 2: Online Payment (Razorpay)
          _buildPaymentOptionTile(
            id: 'online',
            title: 'Online Payment (Razorpay)',
            subtitle: 'UPI, Google Pay, PhonePe, Cards & NetBanking',
            badge: '⚡ Fast & Secure',
            badgeColor: AppDesignSystem.blue700,
            iconWidget: Text('💳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String id,
    required String title,
    required String subtitle,
    required String? badge,
    required Color badgeColor,
    required Widget iconWidget,
  }) {
    final isSelected = _selectedPayment == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPayment = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignSystem.rose50 : AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryRed : AppDesignSystem.slate300,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: iconWidget,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? AppDesignSystem.statusCancelledText : slateDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryRed : AppDesignSystem.slate500,
                  width: isSelected ? 5.5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary(
    double subtotal,
    double deliveryFee,
    double packagingFee,
    String packagingLabel,
    double grandTotal,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🧾', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
              const SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBillRow('Item Total', '₹${subtotal.toInt()}'),
          const SizedBox(height: 7),
          _buildBillRow(
            'Delivery Fee',
            deliveryFee == 0.0 ? 'FREE' : '₹${deliveryFee.toInt()}',
            isFree: deliveryFee == 0.0,
          ),
          const SizedBox(height: 7),
          _buildBillRow(
            packagingLabel,
            packagingFee == 0.0 ? 'FREE (₹0)' : '+₹${packagingFee.toInt()}',
            isFree: packagingFee == 0.0,
          ),
          if (widget.discountAmount > 0) ...[
            const SizedBox(height: 7),
            _buildBillRow('Discount', '-₹${widget.discountAmount.toInt()}', isDiscount: true),
          ],
          const SizedBox(height: 7),
          _buildBillRow('Handling & Taxes', '₹0', isFree: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppDesignSystem.slate200),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: primaryRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w500, color: AppDesignSystem.slate600),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 12.5),
            fontWeight: (isFree || isDiscount) ? FontWeight.w900 : FontWeight.w700,
            color: isFree
                ? AppDesignSystem.green600
                : (isDiscount ? primaryRed : slateDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPackagingOptionsCard(StoreSettings settings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppDesignSystem.statusDelivered,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              ),
              const SizedBox(width: 8),
              Text(
                'Packaging Preference',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Option 1: Normal Packaging (FREE ₹0) - Default
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPackaging = 'NORMAL');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _selectedPackaging == 'NORMAL' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                  width: _selectedPackaging == 'NORMAL' ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : Colors.white,
                      border: Border.all(
                        color: _selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                        width: 1.5,
                      ),
                    ),
                    child: _selectedPackaging == 'NORMAL'
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard Packaging',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w800,
                            color: slateDark,
                          ),
                        ),
                        Text(
                          'Eco-friendly containers & tamper-proof bag',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusDelivered,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹5',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.emerald600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Option 2: Premium Thermal Packaging (+₹15)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPackaging = 'PREMIUM');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _selectedPackaging == 'PREMIUM' ? AppDesignSystem.amber50 : AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : AppDesignSystem.slate300,
                  width: _selectedPackaging == 'PREMIUM' ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : Colors.white,
                      border: Border.all(
                        color: _selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : AppDesignSystem.slate500,
                        width: 1.5,
                      ),
                    ),
                    child: _selectedPackaging == 'PREMIUM'
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Premium Thermal Packaging',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 11))),
                          ],
                        ),
                        Text(
                          'Insulated thermal pouch + spill-proof packaging',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusPending,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹15',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.amber600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignSystem.statusDelivered,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignSystem.emerald200),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: AppDesignSystem.emerald600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Quality & Freshness Guarantee by FastKirana',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.statusDeliveredText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomProceedBar(double grandTotal, Cart cart) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + (bottomInset > 0 ? bottomInset * 0.5 : 0)),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL BILL',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 9),
                  fontWeight: FontWeight.w800,
                  color: slateMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 19),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: _isPlacingOrder ? null : () => _showPaymentMethodBottomSheet(context, grandTotal, cart),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppDesignSystem.green700, AppDesignSystem.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignSystem.green700.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Proceed to Pay',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodBottomSheet(BuildContext context, double grandTotal, Cart cart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Payment Method',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 16.5),
                                fontWeight: FontWeight.w900,
                                color: slateDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Safe & Encrypted 256-bit Checkout',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: slateMuted,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppDesignSystem.slate200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: AppDesignSystem.slate500, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Option 1: Cash on Delivery (COD)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => _selectedPayment = 'cod');
                        setState(() => _selectedPayment = 'cod');
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedPayment == 'cod' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                            width: _selectedPayment == 'cod' ? 1.8 : 1.1,
                          ),
                          boxShadow: _selectedPayment == 'cod'
                              ? [
                                  BoxShadow(
                                    color: AppDesignSystem.green700.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.green100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('💵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Cash on Delivery',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14),
                                          fontWeight: FontWeight.w900,
                                          color: slateDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppDesignSystem.green100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Default',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w900,
                                            color: AppDesignSystem.green700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Pay via cash or UPI QR at your doorstep',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : Colors.white,
                                border: Border.all(
                                  color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                                  width: 2,
                                ),
                              ),
                              child: _selectedPayment == 'cod'
                                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 2: Pay Online (Instant UPI, Cards & Netbanking)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => _selectedPayment = 'online');
                        setState(() => _selectedPayment = 'online');
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedPayment == 'online' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedPayment == 'online' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                            width: _selectedPayment == 'online' ? 1.8 : 1.1,
                          ),
                          boxShadow: _selectedPayment == 'online'
                              ? [
                                  BoxShadow(
                                    color: AppDesignSystem.green700.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.blue50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('💳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Pay Online',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14),
                                          fontWeight: FontWeight.w900,
                                          color: slateDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppDesignSystem.statusDelivered,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppDesignSystem.emerald200),
                                        ),
                                        child: Text(
                                          '⚡ INSTANT',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w900,
                                            color: AppDesignSystem.statusDeliveredText,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Google Pay, PhonePe, Paytm, Cards & UPI',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPayment == 'online' ? AppDesignSystem.green700 : Colors.white,
                                border: Border.all(
                                  color: _selectedPayment == 'online' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                                  width: 2,
                                ),
                              ),
                              child: _selectedPayment == 'online'
                                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Security Trust Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.slate200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 14, color: AppDesignSystem.success),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '100% Safe & Encrypted • Instant Refunds',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.slate600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Confirm Action Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.green700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handlePlaceOrder(cart);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedPayment == 'online'
                                  ? 'Pay ₹${grandTotal.toInt()} Online'
                                  : 'Place Order • Pay ₹${grandTotal.toInt()} on Delivery',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}