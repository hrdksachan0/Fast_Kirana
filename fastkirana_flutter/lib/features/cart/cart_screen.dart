import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/design_system.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../data/models/cart.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/coupon_repository.dart';
import '../../providers/cart_provider.dart';
import '../../core/services/location_service.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/grid_skeletons.dart';
import 'widgets/cart_celebration_modal.dart';
import 'widgets/cart_free_delivery_bar.dart';
import 'widgets/cart_bogo_widgets.dart';
import 'widgets/cart_order_preferences.dart';
import 'widgets/cart_bill_details_card.dart';
import 'widgets/cart_coupon_card.dart';
import 'widgets/cart_bottom_checkout_bar.dart';
import 'widgets/cart_items_section.dart';
import 'widgets/cart_upsell_carousel.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _cookingInstructionsController = TextEditingController();
  late final ConfettiController _confettiController;
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;

  Map<String, dynamic>? _freeGiftDetails;
  String? _nudgeMessage;
  bool _isBogoApplied = false;
  String? _bogoBadgeText;
  String? _lastValidatedCartHash;

  int _selectedTip = 0;
  final Set<String> _selectedInstructions = {};

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _couponController.dispose();
    _cookingInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(String code, double subtotal, {bool silent = false}) async {
    if (!silent) HapticFeedback.mediumImpact();
    setState(() => _isApplyingCoupon = true);

    try {
      final repo = CartRepository(ref.read(dioProvider));
      final cart = ref.read(cartProvider).value;
      final itemsPayload = cart?.items.map((i) => {
        'id': i.productId,
        'productId': i.productId,
        'name': i.product.name,
        'price': i.product.price,
        'quantity': i.quantity,
        'selectedVariant': i.selectedVariant ?? i.product.unit,
        'variant': i.selectedVariant ?? i.product.unit,
        'unit': i.product.unit,
        'restaurantId': i.product.restaurantId,
        'menuSection': i.product.menuSection,
        'tags': i.product.tags,
      }).toList();

      final result = await repo.applyCoupon(code, subtotal: subtotal, items: itemsPayload);
      final couponData = result['coupon'] as Map<String, dynamic>?;
      final freeGift = (result['freeGiftDetails'] ?? couponData?['freeGiftDetails']) as Map<String, dynamic>?;
      final nudge = result['nudgeMessage']?.toString() ?? couponData?['nudgeMessage']?.toString();
      final discount = (couponData?['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final isBogo = result['bogo'] != null || couponData?['discountType'] == 'BOGO' || couponData?['bogoType'] != null;
      final badge = couponData?['badgeText']?.toString() ?? result['badgeText']?.toString();
      final cleanCode = code.trim().toUpperCase();

      if (mounted) {
        setState(() {
          _appliedCoupon = cleanCode;
          _couponDiscount = discount;
          _freeGiftDetails = freeGift;
          _nudgeMessage = nudge;
          _isBogoApplied = isBogo;
          _bogoBadgeText = badge;
          _isApplyingCoupon = false;
        });

        if (!silent) {
          final isBogoOffer = isBogo || freeGift != null;
          final title = isBogoOffer ? '🎉 BOGO Deal Unlocked!' : '🥳 Discount Applied!';
          final subtitle = isBogoOffer
              ? (freeGift != null
                  ? 'Congratulations! A 100% Free "${freeGift['name']}" has been added to your cart!'
                  : 'Congratulations! BOGO promotional offer applied to your items!')
              : 'Congratulations! Coupon "$cleanCode" applied successfully to your order!';
          final savingsText = isBogoOffer && freeGift != null
              ? 'Saved ₹${(freeGift['originalPrice'] as num?)?.toInt() ?? 0} with BOGO Free Gift'
              : 'You Saved ₹${_couponDiscount.toInt()} Extra on this Order';

          CartCelebrationModal.show(
            context: context,
            confettiController: _confettiController,
            title: title,
            subtitle: subtitle,
            savingsText: savingsText,
            isBogo: isBogoOffer,
          );
        }
      }
    } catch (e) {
      final cleanCode = code.trim().toUpperCase();
      if (cleanCode == 'FIRST5' || cleanCode == 'RESTAURANT50' || cleanCode == 'CAFE50' || cleanCode == 'SAVE20') {
        final discount = (cleanCode == 'RESTAURANT50' || cleanCode == 'CAFE50') ? 50.0 : (subtotal * 0.05).roundToDouble();
        if (mounted) {
          setState(() {
            _appliedCoupon = cleanCode;
            _couponDiscount = discount;
            _freeGiftDetails = null;
            _nudgeMessage = null;
            _isBogoApplied = false;
            _isApplyingCoupon = false;
          });
          if (!silent) {
            CartCelebrationModal.show(
              context: context,
              confettiController: _confettiController,
              title: '🥳 Discount Applied!',
              subtitle: 'Congratulations! Coupon "$cleanCode" applied successfully to your order!',
              savingsText: 'You Saved ₹${discount.toInt()} Extra on this Order',
              isBogo: false,
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isApplyingCoupon = false;
            if (silent) {
              _appliedCoupon = null;
              _couponDiscount = 0.0;
              _freeGiftDetails = null;
              _nudgeMessage = null;
              _isBogoApplied = false;
              _bogoBadgeText = null;
            }
          });
          if (!silent) {
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
  }

  Future<void> _checkAutoApplyCoupon(double subtotal, String? restaurantId) async {
    if (_appliedCoupon != null || _isApplyingCoupon) return;
    try {
      final repo = CouponRepository(ref.read(dioProvider));
      final coupons = await repo.getCoupons(restaurantId: restaurantId);
      final autoCoupons = coupons.where((c) => c.autoApply && c.isValid).toList();
      for (final c in autoCoupons) {
        if (_appliedCoupon != null) break;
        await _applyCoupon(c.code, subtotal, silent: true);
      }
    } catch (_) {}
  }

  void _removeCoupon() {
    HapticFeedback.lightImpact();
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _freeGiftDetails = null;
      _nudgeMessage = null;
      _isBogoApplied = false;
      _bogoBadgeText = null;
      _couponController.clear();
    });
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
                    color: AppDesignSystem.slate200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: _buildEmptyState(context),
          );
        }

        return _buildCartScreenContent(context, ref, cart);
      },
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
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
          title: Text(
            'Your Cart',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 17),
              fontWeight: FontWeight.w900,
              color: slateDark,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: const CartShimmerSkeleton(),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
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
        ),
        body: _buildCartErrorState(context, ref),
      ),
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
                color: AppDesignSystem.statusPending,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.wifi_off_rounded, size: 40, color: AppDesignSystem.danger),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Issue',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 18),
                fontWeight: FontWeight.w900,
                color: slateDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load your cart items. Please check your network and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                color: slateMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).loadCart();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.scaledFontSize(context, 13),
                ),
              ),
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
                color: AppDesignSystem.rose50,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.shopping_bag_outlined, size: 44, color: primaryRed),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your Cart is Empty',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 18),
                fontWeight: FontWeight.w900,
                color: slateDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add farm fresh fruits, dairy, snacks & hot meals!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                color: slateMuted,
              ),
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
              child: Text(
                'Explore Products',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.scaledFontSize(context, 13),
                ),
              ),
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
    const packagingFee = 5.0;
    const packagingLabel = 'Standard Packaging';
    final itemSavings = cart.savings;
    final freeGiftSavings = (_freeGiftDetails != null && _freeGiftDetails!['originalPrice'] != null)
        ? ((_freeGiftDetails!['originalPrice'] as num).toDouble())
        : 0.0;
    final totalSavings = itemSavings + _couponDiscount + freeGiftSavings;
    final grandTotal = (subtotal + deliveryFee + packagingFee + _selectedTip - _couponDiscount).clamp(0.0, 999999.0);
    final totalItems = cart.totalItems;

    // Silent re-validation or auto-apply if cart items change
    final currentCartHash = cart.items.map((i) => '${i.productId}_${i.quantity}_${i.selectedVariant}').join('|');
    if (_lastValidatedCartHash != currentCartHash) {
      _lastValidatedCartHash = currentCartHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_appliedCoupon != null) {
          _applyCoupon(_appliedCoupon!, subtotal, silent: true);
        } else if (cart.items.isNotEmpty) {
          final restId = cart.items.firstWhereOrNull((i) => isRestaurantProduct(i.product))?.product.restaurantId;
          _checkAutoApplyCoupon(subtotal, restId);
        }
      });
    }

    final groceryItems = cart.items.where((i) => !isRestaurantProduct(i.product)).toList();
    final restaurantItems = cart.items.where((i) => isRestaurantProduct(i.product)).toList();

    final Map<String, List<CartItem>> restaurantGroups = {};
    for (final item in restaurantItems) {
      final outlet = getOutletName(item.product);
      restaurantGroups.putIfAbsent(outlet, () => []).add(item);
    }
    final String? cartRestaurantId = restaurantItems.isNotEmpty
        ? restaurantItems.first.product.restaurantId
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppDesignSystem.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
                color: AppDesignSystem.red200,
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
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 150 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline Network Recovery Banner
                  OfflineBanner(
                    onRetry: () {
                      ref.read(cartProvider.notifier).loadCart();
                    },
                    offlineText: 'Offline • Reconnecting cart sync...',
                  ),

                  // 0. Dynamic Distance-Tiered Delivery Progress Bar
                  CartFreeDeliveryBar(subtotal: subtotal, tier: tier),

                  // 1. Grocery Items Section (if present)
                  if (groceryItems.isNotEmpty)
                    CartItemsSection(
                      isGrocery: true,
                      title: 'Grocery & Daily Essentials',
                      subtitle: 'Delivered from FastKirana Darkstore',
                      items: groceryItems,
                    ),

                  // 1.5 BOGO Nudge Alert Banner
                  if (_nudgeMessage != null && _nudgeMessage!.isNotEmpty)
                    CartBogoNudgeBanner(nudgeMessage: _nudgeMessage!),

                  // 2. Restaurant Items Section (Grouped by Outlet)
                  ...restaurantGroups.entries.map((entry) {
                    final outletName = entry.key;
                    final items = entry.value;
                    return CartItemsSection(
                      isGrocery: false,
                      title: outletName,
                      subtitle: 'Freshly prepared at outlet kitchen',
                      items: items,
                      cookingInstructionsController: _cookingInstructionsController,
                    );
                  }),

                  // 2.5 BOGO 100% Free Gift Card
                  if (_freeGiftDetails != null)
                    CartBogoFreeGiftCard(gift: _freeGiftDetails!),

                  const SizedBox(height: 14),

                  // 3. Frequently Bought Together Carousel
                  CartUpsellCarousel(
                    cartProductIds: cart.items.map((i) => i.productId).toList(),
                  ),

                  // 4. Delivery Instructions Section
                  CartDeliveryInstructions(
                    selectedInstructions: _selectedInstructions,
                    onToggleInstruction: (label) {
                      setState(() {
                        if (_selectedInstructions.contains(label)) {
                          _selectedInstructions.remove(label);
                        } else {
                          _selectedInstructions.add(label);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. Delivery Partner Tip Card
                  CartTipSelector(
                    selectedTip: _selectedTip,
                    onTipSelected: (tip) {
                      setState(() => _selectedTip = tip);
                    },
                  ),
                  const SizedBox(height: 14),

                  // 6. Apply Promo / Coupon Code Card
                  CartCouponCard(
                    subtotal: subtotal,
                    restaurantId: cartRestaurantId,
                    appliedCoupon: _appliedCoupon,
                    couponDiscount: _couponDiscount,
                    isApplyingCoupon: _isApplyingCoupon,
                    isBogoApplied: _isBogoApplied,
                    bogoBadgeText: _bogoBadgeText,
                    nudgeMessage: _nudgeMessage,
                    freeGiftDetails: _freeGiftDetails,
                    controller: _couponController,
                    onApplyCoupon: (code) => _applyCoupon(code, subtotal),
                    onRemoveCoupon: _removeCoupon,
                  ),
                  const SizedBox(height: 14),

                  // 7. Bill Details Card
                  CartBillDetailsCard(
                    subtotal: subtotal,
                    itemSavings: itemSavings,
                    deliveryFee: deliveryFee,
                    packagingFee: packagingFee,
                    packagingLabel: packagingLabel,
                    totalSavings: totalSavings,
                    grandTotal: grandTotal,
                    couponDiscount: _couponDiscount,
                    selectedTip: _selectedTip,
                    freeGiftDetails: _freeGiftDetails,
                  ),
                  const SizedBox(height: 14),

                  // 8. Cancellation Policy Info
                  const CartCancellationPolicy(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Celebration Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                maxBlastForce: 28,
                minBlastForce: 10,
                emissionFrequency: 0.05,
                numberOfParticles: 40,
                gravity: 0.25,
                colors: const [
                  Color(0xFFEA580C),
                  Color(0xFF16A34A),
                  Color(0xFFEAB308),
                  Color(0xFF3B82F6),
                  Color(0xFFEC4899),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),
          ],
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
              child: CartBottomCheckoutBar(
                totalSavings: totalSavings,
                grandTotal: grandTotal,
                subtotal: subtotal,
                deliveryFee: deliveryFee,
                tier: tier,
                couponDiscount: _couponDiscount,
                appliedCoupon: _appliedCoupon,
                cookingInstruction: _cookingInstructionsController.text.trim(),
                onViewBreakdown: () => CartBillDetailsCard.showModal(
                  context: context,
                  subtotal: subtotal,
                  deliveryFee: deliveryFee,
                  savings: totalSavings,
                  grandTotal: grandTotal,
                  selectedTip: _selectedTip,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
