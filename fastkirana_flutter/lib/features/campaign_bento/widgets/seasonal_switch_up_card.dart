import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../campaign_bento_models.dart';
import 'campaign_artwork.dart';
import '../../../providers/product_provider.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../categories/category_products_screen.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/theme/responsive.dart';
import '../../../widgets/product_card.dart';

class _BeautyTab {
  final String id;
  final String label;
  final String thumbnail;
  final IconData fallbackIcon;
  final List<String> searchKeywords;

  const _BeautyTab({
    required this.id,
    required this.label,
    required this.thumbnail,
    required this.fallbackIcon,
    required this.searchKeywords,
  });
}


/// Sinusoidal Scalloped Top Wave Clipper (Matching Zepto reference top wavy edge)
class _ScallopWaveClipper extends CustomClipper<Path> {
  const _ScallopWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const scallopWidth = 14.0;
    const scallopHeight = 5.0;
    final count = (size.width / scallopWidth).round();
    final step = size.width / count;

    path.moveTo(0, scallopHeight);
    for (int i = 0; i < count; i++) {
      final startX = i * step;
      final midX = startX + (step / 2);
      final endX = (i + 1) * step;
      path.quadraticBezierTo(midX, -2, endX, scallopHeight);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Continuous Connected Tab Painter matching Zepto's sculpted organic outline.
/// Uses pure C1/G2 continuous liquid cubic fillets and squircle curves to eliminate any sharp edges.
class _ConnectedTabPainter extends CustomPainter {
  final double x;
  final double width;
  final double radius;
  final Color color;
  final Color fill;
  final double lineWidth;

  const _ConnectedTabPainter({
    required this.x,
    required this.width,
    required this.radius,
    required this.color,
    required this.fill,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 1.0;
    const filletR = 28.0; // Deep, flowing liquid concave shoulder curve connecting to baseline
    final topR = radius.clamp(20.0, 32.0); // Generous liquid convex squircle curve at the top
    const top = 1.0;
    const k = 0.55228475; // Standard circular arc kappa factor
    const invK = 1.0 - k; // 0.44771525

    final tabLeft = x;
    final tabRight = x + width;

    final path = Path();
    path.moveTo(0, bottom);

    // Adaptive liquid left fillet (gracefully scales if tab is near or at the left margin)
    final effectiveLeftFillet = math.min(filletR, tabLeft).clamp(8.0, filletR);
    final leftScoopStartX = math.max(0.0, tabLeft - effectiveLeftFillet);

    // 1. Baseline up to left liquid scoop
    if (leftScoopStartX > 0) {
      path.lineTo(leftScoopStartX, bottom);
    }

    // 2. Liquid Concave bottom-left scoop (identical mirror of the bottom-right scoop)
    path.cubicTo(
      leftScoopStartX + (effectiveLeftFillet * k),
      bottom,
      tabLeft,
      (bottom - effectiveLeftFillet) + (effectiveLeftFillet * invK),
      tabLeft,
      bottom - effectiveLeftFillet,
    );

    // 3. Left vertical wall
    path.lineTo(tabLeft, top + topR);

    // 4. Liquid Convex top-left rounded squircle corner
    path.cubicTo(
      tabLeft,
      top + (topR * invK),
      tabLeft + (topR * invK),
      top,
      tabLeft + topR,
      top,
    );

    // 5. Top horizontal line across tab
    path.lineTo(tabRight - topR, top);

    // 6. Liquid Convex top-right rounded squircle corner
    path.cubicTo(
      tabRight - (topR * invK),
      top,
      tabRight,
      top + (topR * invK),
      tabRight,
      top + topR,
    );

    // 7. Right vertical wall
    path.lineTo(tabRight, bottom - filletR);

    // 8. Liquid Concave bottom-right scoop (molten meniscus flare-out into baseline with G2 continuity)
    path.cubicTo(
      tabRight,
      (bottom - filletR) + (filletR * k),
      (tabRight + filletR) - (filletR * k),
      bottom,
      tabRight + filletR,
      bottom,
    );

    // 9. Baseline to the right edge
    path.lineTo(size.width, bottom);

    // Fill path extends down to enclose the active tab shape
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Soft subtle ambient glow for the active pill
    final shadowPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, shadowPaint);

    // Solid fill
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, fillPaint);

    // Antialiased stroke with round joints for pure liquid smoothness
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_ConnectedTabPainter old) =>
      old.x != x ||
      old.width != width ||
      old.radius != radius ||
      old.color != color ||
      old.fill != fill ||
      old.lineWidth != lineWidth;
}

/// The Seasonal Switch-Up Thematic Zone (Matching Zepto Winter & Personal Care reference)
class SeasonalSwitchUpCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const SeasonalSwitchUpCard({super.key, required this.card});

