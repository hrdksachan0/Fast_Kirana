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
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../checkout/controllers/checkout_controller.dart';
import '../../widgets/floating_cart_bar.dart';
import 'widgets/gifting_sparkle_canvas.dart';
import 'widgets/luxury_gift_envelope_card.dart';
import 'widgets/curated_gift_combos_shelf.dart';
import 'widgets/gifting_trust_strip.dart';
import 'widgets/gifting_celebration_bento_box.dart';

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
  bool _isSecretGift = true;
  bool _sendTrackingLink = true;

  String _selectedOccasion = 'Flowers';

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _giftNoteCtrl.dispose();
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
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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

                  // Send Live Tracking Link to Receiver Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 20, color: Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Live Tracking Link to Receiver',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                              Text(
                                'Receiver will get an SMS with live tracking link (price is 100% hidden)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _sendTrackingLink,
                          activeTrackColor: const Color(0xFF16A34A),
                          onChanged: (val) {
                            setModalState(() => _sendTrackingLink = val);
                            setState(() => _sendTrackingLink = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _giftNoteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    maxLength: 250,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      labelText: 'Personal Gift Note',
                      helperText: 'Free handwritten message card inside 💌',
                      helperStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48)),
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
                        final trackingPrefix = _sendTrackingLink && p.isNotEmpty ? '📱 [SEND LIVE TRACKING LINK TO: $p]\n' : '';
                        if (note.isNotEmpty || _isSecretGift || _sendTrackingLink) {
                          ref.read(checkoutControllerProvider.notifier).updateNotes(
                            '$secretPrefix$trackingPrefix${note.isNotEmpty ? '💌 Gift Note: $note' : ''}',
                          );
                        }
                        setState(() {});
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final cartState = ref.watch(cartProvider);
    final cart = cartState.valueOrNull;
    final cartItems = cart?.items ?? [];

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
    final storeSettings = ref.watch(storeSettingsProvider).valueOrNull ?? const StoreSettings();
    final isStoreOpen = storeSettings.isStoreOpen;
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
            child: RefreshIndicator(
              color: const Color(0xFFBE123C),
              backgroundColor: Colors.white,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                ref.invalidate(giftingStoreConfigProvider);
                ref.invalidate(productsProvider(null));
                await ref.read(giftingStoreConfigProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Top Gifting Store Banner (Dynamic Gradient synced with Web Admin)
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            config.gradientStart,
                            Color.lerp(config.gradientStart, config.gradientEnd, 0.5) ?? config.gradientStart,
                            config.gradientEnd,
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
                            // Top Nav Bar: Glassmorphism back button + Crown title + Location
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
                                  child: _buildDynamicBanner(config),
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

                // 4. Curated 1-Tap Gift Combos & Hampers (Strictly Admin Created)
                SliverToBoxAdapter(
                  child: CuratedGiftCombosShelf(
                    hampers: config.hampers,
                    catalog: products,
                    onHamperAdded: () {
                      setState(() {});
                    },
                  ),
                ),

                // 5. The Celebration Edit Bento Box (Option A - Zepto Scalloped Liquid Style)
                SliverToBoxAdapter(
                  child: GiftingCelebrationBentoBox(
                    occasions: occasions,
                    selectedOccasion: _selectedOccasion,
                    onOccasionChanged: (occ) {
                      setState(() {
                        _selectedOccasion = occ;
                      });
                    },
                    products: giftProducts,
                    cartItems: cartItems,
                    isStoreOpen: isStoreOpen,
                    onAddToCart: (p) {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).addProduct(p);
                    },
                    onIncrement: (p) {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).increment(p);
                    },
                    onDecrement: (p) {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).decrement(p.id);
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),

        // 6. Floating Cart Bar (Exact same universal dock across whole app)
        const FloatingCartBar(bottomOffset: 16),
      ],
    ),
  );
}

  Widget _buildDynamicBanner(GiftingStoreConfigModel config) {
    final title = config.bannerTitle.trim().isNotEmpty
        ? config.bannerTitle.trim()
        : 'Thoughtful Gifts, Delivered With Love';
    final subtitle = config.bannerSubtitle.trim().isNotEmpty
        ? config.bannerSubtitle.trim()
        : 'Curated by FastMinute';
    final imageUrl = config.bannerImageUrl.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image: Web Admin Uploaded CDN Image OR HD Asset Fallback
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Image.asset(
              'assets/navratri/gifting-boutique-hero-hd.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackColorBanner(config),
            ),
          )
        else
          Image.asset(
            'assets/navratri/gifting-boutique-hero-hd.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackColorBanner(config),
          ),

        // Subtle gradient overlay for high-contrast legible typography
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),

        // Dynamic Title & Tagline overlay
        Positioned(
          left: 14,
          bottom: 12,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: config.gradientEnd.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFDF73), width: 0.8),
                ),
                child: Text(
                  '👑 ${title.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFFFFDF73),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackColorBanner(GiftingStoreConfigModel config) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.gradientStart, config.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text('🎁', style: TextStyle(fontSize: 48)),
      ),
    );
  }

  /// Strict exclusion list: products that should NEVER appear in the luxury gifting store
  bool _isNonGiftingProduct(Product p) {
    final name = p.name.toLowerCase();
    final cat = (p.category?.name ?? '').toLowerCase();

    // 1. Health drinks, milk powders, nutritional supplements (e.g. Bournvita, Horlicks)
    const healthDrinkBanned = [
      'bournvita',
      'bourn vita',
      'horlicks',
      'complan',
      'boost',
      'milo',
      'pediasure',
      'ensure',
      'protein',
      'whey',
    ];
    if (healthDrinkBanned.any((w) => name.contains(w))) return true;

    // 2. Daily cooking staples, flours, oils, spices, grains
    const staplesBanned = [
      'atta',
      'maida',
      'besan',
      'suji',
      'sooji',
      'chawal',
      'rice',
      'dal',
      'mustard oil',
      'refined oil',
      'soyabean oil',
      'fortune oil',
      'cooking oil',
      'salt',
      'namak',
      'sugar',
      'cheeni',
      'haldi',
      'mirch powder',
      'dhaniya powder',
      'jeera',
      'hing',
      'garam masala',
      'spices',
      'poha',
    ];
    if (staplesBanned.any((w) => name.contains(w))) return true;

    // 3. Vegetables, fruits, fresh produce (prevent 'capsicum' matching 'cap', 'cauliflower' matching 'flower')
    const produceBanned = [
      'capsicum',
      'shimla mirch',
      'cauliflower',
      'gobhi',
      'aloo',
      'potato',
      'pyaz',
      'onion',
      'tomato',
      'tamatar',
      'sabzi',
      'vegetable',
      'lemon',
      'nimbu',
      'adrak',
      'ginger',
      'lahsun',
      'garlic',
      'mirchi',
      'chilli',
      'kheera',
      'cucumber',
      'baingan',
      'brinjal',
      'bhindi',
      'lauki',
      'matar',
      'palak',
      'spinach',
      'dhaniya patti',
      'coriander',
    ];
    if (produceBanned.any((w) => name.contains(w))) return true;

    // 4. Household, cleaning, toiletries, personal care (prevent 'rose' cleaner / agarbatti / pears soap)
    const householdBanned = [
      'cleaner',
      'floor cleaner',
      'harpic',
      'colin',
      'lizol',
      'dettol',
      'savlon',
      'soap',
      'shampoo',
      'conditioner',
      'detergent',
      'surf',
      'ariel',
      'tide',
      'rin',
      'vim',
      'dishwash',
      'agarbatti',
      'dhoop',
      'mosquito',
      'all out',
      'good knight',
      'coil',
      'hit',
      'toilet',
      'diaper',
      'sanitary',
      'napkin',
      'toothpaste',
      'colgate',
      'brush',
      'pears',
      'face wash',
      'body wash',
      'scrub',
      'broom',
      'mop',
      'garbage bag',
      'phenyl',
      'gulab jal',
      'rose water',
    ];
    if (householdBanned.any((w) => name.contains(w))) return true;

    // 5. Beverages, syrups, cold drinks, sodas
    const beverageBanned = [
      'syrup',
      'shake',
      'milkshake',
      'tang',
      'glucon',
      'rasna',
      'soda',
      'pepsi',
      'coca-cola',
      'coca cola',
      'coke',
      'thums up',
      'sprite',
      'fanta',
      'frooti',
      'maaza',
      'slice',
      'sting',
      'energy drink',
      'red bull',
      'bisleri',
      'packaged water',
      'water bottle',
    ];
    if (beverageBanned.any((w) => name.contains(w))) return true;

    // 6. Fast food, savory snacks, everyday biscuits, cooking staples
    const snacksBanned = [
      'pizza',
      'burger',
      'sandwich',
      'chowmein',
      'noodle',
      'maggi',
      'pasta',
      'kurkure',
      'chips',
      'lays',
      'bingo',
      'namkeen',
      'bhujia',
      'popcorn',
      'peanut butter',
      'mayonnaise',
      'ketchup',
      'sauce',
      'biscuit',
      'biscuits',
      'cookies',
      'bourbon',
      'parle-g',
      'parle g',
      'marie',
      'monaco',
      'krackjack',
      'hide & seek',
      'dark fantasy',
      'bread',
      'pav',
      'rusk',
      'toast',
      'bun',
      'curd',
      'dahi',
      'paneer',
    ];
    if (snacksBanned.any((w) => name.contains(w))) return true;

    // 7. Non-gifting categories
    const bannedCats = [
      'cleaning',
      'household',
      'vegetables',
      'fruits',
      'staples',
      'atta',
      'rice',
      'dal',
      'oil',
      'masala',
      'personal care',
      'oral care',
      'hygiene',
      'baby care',
      'dairy',
      'beverages',
    ];
    // Special exception for milk cake which might be categorized under dairy
    if (bannedCats.any((bc) => cat.contains(bc))) {
      if (name.contains('milk cake')) return false;
      return true;
    }

    return false;
  }

  List<Product> _filterGiftingProducts(
    List<Product> allProducts,
    String occasion,
    List<GiftingOccasionModel> occasions,
  ) {
    // 0. Filter out all non-gifting products first
    final cleanProducts = allProducts.where((p) => !_isNonGiftingProduct(p)).toList();

    final occ = occasions.firstWhereOrNull((o) => o.label == occasion || o.title == occasion);
    final occasionLabel = (occ?.label ?? occasion).toLowerCase();

    int compareStockAndBestseller(Product a, Product b) {
      final aInStock = (a.isAvailable && a.isInStock) ? 1 : 0;
      final bInStock = (b.isAvailable && b.isInStock) ? 1 : 0;
      if (aInStock != bInStock) return bInStock.compareTo(aInStock);
      return (b.isBestSeller ? 1 : 0).compareTo(a.isBestSeller ? 1 : 0);
    }

    // 1. Explicit admin-curated product links (Highest priority)
    if (occ != null && occ.productIds.isNotEmpty) {
      final explicit = cleanProducts
          .where((p) => occ.productIds.contains(p.id) || occ.productIds.contains(p.slug))
          .toList();
      if (explicit.isNotEmpty) {
        explicit.sort(compareStockAndBestseller);
        return explicit;
      }
    }

    // 2. Strict Occasion-Specific Filtering
    final matched = cleanProducts.where((p) {
      final name = p.name.toLowerCase();
      final cat = (p.category?.name ?? '').toLowerCase();
      final tags = p.tags.map((t) => t.toLowerCase().trim()).toList();

      // --- TAB 1: FLOWERS & BOUQUETS ---
      if (occasionLabel.contains('flower') || occasionLabel.contains('rose') || occasionLabel.contains('bouquet')) {
        final isNonFloral = name.contains('gulabri') ||
            name.contains('floor cleaner') ||
            name.contains('agarbatti') ||
            name.contains('dhoop') ||
            name.contains('syrup') ||
            name.contains('sherbet') ||
            name.contains('sharbat') ||
            name.contains('water') ||
            name.contains('soap') ||
            name.contains('perfume') ||
            name.contains('spray') ||
            name.contains('room freshener') ||
            name.contains('tea');
        if (isNonFloral) return false;

        final isFloralCategory = cat.contains('flower') || cat.contains('bouquet');
        final isFloralName = name.contains('rose') ||
            name.contains('bouquet') ||
            name.contains('bloom') ||
            name.contains('gajra') ||
            name.contains('carnation') ||
            name.contains('orchid') ||
            name.contains('tulip') ||
            name.contains('lily') ||
            name.contains('sunflower');
        final isFloralTag = tags.contains('flower') ||
            tags.contains('flowers') ||
            tags.contains('bouquet') ||
            tags.contains('roses') ||
            tags.contains('rose');
        return isFloralCategory || isFloralName || isFloralTag;
      }

      // --- TAB 2: CAKES & BAKERY ---
      if (occasionLabel.contains('cake') || occasionLabel.contains('pastry') || occasionLabel.contains('bakery')) {
        final isNonCake = name.contains('soap') ||
            name.contains('rusk') ||
            name.contains('milk cake') || // traditional sweet goes to Sweets
            name.contains('atta') ||
            name.contains('premix');
        if (isNonCake) return false;

        final isCakeName = name.contains('cake') ||
            name.contains('donut cake') ||
            name.contains('pastry') ||
            name.contains('swiss roll') ||
            name.contains('muffin') ||
            name.contains('brownie') ||
            name.contains('cupcake');
        final isCakeTag = tags.contains('cake') || tags.contains('cakes') || tags.contains('pastry');
        return isCakeName || isCakeTag;
      }

      // --- TAB 3: LUXURY CHOCOLATES ---
      if (occasionLabel.contains('choc')) {
        final isNonChocolate = name.contains('shake') ||
            name.contains('syrup') ||
            name.contains('ice cream') ||
            name.contains('biscuit') ||
            name.contains('bournvita') ||
            name.contains('horlicks') ||
            name.contains('cake');
        if (isNonChocolate) return false;

        final isChocoBrand = name.contains('celebration') ||
            name.contains('silk') ||
            name.contains('ferrero') ||
            name.contains('bournville') ||
            name.contains('temptation') ||
            name.contains('kitkat') ||
            name.contains('dairy milk') ||
            name.contains('amul dark') ||
            name.contains('amul chocolate') ||
            name.contains('snickers') ||
            name.contains('5 star') ||
            name.contains('perk') ||
            name.contains('munch') ||
            name.contains('galaxy') ||
            name.contains('hershey');
        final isChocoTagged = (name.contains('chocolate') || tags.contains('chocolate') || tags.contains('chocolates') || cat.contains('chocolate'));
        return isChocoBrand || isChocoTagged;
      }

      // --- TAB 4: ROYAL SWEETS & MITHAI ---
      if (occasionLabel.contains('sweet') || occasionLabel.contains('mithai')) {
        final isNonMithai = name.contains('corn') || // sweet corn
            name.contains('soda') || // lime soda sweet
            name.contains('potato') || // sweet potato
            name.contains('sauce') ||
            name.contains('biscuit') ||
            name.contains('namkeen') ||
            name.contains('chutney');
        if (isNonMithai) return false;

        final isMithaiName = name.contains('kaju katli') ||
            name.contains('milk cake') ||
            name.contains('soan papdi') ||
            name.contains('chhena') ||
            name.contains('gulab jamun') ||
            name.contains('rasgulla') ||
            name.contains('laddu') ||
            name.contains('ladoo') ||
            name.contains('peda') ||
            name.contains('barfi') ||
            name.contains('burfi') ||
            name.contains('rasmalai') ||
            name.contains('cham cham') ||
            (name.contains('haldiram') && (name.contains('sweet') || name.contains('papdi') || name.contains('katli') || name.contains('jamun')));
        final isMithaiCategory = cat.contains('sweets') || cat.contains('mithai');
        final isMithaiTag = tags.contains('mithai') || tags.contains('sweets') || tags.contains('sweet');
        return isMithaiName || isMithaiCategory || isMithaiTag;
      }

      // Fallback for custom occasions
      return name.contains('gift') ||
          name.contains('celebration') ||
          name.contains('cake') ||
          name.contains('silk') ||
          name.contains('bouquet');
    }).toList();

    matched.sort(compareStockAndBestseller);

    return matched.take(60).toList();
  }
}
