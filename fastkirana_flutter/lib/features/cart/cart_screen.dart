import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../products/product_detail_screen.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const double freeDeliveryThreshold = 199.0;
  static const double standardDeliveryFee = 25.0;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon(String code, double subtotal) {
    HapticFeedback.mediumImpact();
    setState(() => _isApplyingCoupon = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      final cleanCode = code.trim().toUpperCase();
      if (cleanCode == 'FIRST5' || cleanCode == 'CAFE50' || cleanCode == 'SAVE20') {
        final discount = cleanCode == 'CAFE50' ? 50.0 : (subtotal * 0.05).roundToDouble();
        setState(() {
          _appliedCoupon = cleanCode;
          _couponDiscount = discount;
          _isApplyingCoupon = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: brandGreen,
            content: Text('🎉 Coupon "$cleanCode" applied! You saved ₹${discount.toInt()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isApplyingCoupon = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: primaryRed,
            content: Text('Invalid coupon code. Try CAFE50 or FIRST5'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showBillDetailsModal(BuildContext context, double subtotal, double deliveryFee, double savings, double grandTotal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Bill Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _buildBillRow('Item Total', '₹${subtotal.toInt()}'),
            if (savings > 0) _buildBillRow('Total Savings', '-₹${savings.toInt()}', isGreen: true),
            _buildBillRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
            _buildBillRow('Handling & Taxes', '₹0', isGreen: true),
            const Divider(height: 20),
            _buildBillRow('To Pay', '₹${grandTotal.toInt()}', isBold: true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, color: isGreen ? brandGreen : const Color(0xFF0F172A), fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: cartAsync.when(
          data: (cart) {
            if (cart.items.isEmpty) return _buildEmptyState(context);
            return _buildCartModalContent(context, ref, cart);
          },
          loading: () => const Center(child: CircularProgressIndicator(color: primaryRed)),
          error: (_, __) => _buildEmptyState(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.shopping_bag_outlined, size: 40, color: primaryRed),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Cart is Empty',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Add fresh groceries or hot restaurant meals to begin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Explore Products', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartModalContent(BuildContext context, WidgetRef ref, Cart cart) {
    final subtotal = cart.subtotal;
    final deliveryFee = subtotal >= freeDeliveryThreshold ? 0.0 : standardDeliveryFee;
    final itemSavings = cart.savings;
    final totalSavings = itemSavings + _couponDiscount;
    final grandTotal = (subtotal + deliveryFee - _couponDiscount).clamp(0.0, 999999.0);
    final totalItems = cart.totalItems;

    return Column(
      children: [
        // 1. Top Drawer Drag Pill & Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Column(
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: primaryRed, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Cart',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primaryRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // 2. Scrollable Body
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // Store / Category Subheader
              Row(
                children: [
                  const Text('📦', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grocery & Daily Essentials',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: primaryRed,
                        ),
                      ),
                      Text(
                        'Delivered from FastKirana Darkstore',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cart Items List
              ...cart.items.map((item) {
                final prod = item.product;
                final qty = item.quantity;
                final mrp = prod.mrp > prod.price ? prod.mrp : prod.price;
                final saveAmount = (mrp - prod.price) * qty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Product Image
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (prod.imageUrl != null && prod.imageUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: prod.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 24),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 24),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name & Price Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prod.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '₹${(prod.price * qty).toInt()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (mrp > prod.price) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '₹${(mrp * qty).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (saveAmount > 0) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4EA),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Save ₹${saveAmount.toInt()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF137333),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Stepper Counter (- 1 +)
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 14, color: Color(0xFF64748B)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).decrement(prod.id);
                              },
                            ),
                            Text(
                              '$qty',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 14, color: primaryRed),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).increment(prod);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // 3. Frequently Bought Together Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        'Frequently bought together',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Slide for more →',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Horizontal Mini Cards
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildUpsellCard(
                      ref,
                      id: 'cmqte4wuk000004jmx86hs0pz',
                      name: 'Bikaji Bhelpuri',
                      unit: '110 g',
                      price: 48,
                      imageUrl: 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554730/e3eq2j9dyuwaxlspl6hb.png',
                    ),
                    _buildUpsellCard(
                      ref,
                      id: 'hide_seek_biscuit',
                      name: 'Parle Hide & Seek',
                      unit: '413 g',
                      price: 129,
                      imageUrl: 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554728/mdtjwibywbkjqmo3q2sw.jpg',
                    ),
                    _buildUpsellCard(
                      ref,
                      id: 'cmqum8wtq000604jsdv3omtl5',
                      name: 'Dairy Milk Silk',
                      unit: '52 g',
                      price: 89,
                      imageUrl: 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554792/c0jb8vpco1xn7bvt6kre.jpg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Apply Promo / Coupon Code Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎟️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          'Apply Promo / Coupon Code',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              controller: _couponController,
                              textCapitalization: TextCapitalization.characters,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'ENTER COUPON (E.G. CAFE50)',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (_couponController.text.isNotEmpty) {
                              _applyCoupon(_couponController.text, subtotal);
                            }
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE85B76),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: _isApplyingCoupon
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Apply',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // 5. Savings Pill & Bottom Sticky Checkout Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
            border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Savings Callout Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Center(
                  child: Text(
                    '🎉 You are saving ₹${totalSavings > 0 ? totalSavings.toInt() : 20} on this order!',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Total Bill & Checkout Action Button Row
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BILL',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '₹${grandTotal.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showBillDetailsModal(context, subtotal, deliveryFee, totalSavings, grandTotal),
                        child: Row(
                          children: [
                            Text(
                              'View Bill',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: brandGreen,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: brandGreen),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            discountAmount: _couponDiscount,
                            couponCode: _appliedCoupon,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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
                            'Checkout',
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpsellCard(WidgetRef ref, {required String id, required String name, required String unit, required double price, required String imageUrl}) {
    return Container(
      width: 142,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(unit, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${price.toInt()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final p = Product.fromJson({
                    'id': id,
                    'name': name,
                    'slug': id,
                    'price': price,
                    'mrp': price + 10,
                    'imageUrl': imageUrl,
                    'categoryId': 'snacks',
                    'unit': unit,
                    'stock': 50,
                  });
                  ref.read(cartProvider.notifier).addProduct(p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD1D8)),
                  ),
                  child: Text(
                    '+ Add',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: primaryRed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
