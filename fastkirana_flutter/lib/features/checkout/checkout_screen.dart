import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme/design_system.dart';
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
import 'order_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double discountAmount;
  final String? couponCode;

  const CheckoutScreen({
    super.key,
    this.discountAmount = 0.0,
    this.couponCode,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _deliveryMethod = 'DELIVERY'; // 'DELIVERY' | 'PICKUP'
  String _selectedPayment = 'cod';
  int _selectedAddressIndex = 0;
  bool _isPlacingOrder = false;
  String? _pendingOrderId;
  Razorpay? _razorpay;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
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
        debugPrint('Razorpay signature verification error: $e');
      }
    }

    _completeOrderPlacement(cart, paymentId: response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    HapticFeedback.lightImpact();
    setState(() => _isPlacingOrder = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryRed,
        content: Text('Payment Cancelled: ${response.message ?? "Transaction incomplete"}.'),
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

  Future<void> _handlePlaceOrder(Cart cart, {required String paymentMethod}) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPlacingOrder = true;
      _selectedPayment = paymentMethod;
    });

    final dio = ref.read(dioProvider);
    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    final user = ref.read(authProvider).value;
    final phone = user?.phone ?? '7054470303';
    final userName = user?.name ?? 'FastKirana Customer';
    final userId = user?.id;

    try {
      final orderPayload = {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        'phone': phone,
        'userName': userName,
        if (selectedAddress != null && _deliveryMethod == 'DELIVERY') 'addressId': selectedAddress.id,
        'deliveryMethod': _deliveryMethod,
        'paymentMethod': paymentMethod.toUpperCase(),
        'couponCode': widget.couponCode,
        'items': cart.items.map((item) => {
          'productId': item.product.id,
          'product': {
            'id': item.product.id,
            'name': item.product.name,
            'price': item.product.price,
            'slug': item.product.slug,
          },
          'name': item.product.name,
          'price': item.product.price,
          'quantity': item.quantity,
          'selectedVariant': item.selectedVariant,
          'imageUrl': item.product.imageUrl,
        }).toList(),
      };

      final orderRes = await dio.post('/api/orders', data: orderPayload);
      if (orderRes.data != null) {
        if (orderRes.data is List && (orderRes.data as List).isNotEmpty) {
          _pendingOrderId = orderRes.data[0]['readableId']?.toString() ?? orderRes.data[0]['id'];
        } else if (orderRes.data is Map) {
          _pendingOrderId = orderRes.data['readableId']?.toString() ?? orderRes.data['id'];
        }
      }
    } catch (e) {
      debugPrint('Order post error, using fallback ID: $e');
      _pendingOrderId ??= 'FK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    }

    _pendingOrderId ??= 'FK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    if (paymentMethod == 'upi' || paymentMethod == 'card') {
      final user = ref.read(authProvider).value;
      final phone = user?.phone ?? '7054470303';
      final email = user?.email ?? 'customer@fastkirana.in';

      String? rzpOrderId;
      String keyId = AppConfig.razorpayKeyId;

      try {
        final rzpRes = await dio.post('/api/payment/razorpay/create-order', data: {
          'orderId': _pendingOrderId,
        });
        if (rzpRes.data != null && rzpRes.data is Map) {
          rzpOrderId = rzpRes.data['razorpayOrderId'];
          if (rzpRes.data['keyId'] != null) {
            keyId = rzpRes.data['keyId'];
          }
        }
      } catch (_) {}

      final settings = ref.read(storeSettingsProvider).valueOrNull ?? StoreSettings();
      final subtotal = cart.subtotal;
      final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
      final packagingFee = settings.miscFee;
      final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);
      final amountInPaise = (grandTotal * 100).toInt();

      final options = {
        'key': keyId,
        'amount': amountInPaise,
        'name': 'FastKirana Express',
        'description': 'Order #$_pendingOrderId',
        'order_id': rzpOrderId,
        'prefill': {
          'contact': phone,
          'email': email,
        },
        'theme': {
          'color': '#E20A22',
        },
      };

      if (kIsWeb) {
        try {
          final optionsJson = jsonEncode(options);
          js.context.callMethod('eval', ["""
            (function() {
              window.onRazorpaySuccess = function(paymentId, orderId, signature) {
                window.dispatchEvent(new CustomEvent('razorpay_payment_success', {
                  detail: { paymentId: paymentId, orderId: orderId, signature: signature }
                }));
              };
              window.onRazorpayDismiss = function(err) {
                window.dispatchEvent(new CustomEvent('razorpay_payment_dismissed', { detail: { error: err } }));
              };

              function openRzp() {
                try {
                  var opts = $optionsJson;
                  opts.handler = function(response) {
                    if (window.onRazorpaySuccess) {
                      window.onRazorpaySuccess(response.razorpay_payment_id, response.razorpay_order_id, response.razorpay_signature);
                    }
                  };
                  opts.modal = {
                    ondismiss: function() {
                      if (window.onRazorpayDismiss) {
                        window.onRazorpayDismiss("Payment cancelled by user");
                      }
                    }
                  };
                  var rzp = new Razorpay(opts);
                  rzp.open();
                } catch(e) {
                  if (window.onRazorpayDismiss) {
                    window.onRazorpayDismiss(e.message || e.toString());
                  }
                }
              }

              if (typeof Razorpay === 'undefined') {
                var s = document.createElement('script');
                s.src = 'https://checkout.razorpay.com/v1/checkout.js';
                s.onload = openRzp;
                document.head.appendChild(s);
              } else {
                openRzp();
              }
            })();
          """]);
        } catch (e) {
          debugPrint('Web Razorpay error: $e');
        }
      } else {
        try {
          _razorpay?.open(options);
        } catch (_) {}
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      await _completeOrderPlacement(cart);
    }
  }

  Future<void> _completeOrderPlacement(Cart cart, {String? paymentId}) async {
    final settings = ref.read(storeSettingsProvider).valueOrNull ?? StoreSettings();
    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
    final packagingFee = settings.miscFee;
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

    final newOrder = Order(
      id: _pendingOrderId ?? 'FK-${DateTime.now().millisecondsSinceEpoch}',
      readableId: _pendingOrderId,
      userId: userId,
      addressId: selectedAddress?.id ?? 'addr_default',
      status: OrderStatus.confirmed,
      subtotal: subtotal,
      discount: widget.discountAmount,
      deliveryFee: deliveryFee,
      taxes: 0,
      miscFee: packagingFee,
      total: grandTotal,
      paymentMethod: _selectedPayment == 'upi' ? PaymentMethod.upi : (_selectedPayment == 'card' ? PaymentMethod.card : PaymentMethod.cod),
      paymentStatus: paymentId != null ? 'PAID' : 'PENDING',
      deliveryMethod: _deliveryMethod,
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

    try {
      await OrderRepository(ref.read(dioProvider)).savePlacedOrderLocally(newOrder);
    } catch (_) {}

    ref.read(cartProvider.notifier).clearCart();
    ref.invalidate(ordersProvider(userId));
    if (userId.isEmpty) {
      ref.invalidate(ordersProvider(''));
    }

    if (!mounted) return;
    setState(() => _isPlacingOrder = false);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => OrderSuccessScreen(
          orderId: _pendingOrderId,
          totalAmount: grandTotal,
          deliveryAddress: selectedAddr,
          paymentMethod: paymentId != null ? 'RAZORPAY ($paymentId)' : _selectedPayment.toUpperCase(),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;

    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final settings = ref.watch(storeSettingsProvider).valueOrNull ?? StoreSettings();
    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= settings.freeDeliveryThreshold ? 0.0 : settings.deliveryFee);
    final packagingFee = settings.miscFee;
    final packagingLabel = settings.miscFeeLabel;
    final grandTotal = (subtotal + deliveryFee + packagingFee - widget.discountAmount).clamp(0.0, 999999.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout',
              style: GoogleFonts.inter(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '⚡ Fast Delivery in 10-15 mins',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDeliveryMethodSwitcher(),
            const SizedBox(height: 14),
            if (_deliveryMethod == 'DELIVERY')
              _buildScrollableAddressSection()
            else
              _buildStorePickupLocationCard(),
            const SizedBox(height: 14),
            _buildOrderItemsPreview(cart),
            const SizedBox(height: 14),
            _buildBillSummary(subtotal, deliveryFee, packagingFee, packagingLabel, grandTotal),
            const SizedBox(height: 14),
            _buildGuaranteeBanner(),
          ],
        ),
      ),
      bottomSheet: _buildBottomProceedBar(grandTotal, cart),
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _deliveryMethod == 'DELIVERY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _deliveryMethod == 'DELIVERY'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _deliveryMethod == 'PICKUP' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _deliveryMethod == 'PICKUP'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]
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
                        color: _deliveryMethod == 'PICKUP' ? const Color(0xFF047857) : slateMuted,
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

  Widget _buildScrollableAddressSection() {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                  const Icon(Icons.location_on_rounded, color: primaryRed, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Delivery Address',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: slateDark),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 12, color: primaryRed),
                      const SizedBox(width: 2),
                      Text(
                        'Add New',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: primaryRed),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, color: slateMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghatampur Express Market Zone',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 82,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: addresses.length + 1,
                itemBuilder: (context, index) {
                  if (index == addresses.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen()));
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_location_alt_outlined, color: primaryRed, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              '+ Add',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: primaryRed),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                addr.label.toLowerCase() == 'home' ? '🏠' : '🏢',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  addr.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                    color: isSelected ? const Color(0xFF991B1B) : slateDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: primaryRed, size: 14),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            addr.fullAddress,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isSelected ? const Color(0xFFB91C1C).withOpacity(0.8) : slateMuted,
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
        ],
      ),
    );
  }

  Widget _buildStorePickupLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
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
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Station Road Market, Ghatampur • Ready in 5-10 mins (₹0 fee)',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsPreview(Cart cart) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🛍️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    'Order Items (${cart.totalItems})',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Edit Cart',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cart.items.length,
              itemBuilder: (context, idx) {
                final item = cart.items[idx];
                final p = item.product;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: p.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                                )
                              : const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: slateDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.quantity}x • ₹${(p.price * item.quantity).toInt()}',
                            style: GoogleFonts.inter(fontSize: 9.5, color: slateMuted),
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
      ),
    );
  }

  Widget _buildBillSummary(double subtotal, double deliveryFee, double packagingFee, String packagingLabel, double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧾', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRow('Item Total', '₹${subtotal.toInt()}'),
          if (widget.discountAmount > 0)
            _buildRow('Coupon Savings', '-₹${widget.discountAmount.toInt()}', isGreen: true),
          _buildRow(
            'Delivery Fee',
            _deliveryMethod == 'PICKUP' ? 'FREE (Store Pickup)' : (deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}'),
            isGreen: deliveryFee == 0 || _deliveryMethod == 'PICKUP',
          ),
          _buildRow(
            packagingLabel,
            packagingFee == 0 ? 'FREE' : '₹${packagingFee.toInt()}',
            isGreen: packagingFee == 0,
          ),
          _buildRow('Handling & Taxes', '₹0', isGreen: true),
          const Divider(height: 18, color: slateBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('To Pay', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark)),
              Text('₹${grandTotal.toInt()}', style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w900, color: slateDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String val, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: slateMuted, fontWeight: FontWeight.w500)),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isGreen ? brandGreen : slateDark)),
        ],
      ),
    );
  }

  Widget _buildGuaranteeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Quality & Freshness Guarantee by FastKirana',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomProceedBar(double grandTotal, Cart cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: slateBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL BILL',
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: slateMuted, letterSpacing: 0.5),
                ),
                Text(
                  '₹${grandTotal.toInt()}',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: slateDark),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _isPlacingOrder
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _showPaymentOptionsModal(context, grandTotal, cart);
                    },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A344), Color(0xFF008F3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: brandGreen.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Proceed to Pay',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentOptionsModal(BuildContext context, double grandTotal, Cart cart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: primaryRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Option',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: slateMuted, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildModalPaymentTile(
                      ctx: ctx,
                      id: 'cod',
                      title: 'Cash on Delivery / Pay at Counter',
                      subtitle: 'Pay cash or UPI on handover',
                      badge: 'Most Popular',
                      icon: Icons.payments_outlined,
                      cart: cart,
                    ),
                    _buildModalPaymentTile(
                      ctx: ctx,
                      id: 'upi',
                      title: 'UPI Instant (GPay / PhonePe / Paytm)',
                      subtitle: 'Fast & 100% secure payment',
                      badge: 'Zero Fee',
                      icon: Icons.qr_code_2_rounded,
                      cart: cart,
                    ),
                    _buildModalPaymentTile(
                      ctx: ctx,
                      id: 'card',
                      title: 'Credit / Debit Card / Net Banking',
                      subtitle: 'Visa, MasterCard, RuPay',
                      badge: null,
                      icon: Icons.credit_card_rounded,
                      cart: cart,
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

  Widget _buildModalPaymentTile({
    required BuildContext ctx,
    required String id,
    required String title,
    required String subtitle,
    required String? badge,
    required IconData icon,
    required Cart cart,
  }) {
    final isSelected = _selectedPayment == id;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        Navigator.pop(ctx);
        await _handlePlaceOrder(cart, paymentMethod: id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFE4E6) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? primaryRed : const Color(0xFF64748B), size: 20),
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
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? const Color(0xFF991B1B) : slateDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}