import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
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
import 'widgets/gifting_sparkle_canvas.dart';
import 'widgets/luxury_gift_envelope_card.dart';
import 'widgets/curated_gift_combos_shelf.dart';
import 'widgets/gifting_trust_strip.dart';

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
  final TextEditingController _giftNoteCtrl = TextEditingController();
  late final ConfettiController _confettiController;
  bool _isSecretGift = true;

  String _selectedOccasion = 'Birthday';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    // Soft celebration confetti on entering the gifting boutique
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _giftNoteCtrl.dispose();
    _confettiController.dispose();
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
              const SizedBox(height: 12),
              TextField(
                controller: _giftNoteCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                maxLength: 120,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  labelText: 'Personal Gift Note (Free Message Card)',
                  hintText: 'e.g. Happy Birthday Priya! Wishing you the sweetest year ahead 🎈',
                  prefixIcon: const Icon(Icons.favorite_outline, color: Color(0xFFE11D48)),
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
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final n = _receiverNameCtrl.text.trim();
                    final p = _receiverPhoneCtrl.text.trim();
                    final note = _giftNoteCtrl.text.trim();
                    ref.read(checkoutControllerProvider.notifier).setReceiverDetails(
                      n.isNotEmpty ? n : null,
                      p.isNotEmpty ? p : null,
                    );
                    final secretPrefix = _isSecretGift ? '🎁 [SECRET GIFT: HIDE PRICE & INVOICE]\n' : '';
                    if (note.isNotEmpty || _isSecretGift) {
                      ref.read(checkoutControllerProvider.notifier).updateNotes(
                        '$secretPrefix${note.isNotEmpty ? '💌 Gift Note: $note' : ''}',
                      );
                    }
                    setState(() {});
                    _confettiController.play();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Save Details & Add Card 💌',
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
      backgroundColor: const Color(0xFFFAF6F7),
      body: Stack(
        children: [
          GiftingSparkleCanvas(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Top Gifting Store Banner (Royal Velvet & Gold Gradient)
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3D0C18), // Deep velvet wine
                          Color(0xFF5A1224), // Rich bordeaux
                          Color(0xFF7A1B32), // Vibrant rose wine
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Nav Bar: Glassmorphism back button + Crown title + Location + Confetti
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Bounceable(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFFDF73).withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFFFDF73).withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('📍', style: TextStyle(fontSize: 11)),
                                          const SizedBox(width: 4),
                                          Text(
                                            selectedAddress != null
                                                ? selectedAddress.fullAddress
                                                : 'Ghatampur Hub',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFFE082),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Interactive Confetti Party Popper Button
                                    Bounceable(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _confettiController.play();
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFFDF73),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text('🎉', style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Full-Bleed 16:9 Luxury Gifting Artwork Banner Card with Gold Rim
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFFFDF73).withValues(alpha: 0.45),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF6B1728).withValues(alpha: 0.30),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (config.bannerImageUrl.trim().isNotEmpty)
                                      CachedNetworkImage(
                                        imageUrl: config.bannerImageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _buildFallbackBanner(),
                                      )
                                    else
                                      _buildFallbackBanner(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Luxury Gifting Trust & Speed Strip
                const SliverToBoxAdapter(
                  child: GiftingTrustStrip(),
                ),

                // 3. Interactive Wax-Sealed Gift Card & Secret Mode Envelope
                SliverToBoxAdapter(
                  child: LuxuryGiftEnvelopeCard(
                    recipientName: _receiverNameCtrl.text.trim(),
                    recipientPhone: _receiverPhoneCtrl.text.trim(),
                    giftNote: _giftNoteCtrl.text.trim(),
                    isSecretGift: _isSecretGift,
                    onSecretGiftToggle: (val) {
                      setState(() => _isSecretGift = val);
                      final note = _giftNoteCtrl.text.trim();
                      final secretPrefix = val ? '🎁 [SECRET GIFT: HIDE PRICE & INVOICE]\n' : '';
                      ref.read(checkoutControllerProvider.notifier).updateNotes(
                        '$secretPrefix${note.isNotEmpty ? '💌 Gift Note: $note' : ''}',
                      );
                    },
                    onTapEdit: _showReceiverDetailsSheet,
                  ),
                ),

                // 4. Curated 1-Tap Gift Combos & Hampers
                SliverToBoxAdapter(
                  child: CuratedGiftCombosShelf(
                    catalog: products,
                    onHamperAdded: () {
                      _confettiController.play();
                      setState(() {});
                    },
                  ),
                ),

                // 5. Horizontal Scrolling Occasion Pills / Cards (Royal Velvet & Gold)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 8),
                    child: SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: occasions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF4A0E1C) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFFDF73)
                                      : const Color(0xFFEBC1CC),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFF6B1728).withValues(alpha: 0.25)
                                        : Colors.black.withValues(alpha: 0.03),
                                    blurRadius: isSelected ? 8 : 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (occ.imageUrl.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: CachedNetworkImage(
                                        imageUrl: occ.imageUrl,
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.contain,
                                        errorWidget: (_, __, ___) =>
                                            Text(occ.emoji, style: const TextStyle(fontSize: 16)),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(occ.emoji, style: const TextStyle(fontSize: 16)),
                                    ),
                                  Text(
                                    occ.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                      color: isSelected ? const Color(0xFFFFE082) : const Color(0xFF4A0E1C),
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
                ),

                // 6. Products Section Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 5),
                                Text(
                                  'Curated for $_selectedOccasion',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF3D0C18),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Fresh stock delivered from $storeCity Dark Store',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF7A4A57),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
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
                                'LIVE STOCK',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF15803D),
                                  letterSpacing: 0.3,
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
                          _confettiController.play();
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
          ),

          // 6. Floating Cart Bar (Exact same as home screen / "bahr")
          // Celebratory Confetti Emitter at Top Center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 24,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.25,
              colors: const [
                Color(0xFFE11D48), // Rose Red
                Color(0xFFFFD600), // Sparkling Gold
                Color(0xFFEC4899), // Hot Pink
                Color(0xFF2563EB), // Electric Blue
                Color(0xFF10B981), // Emerald Green
                Color(0xFFA855F7), // Royal Purple
              ],
            ),
          ),
          const FloatingCartBar(bottomOffset: 16),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/navratri/gifting-boutique-hero-hd.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3D0C18), Color(0xFF6B1728)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('🎁', style: TextStyle(fontSize: 48)),
            ),
          ),
        ),
        // Subtle gold vignette gradient
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.40),
              ],
            ),
          ),
        ),
        Positioned(
          left: 14,
          bottom: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B1728),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFDF73), width: 0.8),
                ),
                child: Text(
                  '👑 ROYAL BOUTIQUE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFFFFDF73),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Thoughtful Gifts, Delivered in 10 Mins',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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

                  // Bottom-Right Floating Green '+' Add Button
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: inCartCount == 0
                        ? Bounceable(
                            onTap: onAdd,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.20),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.add, size: 25, color: Color(0xFF16A34A)),
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
                                    child: const Icon(Icons.remove_rounded, size: 16, color: Colors.white),
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
                                    child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
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
