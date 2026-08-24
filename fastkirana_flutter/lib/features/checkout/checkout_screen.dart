import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:action_slider/action_slider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme/design_system.dart';
import '../../core/config/app_config.dart';
import '../../data/models/cart.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../core/network/api_client.dart';
import '../location/delivery_location_screen.dart';
import '../profile/address_book_screen.dart';
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
  // Delivery Method: 'DELIVERY' | 'PICKUP'
  String _deliveryMethod = 'DELIVERY';
  String _selectedPayment = 'cod';
  int _selectedAddressIndex = 0;
  bool _isPlacingOrder = false;
  String? _pendingOrderId;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();
    final cart = ref.read(cartProvider).value;
    if (cart == null) return;

    final dio = ref.read(dioProvider);

    // Verify signature with backend
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
        backgroundColor: Colors.red,
        content: Text('Payment Incomplete: ${response.message ?? "Transaction Cancelled"}. Order saved as Pending.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color successGreen = Color(0xFF10B981);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  final List<Map<String, dynamic>> _paymentOptions = [
    {
      'id': 'cod',
      'name': 'Cash on Delivery / Pay at Counter',
      'desc': 'Pay cash or UPI on handover',
      'icon': Icons.payments_outlined,
      'badge': 'Most Popular',
    },
    {
      'id': 'upi',
      'name': 'UPI Instant (GPay / PhonePe / Paytm)',
      'desc': 'Fast & 100% secure payment',
      'icon': Icons.qr_code_2_rounded,
      'badge': 'Zero Fee',
    },
    {
      'id': 'card',
      'name': 'Credit / Debit Card / Net Banking',
      'desc': 'Visa, MasterCard, RuPay',
      'icon': Icons.credit_card_rounded,
      'badge': null,
    },
  ];

  Future<void> _handlePlaceOrder(Cart cart) async {
    HapticFeedback.heavyImpact();
    setState(() => _isPlacingOrder = true);

    final dio = ref.read(dioProvider);
    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    // 1. Pre-create DB Order in PENDING status FIRST
    try {
      final orderPayload = {
        if (selectedAddress != null && _deliveryMethod == 'DELIVERY') 'addressId': selectedAddress.id,
        'deliveryMethod': _deliveryMethod,
        'paymentMethod': _selectedPayment.toUpperCase(),
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
          _pendingOrderId = orderRes.data[0]['id'];
        } else if (orderRes.data is Map) {
          _pendingOrderId = orderRes.data['id'];
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);

      String errorMsg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          errorMsg = data['detail'].toString();
        } else if (data is Map && data['error'] != null) {
          errorMsg = data['error'].toString();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(errorMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Launch Razorpay if Online Payment
    if (_selectedPayment == 'upi' || _selectedPayment == 'card') {
      final user = ref.read(authProvider).value;
      final phone = user?.phone ?? '7054470303';
      final email = user?.email ?? 'customer@fastkirana.in';

      String? rzpOrderId;
      String keyId = AppConfig.razorpayKeyId;

      if (_pendingOrderId != null) {
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
        } catch (e) {
          debugPrint('Error creating Razorpay order: $e');
        }
      }

      final grandTotal = (cart.subtotal + (_deliveryMethod == 'PICKUP' ? 0.0 : (cart.subtotal >= 199 ? 0.0 : 20.0)) - widget.discountAmount).clamp(0.0, 999999.0);

      final options = {
        'key': keyId,
        'amount': (grandTotal * 100).toInt(),
        'name': 'FastKirana',
        'description': 'Payment for Order',
        if (rzpOrderId != null) 'order_id': rzpOrderId,
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {
          'contact': phone,
          'email': email,
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        await _completeOrderPlacement(cart);
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 1000));
      await _completeOrderPlacement(cart);
    }
  }

  Future<void> _completeOrderPlacement(Cart cart, {String? paymentId}) async {
    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= 199 ? 0.0 : 25.0);
    final taxes = 0.0;
    final grandTotal = (subtotal + deliveryFee + taxes - widget.discountAmount).clamp(0.0, 999999.0);

    final addresses = ref.read(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.read(selectedAddressProvider) ??
        (_selectedAddressIndex < addresses.length ? addresses[_selectedAddressIndex] : null);

    final selectedAddr = _deliveryMethod == 'PICKUP'
        ? '🏬 Self Pickup: Ghatampur Darkstore Counter'
        : (selectedAddress != null
            ? '${selectedAddress.label}, ${selectedAddress.fullAddress}'
            : 'Ghatampur Express Zone');

    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;
    setState(() => _isPlacingOrder = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: _pendingOrderId,
          totalAmount: grandTotal,
          deliveryAddress: selectedAddr,
          paymentMethod: paymentId != null ? 'RAZORPAY ($paymentId)' : _selectedPayment.toUpperCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.value;

    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryMethod == 'PICKUP' ? 0.0 : (subtotal >= 199 ? 0.0 : 25.0);
    final taxes = 0.0;
    final grandTotal = (subtotal + deliveryFee + taxes - widget.discountAmount).clamp(0.0, 999999.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Checkout & Order',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textDark,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Delivery vs Self-Pickup Mode Switcher
            _buildDeliveryMethodSwitcher(),
            const SizedBox(height: 16),

            // 2. Address / Store Pickup Card
            if (_deliveryMethod == 'DELIVERY')
              _buildDeliveryAddressSection()
            else
              _buildStorePickupLocationCard(),
            const SizedBox(height: 16),

            // 3. Payment Method Section
            _buildPaymentMethodSection(),
            const SizedBox(height: 16),

            // 4. Itemized Bill Summary
            _buildBillSummary(subtotal, deliveryFee, taxes, grandTotal),
          ],
        ),
      ),
      bottomSheet: _buildBottomSliderBar(grandTotal, cart),
    );
  }

  // 1. Delivery vs Pickup Toggle
  Widget _buildDeliveryMethodSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
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
                duration: const Duration(milliseconds: 200),
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
                    const Text('🛵', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Doorstep Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _deliveryMethod == 'DELIVERY' ? FontWeight.w800 : FontWeight.w600,
                        color: _deliveryMethod == 'DELIVERY' ? textDark : textMuted,
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
                duration: const Duration(milliseconds: 200),
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
                    const Text('🏬', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Self Pickup (₹0 Fee)',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _deliveryMethod == 'PICKUP' ? FontWeight.w800 : FontWeight.w600,
                        color: _deliveryMethod == 'PICKUP' ? const Color(0xFF047857) : textMuted,
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

  // 2A. Delivery Address Selector
  Widget _buildDeliveryAddressSection() {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: primaryRed, size: 20),
                  const SizedBox(width: 8),
                  Text('Delivery Address', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: textDark)),
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
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 12, color: primaryRed),
                      const SizedBox(width: 2),
                      Text('Add New', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: primaryRed)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (addresses.isEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt_rounded, color: primaryRed, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Delivery Address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: primaryRed)),
                          Text('Save home or office location in Ghatampur', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9F1239))),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: primaryRed),
                  ],
                ),
              ),
            )
          else
            ...addresses.map((addr) {
              final isSelected = selectedAddress?.id == addr.id ||
                  (selectedAddress == null && addresses.indexOf(addr) == _selectedAddressIndex);
              final isHome = addr.label.toLowerCase() == 'home';
              final isWork = addr.label.toLowerCase() == 'work';

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedAddressProvider.notifier).state = addr;
                  setState(() => _selectedAddressIndex = addresses.indexOf(addr));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? primaryRed : const Color(0xFFE5E7EB), width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(isHome ? '🏠' : (isWork ? '🏢' : '📍'), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(addr.label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: textDark)),
                            Text(addr.fullAddress, style: GoogleFonts.inter(fontSize: 11, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: primaryRed, size: 20),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // 2B. Self Pickup Store Counter Card
  Widget _buildStorePickupLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                child: const Text('🏬', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Darkstore Pickup Counter',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
                    ),
                    Text(
                      'Ready for pickup in 5-10 mins (Zero delivery fee)',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFA7F3D0)),
          const SizedBox(height: 8),
          Text(
            '📍 Pickup Location: Ghatampur Hub Store, Station Road Market, Kanpur Nagar - 209206',
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF065F46)),
          ),
          const SizedBox(height: 4),
          Text(
            '📞 Store Helpline: +91 70544 70303 • Open 7:00 AM – 10:00 PM',
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: const Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  // 3. Payment Method Section
  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment_rounded, color: primaryRed, size: 20),
              const SizedBox(width: 8),
              Text('Payment Option', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: textDark)),
            ],
          ),
          const SizedBox(height: 12),
          ..._paymentOptions.map((opt) {
            final isSelected = _selectedPayment == opt['id'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPayment = opt['id']);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryRed : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFEE2E2) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        opt['icon'] as IconData,
                        color: isSelected ? primaryRed : const Color(0xFF4B5563),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  opt['name'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (opt['badge'] != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    opt['badge'] as String,
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
                          const SizedBox(height: 2),
                          Text(
                            opt['desc'] as String,
                            style: GoogleFonts.inter(fontSize: 10.5, color: textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: primaryRed, size: 20)
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 4. Bill Summary
  Widget _buildBillSummary(double subtotal, double deliveryFee, double taxes, double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 12),
          _buildRow('Item Subtotal', '₹${subtotal.toInt()}'),
          if (widget.discountAmount > 0)
            _buildRow('Coupon Savings', '-₹${widget.discountAmount.toInt()}', isGreen: true),
          _buildRow(
            'Delivery Fee',
            _deliveryMethod == 'PICKUP' ? 'FREE (Store Pickup)' : (deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}'),
            isGreen: deliveryFee == 0 || _deliveryMethod == 'PICKUP',
          ),
          _buildRow('Taxes & Packaging', '₹${taxes.toInt()}'),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand Total', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              Text('₹${grandTotal.toInt()}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: primaryRed)),
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
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: textMuted)),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isGreen ? const Color(0xFF16A34A) : textDark)),
        ],
      ),
    );
  }

  // 5. Swipe to Order Action Slider
  Widget _buildBottomSliderBar(double grandTotal, Cart cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: ActionSlider.standard(
        sliderBehavior: SliderBehavior.stretch,
        width: double.infinity,
        height: 54,
        backgroundColor: const Color(0xFFF3F4F6),
        toggleColor: primaryRed,
        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
        child: Text(
          _isPlacingOrder
              ? 'Placing Order...'
              : 'Slide to Place ${_deliveryMethod == 'PICKUP' ? 'Pickup ' : ''}Order (₹${grandTotal.toInt()})',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textDark,
            letterSpacing: -0.2,
          ),
        ),
        action: (controller) async {
          controller.loading();
          await _handlePlaceOrder(cart);
          controller.success();
        },
      ),
    );
  }
}