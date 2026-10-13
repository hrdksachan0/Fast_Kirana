import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/category.dart';

/// Dynamic, animated spotlight hero banner displayed between
/// the subcategory filter chips and the infinite product grid.
class HomeAisleSpotlightBanner extends StatefulWidget {
  final Category? selectedSubcategory;
  final int totalCount;
  final VoidCallback? onTap;

  const HomeAisleSpotlightBanner({
    super.key,
    required this.selectedSubcategory,
    required this.totalCount,
    this.onTap,
  });

  @override
  State<HomeAisleSpotlightBanner> createState() => _HomeAisleSpotlightBannerState();
}

class _HomeAisleSpotlightBannerState extends State<HomeAisleSpotlightBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // Gentle 3D floating packshot motion (breathing effect)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.5, end: 3.5).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  _BannerConfig _resolveConfig() {
    final sub = widget.selectedSubcategory;
    if (sub == null) {
      return const _BannerConfig(
        tag: '⚡ GHATAMPUR SUPER SAVER',
        headline: 'Daily Essentials & Groceries\nFlat 10%–40% Off Daily',
        subtext: '⚡ Instant Delivery in 10-15 Mins',
        ctaText: 'Shop All 150+ Items',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789047720250-xu6kpy.webp',
        gradientColors: [
          Color(0xFF064E3B), // Deep Emerald
          Color(0xFF047857),
          Color(0xFF0D9488),
        ],
        accentColor: Color(0xFF34D399),
      );
    }

    final slug = sub.slug.toLowerCase();
    final name = sub.name.toLowerCase();
    final id = sub.id.toUpperCase();

    // Atta, Rice & Grains
    if (id == 'SUB-113-01' || slug.contains('atta') || slug.contains('flour') || slug.contains('rice') || name.contains('atta') || name.contains('rice')) {
      return const _BannerConfig(
        tag: '🌾 100% PURE CHAKKI FRESH',
        headline: 'Aashirvaad & Fortune\nDaily Flour, Basmati & Grains',
        subtext: '⚡ 100% Pure & Unadulterated',
        ctaText: 'Explore Staples',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789048712199-lsktq8.webp',
        gradientColors: [
          Color(0xFF78350F), // Rich Golden Amber
          Color(0xFF92400E),
          Color(0xFFB45309),
        ],
        accentColor: Color(0xFFFBBF24),
      );
    }

    // Dals & Pulses
    if (id == 'SUB-113-03' || slug.contains('dal') || slug.contains('pulse') || name.contains('dal') || name.contains('pulse')) {
      return const _BannerConfig(
        tag: '🍲 UNPOLISHED & HEALTHY',
        headline: 'Tata Sampann & Unpolished Dals\nUp to 25% Off Today',
        subtext: '⚡ High Protein & 5-Step Cleaned',
        ctaText: 'View All Dals',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789049101961-bosttm.webp',
        gradientColors: [
          Color(0xFF7C2D12), // Warm Terracotta
          Color(0xFF9A3412),
          Color(0xFFC2410C),
        ],
        accentColor: Color(0xFFFB923C),
      );
    }

    // Oils & Ghee
    if (id == 'SUB-113-02' || slug.contains('oil') || slug.contains('ghee') || name.contains('oil') || name.contains('ghee')) {
      return const _BannerConfig(
        tag: '🛢️ PURE MUSTARD & DESI GHEE',
        headline: 'Fortune Oil & Amul Pure Ghee\nAt Lowest Market Prices',
        subtext: '⚡ Guaranteed Purity & Aroma',
        ctaText: 'Buy Cooking Oils',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789048994145-dlhm89.jpg',
        gradientColors: [
          Color(0xFF713F12), // Pure Butter Gold
          Color(0xFF854D0E),
          Color(0xFFA16207),
        ],
        accentColor: Color(0xFFFACC15),
      );
    }

    // Spices & Masala
    if (id == 'SUB-113-04' || slug.contains('masala') || slug.contains('spice') || name.contains('masala') || name.contains('spice')) {
      return const _BannerConfig(
        tag: '🌶️ AROMATIC & AUTHENTIC',
        headline: 'Catch, MDH & Everest Spices\nBring Rich Flavor To Meals',
        subtext: '⚡ Fresh Ground Spices',
        ctaText: 'Explore Spices',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789067051942-2s7js5.jpg',
        gradientColors: [
          Color(0xFF831843), // Rich Crimson Spice
          Color(0xFF9D174D),
          Color(0xFFBE185D),
        ],
        accentColor: Color(0xFFF472B6),
      );
    }

    // Tea & Coffee
    if (id == 'SUB-113-05' || slug.contains('tea') || slug.contains('coffee') || slug.contains('chai') || name.contains('tea') || name.contains('chai')) {
      return const _BannerConfig(
        tag: '☕ MORNING ENERGY BREW',
        headline: 'Tata Tea Gold & Nescafe\nFresh Morning Brews & Sugar',
        subtext: '⚡ Handpicked Tea Gardens',
        ctaText: 'Order Tea & Coffee',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789052576291-mg0n0r.jpg',
        gradientColors: [
          Color(0xFF78350F), // Tea Brew Amber
          Color(0xFF854D0E),
          Color(0xFF9A3412),
        ],
        accentColor: Color(0xFFFBBF24),
      );
    }

    // Biscuits & Cookies
    if (id == 'SUB-102-01' || slug.contains('cookie') || slug.contains('biscuit') || name.contains('cookie') || name.contains('biscuit')) {
      return const _BannerConfig(
        tag: '🍪 CRISPY & DELICIOUS',
        headline: 'Good Day, Oreo & Parle-G\nTea-Time Munchies & Rusks',
        subtext: '⚡ Crunchy Crispy Bakes',
        ctaText: 'Browse Cookies',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789579146021-wpqoto.jpg',
        gradientColors: [
          Color(0xFF831843), // Berry Rose
          Color(0xFF9D174D),
          Color(0xFFBE185D),
        ],
        accentColor: Color(0xFFF472B6),
      );
    }

    // Namkeen & Snacks
    if (id == 'SUB-102-02' || slug.contains('namkeen') || slug.contains('snack') || name.contains('namkeen') || name.contains('snack')) {
      return const _BannerConfig(
        tag: '🥨 CHATPATI MUNCHIES',
        headline: 'Haldiram Bhujia, Mixture & Chips\nPerfect Evening Snacks',
        subtext: '⚡ Fresh & Crispy Batches',
        ctaText: 'Get Snacks',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789579178288-mxgb4h.jpg',
        gradientColors: [
          Color(0xFF7C2D12),
          Color(0xFF9A3412),
          Color(0xFFEA580C),
        ],
        accentColor: Color(0xFFFB923C),
      );
    }

    // Instant Food & Noodles
    if (id == 'SUB-104-02' || slug.contains('noodle') || slug.contains('instant') || slug.contains('pasta') || name.contains('noodle') || name.contains('instant')) {
      return const _BannerConfig(
        tag: '🍜 2-MINUTE CRAVINGS',
        headline: 'Maggi, Yippee & Quick Pastas\nInstant Hunger Solutions',
        subtext: '⚡ Ready In Under 5 Mins',
        ctaText: 'Grab Maggi & Noodles',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789070202326-or0hs8.jpg',
        gradientColors: [
          Color(0xFF9F1239), // Zesty Tomato Red
          Color(0xFFBE123C),
          Color(0xFFE11D48),
        ],
        accentColor: Color(0xFFFDA4AF),
      );
    }

    // Sauces & Spreads
    if (id == 'SUB-104-01' || slug.contains('sauce') || slug.contains('spread') || slug.contains('ketchup') || name.contains('sauce') || name.contains('ketchup')) {
      return const _BannerConfig(
        tag: '🍅 TANGY SPREADS & DIPS',
        headline: 'Kissan Fresh Ketchup & Spreads\nMake Every Snack Taste Better',
        subtext: '⚡ 100% Real Tomatoes',
        ctaText: 'Explore Sauces',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789070185714-5l8sjd.webp',
        gradientColors: [
          Color(0xFF991B1B),
          Color(0xFFDC2626),
          Color(0xFFEF4444),
        ],
        accentColor: Color(0xFFFCA5A5),
      );
    }

    // Dry Fruits & Superfoods
    if (id.contains('114') || slug.contains('dry') || slug.contains('nut') || name.contains('dry') || name.contains('nut')) {
      return const _BannerConfig(
        tag: '🥜 100% PREMIUM CRUNCH',
        headline: 'California Almonds & Cashews\nHealthy Daily Superfoods',
        subtext: '⚡ Grade-A Quality Dry Fruits',
        ctaText: 'View Dry Fruits',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789051856805-vl9cul.webp',
        gradientColors: [
          Color(0xFF581C87), // Royal Purple
          Color(0xFF6B21A8),
          Color(0xFF7E22CE),
        ],
        accentColor: Color(0xFFC084FC),
      );
    }

    // Chocolates & Cakes
    if (id == 'SUB-115-03' || slug.contains('choco') || slug.contains('sweet') || name.contains('choco') || name.contains('sweet')) {
      return const _BannerConfig(
        tag: '🍫 SWEET INDULGENCE',
        headline: 'Cadbury Silk & Amul Delights\nSweeten Every Celebration',
        subtext: '⚡ Chilled Packshot Delivery',
        ctaText: 'Treat Yourself',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789580069746-5jc34m.webp',
        gradientColors: [
          Color(0xFF4C1D95), // Velvet Violet
          Color(0xFF5B21B6),
          Color(0xFF6D28D9),
        ],
        accentColor: Color(0xFFA78BFA),
      );
    }

    // Bakery & Bread
    if (id == 'SUB-115-02' || slug.contains('bakery') || slug.contains('bread') || name.contains('bakery') || name.contains('bread')) {
      return const _BannerConfig(
        tag: '🍞 OVEN FRESH DAILY',
        headline: 'Soft Milk Breads & Fresh Pav\nDirect From Daily Bakeries',
        subtext: '⚡ Fresh Morning Batches',
        ctaText: 'Explore Bakery',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789072252410-wgyl4x.jpg',
        gradientColors: [
          Color(0xFF78350F),
          Color(0xFF92400E),
          Color(0xFFB45309),
        ],
        accentColor: Color(0xFFFBBF24),
      );
    }

    // Laundry & Detergents
    if (id == 'SUB-107-03' || slug.contains('laund') || slug.contains('detergent') || name.contains('laund') || name.contains('detergent')) {
      return const _BannerConfig(
        tag: '🧼 STAIN-FREE BRILLIANCE',
        headline: 'Surf Excel, Tide & Ariel\nHeavy Duty Fabric Washers',
        subtext: '⚡ Mega Savings On 1kg & 5kg',
        ctaText: 'Buy Detergents',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789720652264-qjc582.webp',
        gradientColors: [
          Color(0xFF1E3A8A), // Royal Navy
          Color(0xFF1D4ED8),
          Color(0xFF2563EB),
        ],
        accentColor: Color(0xFF60A5FA),
      );
    }

    // Dishwashing
    if (id == 'SUB-107-01' || slug.contains('dish') || name.contains('dish')) {
      return const _BannerConfig(
        tag: '🧽 LEMON GREASE CUTTER',
        headline: 'Vim Gel & Dishwash Bars\nSparkling Clean Utensils',
        subtext: '⚡ With Real Lemon Power',
        ctaText: 'Get Dishwashers',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789062801545-7v6i2w.jpg',
        gradientColors: [
          Color(0xFF065F46),
          Color(0xFF059669),
          Color(0xFF10B981),
        ],
        accentColor: Color(0xFF34D399),
      );
    }

    // Oral Care
    if (id == 'SUB-109-02' || slug.contains('oral') || slug.contains('dental') || name.contains('oral') || name.contains('dental')) {
      return const _BannerConfig(
        tag: '🪥 FRESH ALL-DAY SMILE',
        headline: 'Colgate, CloseUp & Sensodyne\nComplete Dental Protection',
        subtext: '⚡ Germ Protection & Freshness',
        ctaText: 'Oral Care Range',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789065627371-4nxg59.jpg',
        gradientColors: [
          Color(0xFF134E4A), // Ocean Teal
          Color(0xFF0F766E),
          Color(0xFF14B8A6),
        ],
        accentColor: Color(0xFF2DD4BF),
      );
    }

    // Hair Care & Personal Care
    if (id == 'SUB-109-01' || slug.contains('hair') || slug.contains('care') || name.contains('hair') || name.contains('care')) {
      return const _BannerConfig(
        tag: '🧴 NOURISHMENT & GLOW',
        headline: 'Dove, Pantene & Almond Oils\nSoft & Silky Hair Care',
        subtext: '⚡ 100% Genuine Care Brands',
        ctaText: 'Explore Hair Care',
        imageUrl:
            'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789063584529-snlc7r.jpg',
        gradientColors: [
          Color(0xFF1E293B), // Slate Luxury
          Color(0xFF334155),
          Color(0xFF475569),
        ],
        accentColor: Color(0xFF94A3B8),
      );
    }

    // Default Fallback
    return _BannerConfig(
      tag: '⚡ GHATAMPUR SUPER SAVER',
      headline: '${sub.name}\n100% Quality Checked Items',
      subtext: '⚡ Fast Delivery to Ghatampur',
      ctaText: 'Explore Aisle',
      imageUrl: (sub.imageUrl != null && sub.imageUrl!.isNotEmpty)
          ? sub.imageUrl!
          : 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789047720250-xu6kpy.webp',
      gradientColors: const [
        Color(0xFF064E3B),
        Color(0xFF047857),
        Color(0xFF0D9488),
      ],
      accentColor: const Color(0xFF34D399),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _resolveConfig();
    final uniqueKey = ValueKey(widget.selectedSubcategory?.id ?? 'all_sub');

    return Bounceable(
      scaleFactor: 0.98,
      onTap: widget.onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: uniqueKey,
          height: 142,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: config.gradientColors,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: config.gradientColors.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Ambient Background Glow Orbs
                Positioned(
                  top: -20,
                  right: 40,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: config.accentColor.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),

                // 2. Left Text Content & Badges
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 125, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Pill Tag with glowing live pulse
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: config.accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: config.accentColor.withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    config.tag,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Headline
                        Text(
                          config.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 14.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.18,
                            letterSpacing: -0.3,
                          ),
                        ),

                        // Bottom Subtext & Live Count Pill
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                config.subtext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Floating 3D Photographic Packshot on Right
                Positioned(
                  top: 8,
                  bottom: 8,
                  right: 10,
                  width: 115,
                  child: AnimatedBuilder(
                    animation: _floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: child,
                      );
                    },
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(2, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: config.imageUrl,
                            fit: BoxFit.contain,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                            placeholder: (_, __) => Shimmer.fromColors(
                              baseColor: Colors.white.withValues(alpha: 0.15),
                              highlightColor: Colors.white.withValues(alpha: 0.35),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.shopping_bag_outlined,
                              size: 42,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerConfig {
  final String tag;
  final String headline;
  final String subtext;
  final String ctaText;
  final String imageUrl;
  final List<Color> gradientColors;
  final Color accentColor;

  const _BannerConfig({
    required this.tag,
    required this.headline,
    required this.subtext,
    required this.ctaText,
    required this.imageUrl,
    required this.gradientColors,
    required this.accentColor,
  });
}