  @override
  ConsumerState<SeasonalSwitchUpCard> createState() => _SeasonalSwitchUpCardState();
}

class _SeasonalSwitchUpCardState extends ConsumerState<SeasonalSwitchUpCard> {
  String _selectedTabId = 'body-lotions';
  final ScrollController _tabScrollController = ScrollController();

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  void _onTabTapped(String tabId, int index, double tabWidth) {
    HapticFeedback.selectionClick();
    setState(() => _selectedTabId = tabId);
    if (_tabScrollController.hasClients) {
      final target = (index * tabWidth - tabWidth).clamp(
        0.0,
        _tabScrollController.position.maxScrollExtent,
      );
      _tabScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static const List<_BeautyTab> _tabs = [
    _BeautyTab(
      id: 'body-lotions',
      label: 'Body\nLotions',
      thumbnail: 'body.png',
      fallbackIcon: Icons.clean_hands_rounded,
      searchKeywords: ['body lotion', 'vaseline lotion', 'nivea body milk', 'cetaphil dam', 'body milk', 'body butter'],
    ),
    _BeautyTab(
      id: 'face-moisturizers',
      label: 'Face\nMoisturizers',
      thumbnail: 'face.png',
      fallbackIcon: Icons.spa_rounded,
      searchKeywords: ['face moisturizer', 'ponds super light', 'cold cream', 'dot & key ceramide', 'face cream', 'hydrating face', 'day cream', 'night cream'],
    ),
    _BeautyTab(
      id: 'lip-balm',
      label: 'Lip\nBalm',
      thumbnail: 'lip.png',
      fallbackIcon: Icons.face_retouching_natural_rounded,
      searchKeywords: ['lip balm', 'nivea lip', 'vaseline lip therapy', 'gloss boss', 'lip care', 'chapstick'],
    ),
    _BeautyTab(
      id: 'hair-care',
      label: 'Hair\nCare',
      thumbnail: 'hair.png',
      fallbackIcon: Icons.brush_rounded,
      searchKeywords: ['hair oil', 'hair serum', 'shampoo', 'parachute advansed', 'loreal shampoo', 'conditioner', 'hair spa'],
    ),
    _BeautyTab(
      id: 'lip-mask',
      label: 'Lip\nMasks',
      thumbnail: 'lip.png',
      fallbackIcon: Icons.favorite_rounded,
      searchKeywords: ['lip mask', 'laneige lip', 'sleeping mask', 'lip sleeping'],
    ),
  ];


  void _onSeeAllPressed(BuildContext context) {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final match = categories.firstWhere(
      (c) =>
          c.slug.toLowerCase().contains('beauty') ||
          c.slug.toLowerCase().contains('personal') ||
          c.name.toLowerCase().contains('beauty'),
      orElse: () => const Category(
        id: 'cat-beauty-care',
        name: 'Beauty & Personal Care',
        slug: 'beauty-personal-care',
      ),
    );

    Navigator.push(
      context,
      FadeSlideRoute(page: CategoryProductsScreen(category: match)),
    );
  }

  /// Resolve 100% real in-stock database products for the active tab (no fake curated fallback)
  List<Product> _resolveRealProductsForTab(
    String tabId,
    List<Product> catalog,
    List<Category> categories,
  ) {
    final currentTab = _tabs.firstWhere((t) => t.id == tabId, orElse: () => _tabs.first);
    final keywords = currentTab.searchKeywords;

    const excludedFoodKeywords = [
      'soup', 'shake', 'curry', 'paneer', 'roti', 'biryani', 'dal', 'gravy',
      'snack', 'drink', 'beverage', 'tea', 'coffee', 'ice cream', 'cake',
      'pizza', 'burger', 'sandwich', 'pasta', 'momo', 'roll', 'salad bowl',
      'thali', 'khichdi', 'chawal', 'rice', 'mustard', 'soyabean', 'refined',
      'ghee', 'atta', 'flour', 'spices', 'masala', 'noodles', 'maggi',
    ];

    bool isEligibleGrocery(Product p) {
      if (!p.isAvailable || p.stock <= 0) return false;
      if (p.restaurantId != null && p.restaurantId!.isNotEmpty) return false;
      if (p.menuSection != null && p.menuSection!.isNotEmpty) return false;
      final nameLower = p.name.toLowerCase();
      return !excludedFoodKeywords.any((food) => nameLower.contains(food));
    }

    final List<Product> result = [];
    final Set<String> seenIds = {};

    // 0. Strictly prefer real items explicitly configured by admin in widget.card.items
    for (final item in widget.card.items) {
      final rp = item.realProduct;
      if (rp != null && rp.isAvailable && rp.stock > 0 && seenIds.add(rp.id)) {
        result.add(rp);
      }
    }
    if (result.isNotEmpty) return result;

    // 1. Exact keyword matches for this tab
    for (final p in catalog) {
      if (!isEligibleGrocery(p)) continue;
      final nameLower = p.name.toLowerCase();
      final tagMatch = p.tags.any((t) => keywords.any((k) => t.toLowerCase().contains(k)));
      final nameMatch = keywords.any((k) => nameLower.contains(k));
      if ((tagMatch || nameMatch) && seenIds.add(p.id)) {
        result.add(p);
        if (result.length >= 8) return result;
      }
    }

    // 2. Backfill from Beauty / Personal Care / Skincare / Grooming category in real DB
    final beautyCatIds = categories
        .where((c) {
          final key = '${c.name} ${c.slug}'.toLowerCase();
          return key.contains('beauty') ||
              key.contains('personal') ||
              key.contains('skin') ||
              key.contains('hair') ||
              key.contains('groom') ||
              key.contains('care') ||
              key.contains('cosmetic');
        })
        .map((c) => c.id)
        .toSet();

    for (final p in catalog) {
      if (seenIds.contains(p.id) || !isEligibleGrocery(p)) continue;
      final catKey = '${p.category?.name ?? ''} ${p.category?.slug ?? ''}'.toLowerCase();
      final inBeautyCat = (p.categoryId != null && beautyCatIds.contains(p.categoryId)) ||
          catKey.contains('beauty') ||
          catKey.contains('personal') ||
          catKey.contains('skin') ||
          catKey.contains('hair') ||
          catKey.contains('care');
      if (inBeautyCat && seenIds.add(p.id)) {
        result.add(p);
        if (result.length >= 8) break;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final productsToShow = _resolveRealProductsForTab(_selectedTabId, catalog, categories);
    if (productsToShow.isEmpty) return const SizedBox.shrink();
    final cardWidth = Responsive.productCardShelfWidth(context);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD6EEFF),
            Color(0xFFE9F5FF),
            Color(0xFFF7FBFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC0E2FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Scalloped Wavy Top Bar with Gradient Background
          ClipPath(
            clipper: const _ScallopWaveClipper(),
            child: Container(
              height: 10,
              width: double.infinity,
              color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 10),

          // Header Title: "The Seasonal Switch-Up"
          Center(
            child: Text(
              'The Seasonal Switch-Up',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E3A8A), // Deep navy
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Co-Sponsor Subtitle with Symmetrical Flourish Dividers:
          // ❄️ ─── POWERED BY [Cetaphil] DOT & KEY ─── ❄️
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('❄️', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Container(
                      width: 18,
                      height: 1.2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x0060A5FA), Color(0xFF60A5FA)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'POWERED BY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E40AF),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Cetaphil Logo Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0060A9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Cetaphil',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DOT & KEY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E3A8A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 18,
                      height: 1.2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0x0060A5FA)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('❄️', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. Sub-Category Tabs with Continuous Connected Liquid Outline Painter
          LayoutBuilder(
            builder: (context, constraints) {
              const tabWidth = 98.0;
              const tabHeight = 116.0;
              const sidePadding = 36.0;
              final fullWidth = math.max(
                constraints.maxWidth,
                sidePadding * 2 + (tabWidth * _tabs.length),
              );
              final activeIdx = _tabs.indexWhere((t) => t.id == _selectedTabId);
              final selectedIdx = activeIdx >= 0 ? activeIdx : 0;
              final targetX = sidePadding + (selectedIdx * tabWidth);

              return SingleChildScrollView(
                controller: _tabScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: fullWidth,
                  height: tabHeight,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.fastOutSlowIn,
                    tween: Tween<double>(end: targetX),
                    builder: (context, animX, child) => CustomPaint(
                      painter: _ConnectedTabPainter(
                        x: animX,
                        width: tabWidth,
                        radius: 28,
                        color: const Color(0xFF93C5FD),
                        fill: const Color(0xFFEAF5FF),
                        lineWidth: 1.4,
                      ),
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _tabs.length; i++) ...[
                            _buildTabItem(_tabs[i], _tabs[i].id == _selectedTabId, i, tabWidth, tabHeight),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. Horizontal Product Shelf (Directly connected to active tab above)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(
                left: BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                right: BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                bottom: BorderSide(color: Color(0xFF93C5FD), width: 1.2),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Smooth AnimatedSwitcher for Product Shelf Transitions
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTabId),
                    child: SizedBox(
                      height: Responsive.productShelfHeight(context),
                      child: ListView.separated(
                        key: PageStorageKey('ssu-shelf-$_selectedTabId'),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: productsToShow.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final product = productsToShow[index];
                          return SizedBox(
                            width: cardWidth,
                            child: ProductCard(
                              product: product,
                              width: cardWidth,
                              showOutlet: false,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 4. Bottom Footer CTA Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    child: InkWell(
                      onTap: () => _onSeeAllPressed(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        child: Row(
                          children: [
                            // Overlapping Circular Product Avatars
                            const SizedBox(
                              width: 58,
                              height: 28,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0,
                                    child: _AvatarCircle(image: 'body.png', icon: Icons.clean_hands_rounded),
                                  ),
                                  Positioned(
                                    left: 15,
                                    child: _AvatarCircle(image: 'face.png', icon: Icons.spa_rounded),
                                  ),
                                  Positioned(
                                    left: 30,
                                    child: _AvatarCircle(image: 'lip.png', icon: Icons.favorite_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'See all products',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Color(0xFF1E3A8A),
                            ),
                          ],
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

  Widget _buildTabItem(_BeautyTab tab, bool isSelected, int index, double tabWidth, double tabHeight) {
    return GestureDetector(
      onTap: () => _onTabTapped(tab.id, index, tabWidth),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tabWidth,
        height: tabHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular Thumbnail Avatar with smooth animated highlight ring & soft shadow
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFBFDBFE),
                    width: isSelected ? 2.2 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: CampaignArtwork(
                    image: tab.thumbnail,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    fallbackIcon: tab.fallbackIcon,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  height: 1.15,
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String image;
  final IconData icon;

  const _AvatarCircle({required this.image, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: CampaignArtwork(
          image: image,
          width: 26,
          height: 26,
          fit: BoxFit.cover,
          fallbackIcon: icon,
        ),
      ),
    );
  }
}
