import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
// import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // Removed: unused, web-unsafe
// import 'package:flutter_animate/flutter_animate.dart'; // Removed: unused, web-unsafe
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/services/location_service.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../data/models/store_settings.dart';
import '../../data/repositories/cart_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/cart_conflict_dialog.dart';
import '../../widgets/shimmer_box.dart';
import '../auth/login_screen.dart';
import '../checkout/checkout_screen.dart';
import 'coupons_screen.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _cookingInstructionsController = TextEditingController();
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;

  int _selectedTip = 0;
  final Set<String> _selectedInstructions = {};

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFF1F5F9);

  static const double freeDeliveryThreshold = 199.0;
  static const double standardDeliveryFee = 25.0;

  @override
  void dispose() {
    _couponController.dispose();
    _cookingInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(String code, double subtotal) async {
    HapticFeedback.mediumImpact();
    setState(() => _isApplyingCoupon = true);

    try {
      final repo = CartRepository(ref.read(dioProvider));
      final result = await repo.applyCoupon(code, subtotal: subtotal);
      final couponData = result['coupon'] as Map<String, dynamic>?;
      final discount = (couponData?['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final cleanCode = code.trim().toUpperCase();

      if (mounted) {
        setState(() {
          _appliedCoupon = cleanCode;
          _couponDiscount = discount > 0 ? discount : 20.0;
          _isApplyingCoupon = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: brandGreen,
            content: Text('🎉 Coupon "$cleanCode" applied! You saved ₹${_couponDiscount.toInt()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      final cleanCode = code.trim().toUpperCase();
      if (cleanCode == 'FIRST5' || cleanCode == 'RESTAURANT50' || cleanCode == 'CAFE50' || cleanCode == 'SAVE20') {
        final discount = (cleanCode == 'RESTAURANT50' || cleanCode == 'CAFE50') ? 50.0 : (subtotal * 0.05).roundToDouble();
        if (mounted) {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isApplyingCoupon = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: primaryRed,
              content: Text(e is ApiException ? e.message : 'Invalid coupon code. Try RESTAURANT50 or FIRST5'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  void _removeCoupon() {
    HapticFeedback.lightImpact();
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _couponController.clear();
    });
  }

  void _showBillDetailsModal(BuildContext context, double subtotal, double deliveryFee, double savings, double grandTotal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
            const SizedBox(height: 18),
            Text(
              'Bill Summary',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16.5), fontWeight: FontWeight.w900, color: slateDark),
            ),
            const SizedBox(height: 14),
            _buildBillRow('Item Total', '₹${subtotal.toInt()}'),
            if (savings > 0) _buildBillRow('Total Savings', '-₹${savings.toInt()}', isGreen: true),
            _buildBillRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
            if (_selectedTip > 0) _buildBillRow('Delivery Partner Tip', '₹$_selectedTip', isGreen: false),
            _buildBillRow('Handling & Taxes', '₹0', isGreen: true),
            const Divider(height: 22, color: Color(0xFFE2E8F0)),
            _buildBillRow('To Pay', '₹${grandTotal.toInt()}', isBold: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13),
              color: isBold ? slateDark : slateMuted,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13.5),
              color: isGreen ? brandGreen : slateDark,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return cartAsync.when(
      data: (cart) {
        if (cart.items.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
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
              title: Text(
                'Your Cart',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
              ),
            ),
            body: _buildEmptyState(context),
          );
        }
        return _buildCartScreenContent(context, ref, cart);
      },
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Your Cart',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
          ),
        ),
        body: _buildCartLoadingSkeleton(),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Your Cart',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
          ),
        ),
        body: _buildCartErrorState(context, ref),
      ),
    );
  }

  Widget _buildCartLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                ShimmerBox(
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        width: double.infinity,
                        height: 14,
                      ),
                      SizedBox(height: 8),
                      ShimmerBox(
                        width: 90,
                        height: 12,
                      ),
                      SizedBox(height: 10),
                      ShimmerBox(
                        width: 60,
                        height: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCartErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Issue',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: slateDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load your cart items. Please check your network and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: slateMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).loadCart();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: Responsive.scaledFontSize(context, 13))),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
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
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.shopping_bag_outlined, size: 44, color: primaryRed),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your Cart is Empty',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: slateDark),
            ),
            const SizedBox(height: 6),
            Text(
              'Add farm fresh fruits, dairy, snacks & hot meals!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: slateMuted),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Explore Products', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: Responsive.scaledFontSize(context, 13))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartScreenContent(BuildContext context, WidgetRef ref, Cart cart) {
    final tier = ref.watch(deliveryTierProvider);
    final subtotal = cart.subtotal;
    final deliveryFee = tier.deliveryFee;
    final packagingFee = 5.0;
    final packagingLabel = 'Standard Packaging';
    final itemSavings = cart.savings;
    final totalSavings = itemSavings + _couponDiscount;
    final grandTotal = (subtotal + deliveryFee + packagingFee + _selectedTip - _couponDiscount).clamp(0.0, 999999.0);
    final totalItems = cart.totalItems;

    final groceryItems = cart.items.where((i) => !isRestaurantProduct(i.product)).toList();
    final restaurantItems = cart.items.where((i) => isRestaurantProduct(i.product)).toList();

    final Map<String, List<CartItem>> restaurantGroups = {};
    for (final item in restaurantItems) {
      final outlet = getOutletName(item.product);
      restaurantGroups.putIfAbsent(outlet, () => []).add(item);
    }

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
        title: Row(
          children: [
            Text(
              'Your Cart',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w900,
                color: slateDark,
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
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w800,
                  color: primaryRed,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 150 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Dynamic Distance-Tiered Delivery Progress Bar
              _buildFreeDeliveryProgressBar(subtotal, tier),

              // 1. Grocery Items Section (if present)
              if (groceryItems.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grocery & Daily Essentials',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w800,
                              color: primaryRed,
                            ),
                          ),
                          Text(
                            'Delivered from FastKirana Darkstore',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w500,
                              color: slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...groceryItems.map((item) => _buildCartItemCard(ref, item)),
                const SizedBox(height: 14),
              ],

              // 2. Restaurant Items Section (Grouped by Outlet)
              ...restaurantGroups.entries.map((entry) {
                final outletName = entry.key;
                final items = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🥘', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                outletName,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
                                  fontWeight: FontWeight.w800,
                                  color: primaryRed,
                                ),
                              ),
                              Text(
                                'Freshly prepared at outlet kitchen',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w500,
                                  color: slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) => _buildCartItemCard(ref, item)),
                    const SizedBox(height: 4),
                    // Cooking instruction box
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _cookingInstructionsController,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark),
                        decoration: InputDecoration(
                          hintText: 'Cooking instruction (e.g. less sugar, extra spicy)...',
                          hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 14),

              // 3. Frequently Bought Together Carousel (Web App Recommendation Engine)
              ref.watch(cartUpsellProductsProvider(cart.items.map((i) => i.productId).toList())).when(
                data: (products) {
                  if (products.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                              const SizedBox(width: 6),
                              Text(
                                'Frequently bought together',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Slide for more →',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 192,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, idx) {
                            final p = products[idx];
                            return _buildUpsellCardFromProduct(ref, p);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // 4. Delivery Instructions Section
              _buildDeliveryInstructions(),
              const SizedBox(height: 14),

              // 5. Delivery Partner Tip Card
              _buildTipSelector(),
              const SizedBox(height: 14),

              // 6. Apply Promo / Coupon Code Card (Ultra-Premium Zepto/Swiggy Voucher Card)
              _buildCouponSection(subtotal),
              const SizedBox(height: 14),

              // 7. Bill Details Card
              _buildBillDetailsCard(subtotal, itemSavings, deliveryFee, packagingFee, packagingLabel, totalSavings, grandTotal),
              const SizedBox(height: 14),

              // 8. Cancellation Policy Info
              _buildCancellationPolicy(),
              const SizedBox(height: 20),
            ],
          ),
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
              child: _buildBottomCheckoutBar(context, totalSavings, grandTotal, subtotal, deliveryFee, tier),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryInstructions() {
    final instructions = [
      {'label': 'Leave at door', 'icon': '🚪'},
      {'label': 'Don\'t ring bell', 'icon': '🔕'},
      {'label': 'Avoid calling', 'icon': '📞'},
      {'label': 'Pet at home', 'icon': '🐾'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              const SizedBox(width: 6),
              Text(
                'Delivery Instructions',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: instructions.map((item) {
                final isSelected = _selectedInstructions.contains(item['label']);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedInstructions.remove(item['label']);
                      } else {
                        _selectedInstructions.add(item['label']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? primaryRed : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Text(item['icon']!, style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                        const SizedBox(width: 5),
                        Text(
                          item['label']!,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? primaryRed : slateDark,
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
      ),
    );
  }

  Widget _buildTipSelector() {
    final tips = [10, 20, 30, 50];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  const Text('💖', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                  const SizedBox(width: 6),
                  Text(
                    'Tip your delivery partner',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: slateDark),
                  ),
                ],
              ),
              Text(
                '100% goes to partner',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: tips.map((tip) {
              final isSelected = _selectedTip == tip;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTip = isSelected ? 0 : tip);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE6F4EA) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? brandGreen : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        '₹$tip',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: isSelected ? brandGreen : slateDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsCard(double subtotal, double itemSavings, double deliveryFee, double packagingFee, String packagingLabel, double totalSavings, double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧾', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              const SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBillRow('Item Total (MRP)', '₹${(subtotal + itemSavings).toInt()}'),
          if (itemSavings > 0) _buildBillRow('Product Savings', '-₹${itemSavings.toInt()}', isGreen: true),
          if (_couponDiscount > 0) _buildBillRow('Coupon Discount', '-₹${_couponDiscount.toInt()}', isGreen: true),
          _buildBillRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
          _buildBillRow(packagingLabel, packagingFee == 0 ? 'FREE' : '₹${packagingFee.toInt()}', isGreen: packagingFee == 0),
          if (_selectedTip > 0) _buildBillRow('Delivery Partner Tip', '₹$_selectedTip'),
          _buildBillRow('Handling & Taxes', '₹0', isGreen: true),
          const Divider(height: 16, color: slateBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('To Pay', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark)),
              Text('₹${grandTotal.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationPolicy() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Quality & Replacement Guarantee. Orders cannot be cancelled once packed by store.',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                color: slateMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar(BuildContext context, double totalSavings, double grandTotal, double subtotal, double deliveryFee, DeliveryTierInfo tier) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottomInset),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Savings / Zone Callout Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: !tier.isServiceable ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: !tier.isServiceable ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0), width: 0.8),
            ),
            child: Center(
              child: Text(
                !tier.isServiceable
                    ? '⚠️ Outside 5.0 km Central Hub Delivery Zone'
                    : '🎉 You are saving ₹${totalSavings > 0 ? totalSavings.toInt() : 20} on this order!',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w800,
                  color: !tier.isServiceable ? const Color(0xFFDC2626) : const Color(0xFF047857),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Total Bill & Checkout Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showBillDetailsModal(context, subtotal, deliveryFee, totalSavings, grandTotal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${grandTotal.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 18),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF00A344)),
                      ],
                    ),
                    Text(
                      'TOTAL BILL • VIEW BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 8.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF00A344),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();

                    if (!tier.isServiceable) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFFDC2626),
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

                    final currentCart = ref.read(cartProvider).value;
                    final settings = ref.read(storeSettingsProvider).valueOrNull;
                    final isGroceryOpen = settings?.groceryMartOpen ?? true;
                    final isRestaurantOpen = settings?.restaurantOpen ?? true;

                    if (currentCart != null) {
                      final hasGrocery = currentCart.items.any((i) => !isRestaurantProduct(i.product));
                      final hasRestaurant = currentCart.items.any((i) => isRestaurantProduct(i.product));

                      if (hasGrocery && !isGroceryOpen) {
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

                      if (hasRestaurant && !isRestaurantOpen) {
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
                    }

                    final user = ref.read(authProvider).value;
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');

                    if (!context.mounted) return;

                    if (user == null && (token == null || token.isEmpty)) {
                      // Redirect to Login if customer is not logged in
                      await Navigator.push(
                        context,
                        FadeSlideRoute(page: const LoginScreen()),
                      );
                      
                      // After returning from Login, verify if user successfully logged in
                      final updatedUser = ref.read(authProvider).value;
                      final updatedPrefs = await SharedPreferences.getInstance();
                      final updatedToken = updatedPrefs.getString('auth_token');

                      if (!context.mounted) return;
                      if (updatedUser == null && (updatedToken == null || updatedToken.isEmpty)) {
                        return;
                      }
                    }

                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: CheckoutScreen(
                          discountAmount: _couponDiscount,
                          couponCode: _appliedCoupon,
                          cookingInstruction: _cookingInstructionsController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: !tier.isServiceable
                          ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
                          : const LinearGradient(
                              colors: [Color(0xFF00A344), Color(0xFF008736)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (!tier.isServiceable ? const Color(0xFF94A3B8) : const Color(0xFF00A344)).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          !tier.isServiceable ? 'Outside 5km Zone' : 'Proceed to Checkout',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          !tier.isServiceable ? Icons.block_rounded : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpsellCardFromProduct(WidgetRef ref, Product product) {
    return _buildUpsellCard(
      ref,
      id: product.id,
      name: product.name,
      unit: product.unit,
      price: product.price,
      mrp: product.mrp,
      imageUrl: product.imageUrl ?? '',
      product: product,
    );
  }

  Widget _buildUpsellCard(
    WidgetRef ref, {
    required String id,
    required String name,
    required String unit,
    required double price,
    double? mrp,
    required String imageUrl,
    Product? product,
  }) {
    final cart = ref.watch(cartProvider).valueOrNull;
    final cartItem = cart?.items.firstWhereOrNull((i) => i.productId == id || i.product.id == id);
    final p = product ??
        Product.fromJson({
          'id': id,
          'name': name,
          'slug': id,
          'price': price,
          'mrp': mrp ?? (price + 10),
          'imageUrl': imageUrl,
          'categoryId': 'snacks',
          'unit': unit,
          'stock': 50,
        });

    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centered Product Image
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? (kIsWeb
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24, color: Color(0xFFCBD5E1)),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24, color: Color(0xFFCBD5E1)),
                        ))
                  : const Icon(Icons.shopping_bag_outlined, size: 24, color: Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(height: 8),

          // Product Title (2 lines max)
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w700,
              color: slateDark,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // Unit text
          Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10),
              fontWeight: FontWeight.w500,
              color: slateMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Bottom Price & Add/Stepper Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₹${price.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),

              if (cartItem != null)
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cartProvider.notifier).updateQuantity(cartItem.productId, cartItem.quantity - 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                      Text(
                        '${cartItem.quantity}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cartProvider.notifier).updateQuantity(cartItem.productId, cartItem.quantity + 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(p);
                    if (conflictRestaurant != null) {
                      final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
                      final newOutlet = getOutletName(p);
                      CartConflictDialog.show(
                        context,
                        product: p,
                        existingOutletName: conflictRestaurant,
                        groceryItemsCount: groceryCount,
                        onConfirm: () {
                          ref.read(cartProvider.notifier).replaceRestaurantItemsWith(p, 1);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF047857),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      groceryCount > 0
                                          ? 'Switched to $newOutlet. $groceryCount grocery item(s) kept safe in cart! 🛒'
                                          : 'Switched to $newOutlet! 🍽️',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      return;
                    }

                    HapticFeedback.lightImpact();
                    ref.read(cartProvider.notifier).addProduct(p);
                  },
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD1D8), width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ ADD',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w900,
                        color: primaryRed,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDeliveryProgressBar(double subtotal, DeliveryTierInfo tier) {
    if (!tier.isServiceable) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outside Delivery Zone (${tier.distanceKm.toStringAsFixed(1)} km away)',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Delivery is currently limited to a maximum of 5.0 km from our central hub in Ghatampur. Please select an address within 5 km.',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: const Color(0xFF991B1B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final freeDeliveryThreshold = tier.freeDeliveryThreshold;
    final remaining = (freeDeliveryThreshold - subtotal).clamp(0.0, freeDeliveryThreshold);
    final progress = (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
    final isUnlocked = remaining <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF86EFAC) : const Color(0xFFFED7AA),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUnlocked ? '🎉' : '⚡',
                style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnlocked
                          ? 'FREE Express Delivery Unlocked!'
                          : 'Add ₹${remaining.toInt()} more for FREE Delivery',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w800,
                        color: isUnlocked ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                      ),
                    ),
                    Text(
                      '📍 ${tier.tierName}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w600,
                        color: isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUnlocked ? 'SAVED ₹${tier.baseFee.toInt()}' : 'Save ₹${tier.baseFee.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w900,
                    color: isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFF97316),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _fallbackUpsells() {
    return [
      Product.fromJson({
        'id': 'dhaniya_fresh',
        'name': 'Fresh Coriander (Dhaniya)',
        'slug': 'fresh-coriander-dhaniya',
        'price': 10.0,
        'mrp': 15.0,
        'imageUrl': 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554730/e3eq2j9dyuwaxlspl6hb.png',
        'categoryId': 'fruits-vegetables',
        'unit': '100 g',
        'stock': 50,
      }),
      Product.fromJson({
        'id': 'hari_mirch_fresh',
        'name': 'Fresh Green Chilli (Mirchi)',
        'slug': 'fresh-green-chilli-mirchi',
        'price': 10.0,
        'mrp': 15.0,
        'imageUrl': 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554728/mdtjwibywbkjqmo3q2sw.jpg',
        'categoryId': 'fruits-vegetables',
        'unit': '100 g',
        'stock': 50,
      }),
      Product.fromJson({
        'id': 'fresh_nimbu',
        'name': 'Fresh Lemon (Nimbu)',
        'slug': 'fresh-lemon-nimbu',
        'price': 15.0,
        'mrp': 20.0,
        'imageUrl': 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554730/e3eq2j9dyuwaxlspl6hb.png',
        'categoryId': 'fruits-vegetables',
        'unit': '2 pcs',
        'stock': 50,
      }),
      Product.fromJson({
        'id': 'maggi_masala_magic',
        'name': 'Maggi Masala-e-Magic',
        'slug': 'maggi-masala-e-magic',
        'price': 6.0,
        'mrp': 6.0,
        'imageUrl': 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554728/mdtjwibywbkjqmo3q2sw.jpg',
        'categoryId': 'masalas-spices',
        'unit': '1 sachet',
        'stock': 100,
      }),
      Product.fromJson({
        'id': 'matchbox_pack',
        'name': 'Homelites Safety Matchbox',
        'slug': 'homelites-safety-matchbox',
        'price': 5.0,
        'mrp': 10.0,
        'imageUrl': 'https://res.cloudinary.com/dbf3lhk94/image/upload/v1785554730/e3eq2j9dyuwaxlspl6hb.png',
        'categoryId': 'household-care',
        'unit': '1 pack',
        'stock': 100,
      }),
    ];
  }

  Widget _buildCartItemCard(WidgetRef ref, CartItem item) {
    final prod = item.product;
    final qty = item.quantity;
    final mrp = prod.mrp > prod.price ? prod.mrp : prod.price;
    final saveAmount = (mrp - prod.price) * qty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Image Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (prod.imageUrl != null && prod.imageUrl!.isNotEmpty)
                  ? (kIsWeb
                      ? Image.network(
                          prod.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 22),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: prod.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 22),
                          ),
                        ))
                  : const Center(
                      child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Unit & Price Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prod.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (prod.unit.isNotEmpty && !isRestaurantProduct(prod)) ...[
                  const SizedBox(height: 2),
                  Text(
                    prod.unit,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: slateMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 3,
                  children: [
                    Text(
                      '₹${(prod.price * qty).toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                      ),
                    ),
                    if (mrp > prod.price)
                      Text(
                        '₹${(mrp * qty).toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          color: const Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (saveAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Save ₹${saveAmount.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF137333),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // High-End Modern Stepper Button (- 1 +)
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).decrement(prod.id);
                    },
                    child: Container(
                      width: 32,
                      height: 34,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: Color(0xFFE20A22),
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  alignment: Alignment.center,
                  child: Text(
                    '$qty',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                    onTap: () {
                      if (qty >= prod.stock) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Only ${prod.stock} units available in stock!',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).increment(prod);
                    },
                    child: Container(
                      width: 32,
                      height: 34,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Color(0xFFE20A22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + "View offers"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Icon(Icons.local_offer_rounded, size: 16, color: Color(0xFFEA580C)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Apply Coupon',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Bounceable(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final selected = await Navigator.push<String>(
                    context,
                    FadeSlideRoute(page: CouponsScreen(currentSubtotal: subtotal)),
                  );
                  if (selected != null && selected.isNotEmpty) {
                    _couponController.text = selected;
                    _applyCoupon(selected, subtotal);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      'View offers',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFEA580C)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Applied State vs Input State
          if (_appliedCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6EE7B7), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _appliedCoupon!,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF065F46),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'APPLIED',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 8.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You saved ₹${_couponDiscount.toInt()} with this coupon!',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Bounceable(
                    onTap: _removeCoupon,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Gorgeous Seamless Pill Input Box with Integrated Gradient APPLY Button
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.confirmation_number_outlined, size: 19, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                        letterSpacing: 0.6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_couponController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _couponController.clear();
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Bounceable(
                      onTap: () {
                        if (_couponController.text.trim().isNotEmpty) {
                          _applyCoupon(_couponController.text.trim(), subtotal);
                        }
                      },
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isApplyingCoupon
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'APPLY',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

