import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:action_slider/action_slider.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/cart.dart';
import '../../providers/cart_provider.dart';
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
  String _selectedPayment = 'cod';
  int _selectedAddressIndex = 0;
  bool _isPlacingOrder = false;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color successGreen = Color(0xFF10B981);

  final List<Map<String, String>> _addresses = [
    {
      'tag': 'Home',
      'icon': '🏠',
      'name': 'Ghatampur Home',
      'address': 'Ward No. 4, Near Subhash Chowk, Kanpur Road',
      'city': 'Ghatampur, Kanpur Nagar - 209206',
      'phone': '+91 70544 70303',
    },
    {
      'tag': 'Work',
      'icon': '🏢',
      'name': 'Market Office',
      'address': 'Shop #12, Station Road Market',
      'city': 'Ghatampur - 209206',
      'phone': '+91 70544 70303',
    },
  ];

  final List<Map<String, dynamic>> _paymentOptions = [
    {
      'id': 'cod',
      'name': 'Cash on Delivery',
      'desc': 'Pay cash or UPI at doorstep',
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

    await Future.delayed(const Duration(milliseconds: 1200));

    final subtotal = cart.subtotal;
    final deliveryFee = subtotal >= 200 ? 0.0 : 25.0;
    final taxes = 0.0;
    final grandTotal = (subtotal + deliveryFee + taxes - widget.discountAmount).clamp(0.0, 999999.0);

    final selectedAddr = _addresses[_selectedAddressIndex];

    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;
    setState(() => _isPlacingOrder = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          totalAmount: grandTotal,
          deliveryAddress: '${selectedAddr['name']}, ${selectedAddr['address']}',
          paymentMethod: _selectedPayment.toUpperCase(),
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
    final deliveryFee = subtotal >= 200 ? 0.0 : 25.0;
    final taxes = 0.0;
    final grandTotal = (subtotal + deliveryFee + taxes - widget.discountAmount).clamp(0.0, 999999.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Confirm & Pay',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            children: [
              // 1. Delivery ETA Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFFF1F2)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: primaryRed, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Superfast Delivery in 10-15 mins',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                          Text(
                            'Dispatching directly from Ghatampur Hub',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Select Delivery Address
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('📍', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              'Delivery Address',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '+ Add New',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: primaryRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_addresses.length, (idx) {
                      final addr = _addresses[idx];
                      final isSelected = _selectedAddressIndex == idx;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedAddressIndex = idx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primaryRed : const Color(0xFFE5E7EB),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? primaryRed : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(addr['icon']!, style: const TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        Text(
                                          addr['name']!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isSelected ? primaryRed.withOpacity(0.12) : const Color(0xFFE5E7EB),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            addr['tag']!,
                                            style: GoogleFonts.inter(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected ? primaryRed : const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${addr['address']}, ${addr['city']}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addr['phone']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Payment Method Selection
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💳', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          'Select Payment Method',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._paymentOptions.map((method) {
                      final isSelected = _selectedPayment == method['id'];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPayment = method['id'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primaryRed : const Color(0xFFE5E7EB),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? primaryRed : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                method['icon'] as IconData,
                                size: 22,
                                color: isSelected ? primaryRed : const Color(0xFF4B5563),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          method['name'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        if (method['badge'] != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              method['badge'] as String,
                                              style: GoogleFonts.inter(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF15803D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      method['desc'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Order Bill Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Summary',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryRow('Items Total', '₹${subtotal.toInt()}'),
                    if (widget.discountAmount > 0)
                      _buildSummaryRow('Coupon Discount', '-₹${widget.discountAmount.toInt()}', isHighlight: true),
                    _buildSummaryRow(
                      'Delivery Fee',
                      deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}',
                      isHighlight: deliveryFee == 0,
                    ),
                    _buildSummaryRow('Taxes & Packaging', '₹${taxes.toInt()}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grand Total',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '₹${grandTotal.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 5. Sticky Bottom Slide-to-Order Swipe Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ActionSlider.standard(
                height: 54,
                sliderBehavior: SliderBehavior.stretch,
                backgroundColor: const Color(0xFFF3F4F6),
                toggleColor: primaryRed,
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                loadingIcon: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
                successIcon: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                child: Text(
                  'Slide to Place Order · ₹${grandTotal.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF374151),
                    letterSpacing: -0.2,
                  ),
                ),
                action: (controller) async {
                  controller.loading();
                  await _handlePlaceOrder(cart);
                  controller.success();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? successGreen : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}