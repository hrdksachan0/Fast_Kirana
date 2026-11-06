import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import '../../data/models/gifting_store_config.dart';
import '../../providers/gifting_store_provider.dart';

import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../checkout/controllers/checkout_controller.dart';
import '../../widgets/floating_cart_bar.dart';
import '../products/product_detail_screen.dart';

/// Luxury Gifting Store with 3D Banner, 6 Occasions Cards & 3-Column Zepto Grid
/// Driven by real-time productsProvider and cartProvider.
class SendGiftScreen extends ConsumerStatefulWidget {
  const SendGiftScreen({super.key});

  @override
  ConsumerState<SendGiftScreen> createState() => _SendGiftScreenState();
}

class _SendGiftScreenState extends ConsumerState<SendGiftScreen> {
  final TextEditingController _receiverNameCtrl = TextEditingController();
  final TextEditingController _receiverPhoneCtrl = TextEditingController();

  String _selectedOccasion = 'Birthday';

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    super.dispose();
  }

  void _showReceiverDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎁 Receiver Details (Optional)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppDesignSystem.slate500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter receiver details if you want our delivery partner to call them directly upon arrival.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _receiverNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  labelText: 'Receiver Name',
                  hintText: 'e.g. Mom, Rohit, Priya',
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2563EB)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppDesignSystem.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _receiverPhoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  labelText: 'Receiver Phone Number',
                  hintText: '10-digit mobile number',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, top: 14, right: 6),
                    child: Text('+91', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppDesignSystem.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final n = _receiverNameCtrl.text.trim();
                    final p = _receiverPhoneCtrl.text.trim();
                    ref.read(checkoutControllerProvider.notifier).setReceiverDetails(
                      n.isNotEmpty ? n : null,
                      p.isNotEmpty ? p : null,
                    );
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Save Details',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final cartState = ref.watch(cartProvider);
    final cart = cartState.valueOrNull;
    final cartItems = cart?.items ?? [];
    final currentHub = ref.watch(currentStoreHubProvider);
    final storeCity = currentHub.city.isNotEmpty ? currentHub.city : currentHub.name;

    // Dynamic Gifting Store Config from Admin
    final giftingConfigAsync = ref.watch(giftingStoreConfigProvider);
    final config = giftingConfigAsync.valueOrNull ??
        const GiftingStoreConfigModel(occasions: GiftingStoreConfigModel.defaultOccasions);
    final occasions = config.occasions.where((o) => o.isActive).toList();

    if (occasions.isNotEmpty && !occasions.any((o) => o.label == _selectedOccasion)) {
      _selectedOccasion = occasions.first.label;
    }

    // Real-time backend products connection
    final allProductsAsync = ref.watch(productsProvider(null));
    final products = allProductsAsync.valueOrNull ?? [];
    final giftProducts = _filterGiftingProducts(products, _selectedOccasion, occasions);

    final hasReceiverInfo = _receiverNameCtrl.text.trim().isNotEmpty ||
        _receiverPhoneCtrl.text.trim().isNotEmpty;

    if (!config.enabled) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            config.bannerTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Gifting Store Temporarily Unavailable',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We are updating curated hampers and festive gifts. Please check back shortly!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top Gifting Store Banner (Dynamic Gradient & Admin Uploaded Art)
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        config.gradientStart,
                        config.gradientStart.withValues(alpha: 0.95),
                        config.gradientEnd,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Top Nav
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Bounceable(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  selectedAddress != null
                                      ? selectedAddress.fullAddress
                                      : 'Ghatampur Hub',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Banner Headline
                        Text(
                          config.bannerTitle,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.bannerSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFF1F2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Hero Art (Custom Admin Image or Clean 3D Squircle)
                        if (config.bannerImageUrl.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: config.bannerImageUrl,
                                height: 110,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Text('🎁', style: TextStyle(fontSize: 52)),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 100,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('🎁', style: TextStyle(fontSize: 44)),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Occasion Cards Grid (Dynamic Occasions from Admin)
              SliverToBoxAdapter(
                child: Container(
                  color: config.gradientEnd,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: occasions.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.90,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                    ),
                    itemBuilder: (context, index) {
                      final occ = occasions[index];
                      final isSelected = occ.label == _selectedOccasion;

                      return Bounceable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedOccasion = occ.label;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFBE123C) : Colors.transparent,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFFBE123C).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 26,
                                child: Center(
                                  child: Text(
                                    occ.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                      color: isSelected ? const Color(0xFFBE123C) : const Color(0xFF713F12),
                                      height: 1.15,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Center(
                                    child: occ.imageUrl.trim().isNotEmpty
                                        ? Transform.scale(
                                            scale: 1.12,
                                            child: CachedNetworkImage(
                                              imageUrl: occ.imageUrl,
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => Center(
                                                child: Text(occ.emoji, style: const TextStyle(fontSize: 28)),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(occ.emoji, style: const TextStyle(fontSize: 28)),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. Compact Receiver Details Pill (Unobtrusive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Bounceable(
                    onTap: _showReceiverDetailsSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasReceiverInfo ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasReceiverInfo ? const Color(0xFFBFDBFE) : AppDesignSystem.slate200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(hasReceiverInfo ? '🎁' : '👤', style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasReceiverInfo
                                  ? 'Gifting to: ${_receiverNameCtrl.text.trim()} (${_receiverPhoneCtrl.text.trim()})'
                                  : 'Sending as a gift? Add receiver details',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: hasReceiverInfo ? FontWeight.w700 : FontWeight.w600,
                                color: hasReceiverInfo ? const Color(0xFF1D4ED8) : AppDesignSystem.slate700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            hasReceiverInfo ? 'EDIT' : '+ ADD',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Products Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popular in $_selectedOccasion',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Real-time inventory from $storeCity Store',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.slate500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. 3-Column Zepto Style Product Cards Grid (Real-time backend attached!)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 110),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.isTablet(context) ? 4 : 3,
                    childAspectRatio: Responsive.isTablet(context)
                        ? 0.72
                        : (MediaQuery.of(context).size.width < 360 ? 0.60 : 0.63),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = giftProducts[index];
                      final inCartCount = cartItems
                          .where((item) => item.product.id == product.id)
                          .fold(0, (sum, item) => sum + item.quantity);

                      return _ZeptoGiftCard(
                        product: product,
                        inCartCount: inCartCount,
                        onAdd: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).addProduct(product);
                        },
                        onIncrement: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).increment(product);
                        },
                        onDecrement: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).decrement(product.id);
                        },
                      );
                    },
                    childCount: giftProducts.length,
                  ),
                ),
              ),
            ],
          ),

          // 6. Floating Cart Bar (Exact same as home screen / "bahr")
          const FloatingCartBar(bottomOffset: 16),
        ],
      ),
    );
  }

  List<Product> _filterGiftingProducts(
    List<Product> allProducts,
    String occasion,
    List<GiftingOccasionModel> occasions,
  ) {
    final occ = occasions.firstWhereOrNull((o) => o.label == occasion);
    final occasionTags = (occ?.tags ?? []).map((t) => t.toLowerCase().trim()).toList();
    final lower = occasion.toLowerCase();

    final matched = allProducts.where((p) {
      final name = p.name.toLowerCase();
      final cat = (p.category?.name ?? '').toLowerCase();
      final tags = p.tags.map((t) => t.toLowerCase().trim()).toList();

      // 1. Dynamic tags matching from Admin
      if (occasionTags.isNotEmpty && occasionTags.any((t) => tags.contains(t) || name.contains(t) || cat.contains(t))) {
        return true;
      }

      // 2. Fallbacks
      if (lower.contains('anniversary')) {
        return name.contains('silk') ||
            name.contains('ferrero') ||
            name.contains('chocolate') ||
            name.contains('rose') ||
            tags.contains('gift');
      }
      if (lower.contains('birthday') || lower.contains('cake')) {
        return name.contains('cake') ||
            cat.contains('bakery') ||
            name.contains('chocolate') ||
            tags.contains('cake') ||
            tags.contains('sweet');
      }
      if (lower.contains('chocolate')) {
        return name.contains('chocolate') ||
            name.contains('silk') ||
            name.contains('ferrero') ||
            name.contains('cadbury') ||
            tags.contains('chocolate');
      }
      if (lower.contains('mithai')) {
        return name.contains('katli') ||
            name.contains('jamun') ||
            name.contains('laddu') ||
            name.contains('haldiram') ||
            name.contains('sweet') ||
            tags.contains('sweet');
      }
      if (lower.contains('dry fruit') || lower.contains('festive')) {
        return name.contains('almond') ||
            name.contains('kaju') ||
            name.contains('cashew') ||
            name.contains('nut') ||
            p.isBestSeller ||
            tags.contains('dry fruit');
      }
      return name.contains('gift') ||
          name.contains('celebration') ||
          name.contains('cake') ||
          name.contains('chocolate') ||
          cat.contains('sweet');
    }).toList();

    if (matched.length >= 6) {
      return matched.take(24).toList();
    }

    // Prioritize real database products first, supplemented with curated hampers to keep the 3-column grid rich
    final fallback = _getFallbackGiftHampers();
    final combined = <Product>[...matched];
    for (final f in fallback) {
      if (!combined.any((p) => p.name.toLowerCase() == f.name.toLowerCase() || p.id == f.id)) {
        combined.add(f);
      }
      if (combined.length >= 12) break;
    }
    return combined;
  }

  List<Product> _getFallbackGiftHampers() {
    return [
      Product(
        id: 'gift-ferrero-16',
        name: 'Ferrero Rocher Premium Gold Box (16 Pcs)',
        slug: 'ferrero-rocher-16',
        mrp: 599,
        price: 529,
        discount: 70,
        unit: '200 g',
        stock: 40,
        isAvailable: true,
        tags: ['gift', 'chocolate', 'premium'],
        minStock: 5,
        costPrice: 450,
        isFlashDeal: false,
        isTopPick: true,
        isBestSeller: true,
        sortOrder: 1,
        imageUrl: 'https://images.unsplash.com/photo-1582293041079-7814c2f12063?w=400&q=80',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'gift-truffle-cake',
        name: 'Dutch Truffle Chocolate Fresh Cake',
        slug: 'dutch-truffle-cake-500g',
        mrp: 450,
        price: 399,
        discount: 51,
        unit: '500 g',
        stock: 25,
        isAvailable: true,
        tags: ['gift', 'cake', 'birthday'],
        minStock: 2,
        costPrice: 300,
        isFlashDeal: true,
        isTopPick: true,
        isBestSeller: true,
        sortOrder: 2,
        imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'gift-cadbury-celebration',
        name: 'Cadbury Celebrations Rich Dry Fruit Box',
        slug: 'cadbury-celebrations-gift-box',
        mrp: 299,
        price: 249,
        discount: 50,
        unit: '250 g',
        stock: 50,
        isAvailable: true,
        tags: ['gift', 'chocolate', 'sweets'],
        minStock: 5,
        costPrice: 200,
        isFlashDeal: false,
        isTopPick: true,
        isBestSeller: true,
        sortOrder: 3,
        imageUrl: 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=400&q=80',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'gift-haldiram-kaju-katli',
        name: 'Haldiram Royal Kaju Katli Gift Pack',
        slug: 'haldiram-kaju-katli-gift',
        mrp: 499,
        price: 449,
        discount: 50,
        unit: '500 g',
        stock: 30,
        isAvailable: true,
        tags: ['gift', 'mithai', 'sweets'],
        minStock: 5,
        costPrice: 380,
        isFlashDeal: false,
        isTopPick: true,
        isBestSeller: false,
        sortOrder: 4,
        imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'gift-nut-circle',
        name: "Haldiram's Nut Circle (Dry Fruit Pack)",
        slug: 'haldiram-nut-circle-400g',
        mrp: 1199,
        price: 1022,
        discount: 177,
        unit: '400 g',
        stock: 50,
        isAvailable: true,
        tags: ['gift', 'dry fruit', 'festive'],
        minStock: 5,
        costPrice: 850,
        isFlashDeal: false,
        isTopPick: true,
        isBestSeller: false,
        sortOrder: 5,
        imageUrl: 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=400&q=80',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'gift-silk-pralines',
        name: 'Cadbury Dairy Milk Silk Pralines Box',
        slug: 'cadbury-silk-pralines',
        mrp: 199,
        price: 175,
        discount: 24,
        unit: '150 g',
        stock: 35,
        isAvailable: true,
        tags: ['gift', 'chocolate'],
        minStock: 5,
        costPrice: 140,
        isFlashDeal: false,
        isTopPick: false,
        isBestSeller: false,
        sortOrder: 6,
        imageUrl: 'https://images.unsplash.com/photo-1582293041079-7814c2f12063?w=400&q=80',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

/// Exact Zepto/Blinkit Style 3-Column Compact Product Card
class _ZeptoGiftCard extends StatelessWidget {
  final Product product;
  final int inCartCount;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ZeptoGiftCard({
    required this.product,
    required this.inCartCount,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercent = product.mrp > product.price
        ? (((product.mrp - product.price) / product.mrp) * 100).round()
        : 0;

    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(page: ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Square Image Container (1:1 Ratio)
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl ?? '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(child: Text('🎁', style: TextStyle(fontSize: 22))),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(child: Text('🎁', style: TextStyle(fontSize: 22))),
                        ),
                      ),
                    ),
                  ),

                  // Top-Left Badge (HOT or GIFT)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: product.isBestSeller
                            ? const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                              ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        product.isBestSeller ? '🔥 HOT' : '🎁 GIFT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Left Veg Icon
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF16A34A), width: 1.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Right Floating Green '+' Add Button
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: inCartCount == 0
                        ? Bounceable(
                            onTap: onAdd,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF16A34A), width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.add_rounded, size: 20, color: Color(0xFF16A34A)),
                              ),
                            ),
                          )
                        : Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.30),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Bounceable(
                                  onTap: onDecrement,
                                  child: Container(
                                    width: 22,
                                    height: 30,
                                    alignment: Alignment.center,
                                    color: Colors.transparent,
                                    child: const Icon(Icons.remove_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    '$inCartCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Bounceable(
                                  onTap: onIncrement,
                                  child: Container(
                                    width: 22,
                                    height: 30,
                                    alignment: Alignment.center,
                                    color: Colors.transparent,
                                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // 2. Info Details Below Image
            Padding(
              padding: const EdgeInsets.fromLTRB(1, 4, 1, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row: Unit badge + Discount %
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFBBF7D0), width: 0.7),
                        ),
                        child: Text(
                          product.unit.isNotEmpty ? product.unit : '1 pc',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      if (discountPercent > 0) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$discountPercent% OFF',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Price Row (Price + Strikethrough MRP)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                      if (product.mrp > product.price) ...[
                        const SizedBox(width: 3),
                        Text(
                          '₹${product.mrp.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.slate400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),

                  // 2-line Product Title (Fixed height so all 3 cards in row align)
                  SizedBox(
                    height: 26,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
