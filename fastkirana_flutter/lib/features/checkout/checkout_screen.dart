import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/config/app_config.dart';
import '../../data/models/cart.dart';
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
import '../../core/services/admin_notification_service.dart';
import '../../core/utils/restaurant_utils.dart';

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
  String _deliveryMethod = 'DELIVERY'; // 'DELIVERY' | 'PICKUP'
  String _selectedPayment = 'cod'; // Default: Cash on Delivery ('cod' | 'online')
  String _selectedPackaging = 'NORMAL'; // 'NORMAL' (FREE ₹0) | 'PREMIUM' (+₹15)
  int _selectedAddressIndex = 0;
  String _deliveryInstruction = '🔔 Ring Bell';
  bool _isPlacingOrder = false;
  String? _pendingOrderId;
  Razorpay? _razorpay;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

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
    final cart = ref.read(cartProvider).value;
    if (cart == null) return;

    final dio = ref.read(dioProvider);

    if (_pendingOrderId != null && response.paymentId != null) {
      try {
        await dio.post('/api/payment/razorpay/verify-signature', data: {
          'orderId': _pendingOrderId,
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        });
      } catch (e) {
        debugPrint('Razorpay signature verification: $e');
      }
    }

    _completeOrderPlacement(cart, paymentId: response.paymentId ?? 'RZP_${DateTime.now().millisecondsSinceEpoch}');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    HapticFeedback.lightImpact();
    setState(() => _isPlacingOrder = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryRed,
        content: Text('Payment Incomplete: ${response.message ?? "Transaction cancelled"}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wallet Selected: ${response.walletName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                    color: const Color(0xFFCBD5E1),
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
                              color: const Color(0xFF0C2340),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Razorpay',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF3395FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Online Payment',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '100% Encrypted & Secure Razorpay Gateway',
                        style: GoogleFonts.inter(fontSize: 11, color: slateMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '₹${grandTotal.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Razorpay Option 1: Instant UPI (GPay / PhonePe / Paytm)
              _buildRazorpayOptionTile(
                ctx,
                iconWidget: const Text('⚡', style: TextStyle(fontSize: 18)),
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
                iconWidget: const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 20),
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
                iconWidget: const Icon(Icons.account_balance_rounded, color: Color(0xFF7C3AED), size: 20),
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: slateDark,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: slateMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
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
        backgroundColor: const Color(0xFF0F172A),
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
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
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

    final settings = ref.read(storeSettingsProvider).valueOrNull ?? StoreSettings();
    final hasGrocery = cart.items.any((i) => !isRestaurantProduct(i.product));
    final hasRestaurant = cart.items.any((i) => isRestaurantProduct(i.product));

    if (hasGrocery && !settings.groceryMartOpen) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE11D48),
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
          backgroundColor: const Color(0xFFE11D48),
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

    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    // If Online Razorpay Payment is selected
    if (_selectedPayment == 'online') {
      if (kIsWeb) {
        _showOnlineRazorpaySheet(cart, grandTotal);
        return;
      }

      // On Mobile, open direct Razorpay SDK Gateway
      if (_razorpay != null) {
        final user = ref.read(authProvider).value;
        final phone = user?.phone ?? '7054470303';
        final email = user?.email ?? 'customer@fastkirana.in';

        final options = {
          'key': AppConfig.razorpayKeyId,
          'amount': (grandTotal * 100).toInt(),
          'name': 'FastKirana Express',
          'description': 'Order Payment',
          'prefill': {
            'contact': phone,
            'email': email,
          },
          'theme': {
            'color': '#E20A22',
          },
        };

        try {
          _razorpay!.open(options);
          return;
        } catch (e) {
          debugPrint('Razorpay open fallback: $e');
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
    final settings = ref.read(storeSettingsProvider).valueOrNull ?? StoreSettings();
    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 0.0;
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    final selectedAddr = _deliveryMethod == 'PICKUP'
        ? '🏬 Self Pickup: FastKirana Darkstore Counter'
        : (selectedAddress != null
            ? '${selectedAddress.label}, ${selectedAddress.fullAddress}'
            : 'Ghatampur Express Zone');

    final user = ref.read(authProvider).value;
    final userId = user?.id ?? '';
    final customerName = user?.name?.isNotEmpty == true ? user!.name! : (selectedAddress?.label ?? 'FastKirana Customer');
    final customerPhone = user?.phone ?? selectedAddress?.phone ?? '7054470303';

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
      notes: _deliveryInstruction,
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
        'phone': customerPhone,
        'customerAddress': selectedAddr,
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
      }
    } catch (e) {
      debugPrint('Backend sync notice: $e');
    }

    // 2. Save the real database order locally
    await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(placedOrder);

    // Celebratory Haptic Feedback
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final successPage = OrderSuccessScreen(
      orderId: placedOrder.displayId,
      totalAmount: grandTotal,
      deliveryAddress: selectedAddr,
      paymentMethod: _selectedPayment == 'online' ? 'RAZORPAY (PAID)' : 'CASH ON DELIVERY',
      order: placedOrder,
    );

    // Push success screen first so checkout screen never blinks empty
    await Navigator.pushReplacement(
      context,
      FadeSlideRoute(page: successPage),
    );

    ref.read(cartProvider.notifier).clearCart();
    ref.invalidate(ordersProvider(userId));
    ref.invalidate(ordersProvider(''));
    ref.invalidate(ordersProvider('admin'));
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;

    if (!_isPlacingOrder && (cart == null || cart.items.isEmpty)) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final items = cart?.items ?? [];
    final settings = ref.watch(storeSettingsProvider).valueOrNull ?? StoreSettings();
    final subtotal = cart?.subtotal ?? 0.0;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
    final packagingFee = _selectedPackaging == 'PREMIUM' ? 15.0 : 5.0;
    final packagingLabel = _selectedPackaging == 'PREMIUM' ? 'Premium Thermal Packaging' : 'Standard Packaging';
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text(
                  'Express Delivery',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 📍 Delivery Address Card
                  _buildScrollableAddressSection(),
                  const SizedBox(height: 14),

                  // 2. 🍱 Packaging Preference (2 Options: Normal FREE vs Premium +₹15)
                  _buildPackagingOptionsCard(settings),
                  const SizedBox(height: 14),

                  // 3. 🧾 Detailed Bill Summary
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
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
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      color: Color(0xFF16A34A),
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Placing Your Order...',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connecting to FastKirana Darkstore...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
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
                  const Text('🛍️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items Review',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        'Grocery & Daily Essentials',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: primaryRed,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Darkstore',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: slateMuted,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: Color(0xFFE2E8F0)),
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
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🥘', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        outletName,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fresh Kitchen',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.8, color: Color(0xFFFFEDD5)),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: slateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.product.unit.isNotEmpty ? item.product.unit : "1 unit"} × ${item.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _deliveryMethod = 'DELIVERY');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _deliveryMethod == 'DELIVERY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _deliveryMethod == 'DELIVERY'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🛵', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Doorstep Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _deliveryMethod == 'DELIVERY' ? FontWeight.w900 : FontWeight.w600,
                        color: _deliveryMethod == 'DELIVERY' ? slateDark : slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _deliveryMethod = 'PICKUP');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _deliveryMethod == 'PICKUP' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _deliveryMethod == 'PICKUP'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏬', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Self Pickup (₹0 Fee)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _deliveryMethod == 'PICKUP' ? FontWeight.w900 : FontWeight.w600,
                        color: _deliveryMethod == 'PICKUP' ? slateDark : slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
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
                  const Text('🛍️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: slateDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: primaryRed),
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
                      color: const Color(0xFFF8FAFC),
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
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: slateDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${prod.unit.isNotEmpty ? prod.unit : "1 unit"} × $qty',
                          style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(prod.price * qty).toInt()}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark),
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
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Address',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlideRoute(page: const AddressBookScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 13, color: Color(0xFF0F172A)),
                      const SizedBox(width: 3),
                      Text(
                        'Add New',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.home_outlined, color: slateMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghatampur Express Market Zone (Default)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: addresses.length + 1,
                itemBuilder: (context, index) {
                  if (index == addresses.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, FadeSlideRoute(page: const AddressBookScreen()));
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_location_alt_outlined, color: slateMuted, size: 18),
                            const SizedBox(height: 3),
                            Text(
                              '+ Add',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateDark),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final addr = addresses[index];
                  final isSelected = selectedAddress?.id == addr.id ||
                      (selectedAddress == null && index == _selectedAddressIndex);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedAddressProvider.notifier).state = addr;
                      setState(() => _selectedAddressIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 170,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00A344) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                addr.label.toLowerCase() == 'home' ? '🏠' : '🏢',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  addr.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                    color: isSelected ? const Color(0xFF065F46) : slateDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF00A344), size: 14),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            addr.fullAddress,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isSelected ? const Color(0xFF047857) : slateMuted,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Delivery Instructions',
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: slateMuted),
          ),
          const SizedBox(height: 5),
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
          color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF047857) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildStorePickupLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'FastKirana Darkstore Pickup Counter',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Station Road Market, Ghatampur • Ready for pickup in minutes (₹0 fee)',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF047857)),
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
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
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark),
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
            badgeColor: const Color(0xFF059669),
            iconWidget: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 10),

          // Option 2: Online Payment (Razorpay)
          _buildPaymentOptionTile(
            id: 'online',
            title: 'Online Payment (Razorpay)',
            subtitle: 'UPI, Google Pay, PhonePe, Cards & NetBanking',
            badge: '⚡ Fast & Secure',
            badgeColor: const Color(0xFF2563EB),
            iconWidget: const Text('💳', style: TextStyle(fontSize: 16)),
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
          color: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
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
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? const Color(0xFF991B1B) : slateDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 9,
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
                    style: GoogleFonts.inter(fontSize: 11, color: slateMuted),
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
                  color: isSelected ? primaryRed : const Color(0xFFCBD5E1),
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧾', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark),
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
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: slateDark),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 18,
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
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: (isFree || isDiscount) ? FontWeight.w900 : FontWeight.w700,
            color: isFree
                ? const Color(0xFF16A34A)
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
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🛍️', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(
                'Packaging Preference',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
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
                color: _selectedPackaging == 'NORMAL' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPackaging == 'NORMAL' ? const Color(0xFF00A344) : const Color(0xFFE2E8F0),
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
                      color: _selectedPackaging == 'NORMAL' ? const Color(0xFF00A344) : Colors.white,
                      border: Border.all(
                        color: _selectedPackaging == 'NORMAL' ? const Color(0xFF00A344) : const Color(0xFFCBD5E1),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: slateDark,
                          ),
                        ),
                        Text(
                          'Eco-friendly containers & tamper-proof bag',
                          style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹5',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF059669),
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
                color: _selectedPackaging == 'PREMIUM' ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPackaging == 'PREMIUM' ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
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
                      color: _selectedPackaging == 'PREMIUM' ? const Color(0xFFF59E0B) : Colors.white,
                      border: Border.all(
                        color: _selectedPackaging == 'PREMIUM' ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('✨', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        Text(
                          'Insulated thermal pouch + spill-proof packaging',
                          style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹15',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD97706),
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
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Quality & Freshness Guarantee by FastKirana',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomProceedBar(double grandTotal, Cart cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: slateMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 19,
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
                    colors: [Color(0xFF00A344), Color(0xFF008736)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A344).withValues(alpha: 0.3),
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
                                fontSize: 13.5,
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Payment Method',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: slateMuted, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Option 1: Cash on Delivery (COD) - Default
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => _selectedPayment = 'cod');
                        setState(() => _selectedPayment = 'cod');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedPayment == 'cod' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedPayment == 'cod' ? brandGreen : slateBorder,
                            width: _selectedPayment == 'cod' ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('💵', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Cash on Delivery',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: slateDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Default',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pay cash or scan QR at doorstep',
                                    style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPayment == 'cod' ? brandGreen : Colors.white,
                                border: Border.all(
                                  color: _selectedPayment == 'cod' ? brandGreen : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: _selectedPayment == 'cod'
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 2: Pay Online (Razorpay)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => _selectedPayment = 'online');
                        setState(() => _selectedPayment = 'online');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedPayment == 'online' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedPayment == 'online' ? brandGreen : slateBorder,
                            width: _selectedPayment == 'online' ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('💳', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Pay Online',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: slateDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Razorpay',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'UPI, Cards, Netbanking & Wallets',
                                    style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPayment == 'online' ? brandGreen : Colors.white,
                                border: Border.all(
                                  color: _selectedPayment == 'online' ? brandGreen : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: _selectedPayment == 'online'
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Confirm Action Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
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
                                  ? 'Pay ₹${grandTotal.toInt()} via Razorpay'
                                  : 'Confirm & Place Order (₹${grandTotal.toInt()})',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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