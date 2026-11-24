import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../campaign_bento_models.dart';
import 'campaign_artwork.dart';
import '../../../providers/product_provider.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../core/utils/category_transition_helper.dart';
import '../../../core/theme/responsive.dart';
import '../../../widgets/product_card.dart';

/// Fresh Market ("bloom") Curated Bento Card — 100% Server-Driven:
/// - Background, border, accent, text colors, header image, pill label,
///   title, subtitle, CTA label, destination category & products all come
///   live from [widget.card] (synced via `/api/campaign-bento`).
/// - Product shelf uses the app's real grocery [ProductCard].
class FreshMarketCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const FreshMarketCard({super.key, required this.card});

  @override
  ConsumerState<FreshMarketCard> createState() => _FreshMarketCardState();
}

class _FreshMarketCardState extends ConsumerState<FreshMarketCard> {
  void _navigateToCategory() {
    HapticFeedback.lightImpact();
    final categoriesAsync = ref.read(categoriesProvider);
    final allCats = categoriesAsync.value ?? [];
    final targetSlug = (widget.card.destinationRoute ?? '').trim().toLowerCase();

    Category match;
    if (targetSlug.isNotEmpty) {
      match = allCats.firstWhere(
        (c) =>
            c.slug.toLowerCase() == targetSlug ||
            c.slug.toLowerCase().contains(targetSlug) ||
            c.name.toLowerCase().contains(targetSlug),
        orElse: () => _defaultProduceCategory(allCats),
      );
    } else {
      match = _defaultProduceCategory(allCats);
    }

    CategoryTransitionHelper.pushCategoryWithTransition(
      context,
      ref,
      match,
    );
  }

  Category _defaultProduceCategory(List<Category> allCats) {
    return allCats.firstWhere(
      (c) =>
          c.slug.toLowerCase().contains('fruit') ||
          c.name.toLowerCase().contains('fruit') ||
          c.slug.toLowerCase().contains('veg') ||
          c.name.toLowerCase().contains('veg') ||
          c.slug.toLowerCase().contains('fresh'),
      orElse: () => const Category(
        id: 'CAT-FRUITS',
        name: 'Fruits & Vegetables',
        slug: 'fruits-vegetables',
      ),
    );
  }

  /// Resolves real in-stock grocery [Product] objects for the Bloom shelf.
  /// 1. Matches admin-configured items in [widget.card.items] against live catalog.
  /// 2. Falls back to live Fruits/Vegetables/Fresh produce in catalog.
  /// 3. Backfills with top in-stock grocery staples if produce count is low.
  List<Product> _resolveRealProducts(
    List<Product> catalog,
    List<Category> categories,
  ) {
    final List<Product> resolved = [];
    final Set<String> seenIds = {};
    final Map<String, Product> catalogById = {
      for (final p in catalog) p.id: p,
    };

    bool isEligibleGrocery(Product p) {
      if (!p.isAvailable || p.stock <= 0) return false;
      if (p.restaurantId != null && p.restaurantId!.isNotEmpty) return false;
      if (p.menuSection != null && p.menuSection!.isNotEmpty) return false;
      return true;
    }

    // 1. Prefer real DB products configured by admin in widget.card.items
    for (final item in widget.card.items) {
      final candidate =
          item.realProduct ?? catalogById[item.productId ?? item.id];
      if (candidate != null &&
          isEligibleGrocery(candidate) &&
          seenIds.add(candidate.id)) {
        resolved.add(candidate);
      }
    }
    if (resolved.isNotEmpty) return resolved;

    // 2. Live produce from Fruits & Vegetables / Sabzi / Fresh categories
    final produceCatIds = categories
        .where((c) {
          final key = '${c.name} ${c.slug}'.toLowerCase();
          return key.contains('fruit') ||
              key.contains('veg') ||
              key.contains('sabzi') ||
              key.contains('fresh') ||
              key.contains('dairy');
        })
        .map((c) => c.id)
        .toSet();

    const produceKeywords = [
      'tomato', 'onion', 'potato', 'aloo', 'pyaz', 'tamatar',
      'coriander', 'dhaniya', 'chilli', 'mirch', 'cucumber', 'kheera',
      'mint', 'pudina', 'lemon', 'nimbu', 'ginger', 'adrak', 'garlic', 'lahsun',
      'apple', 'banana', 'mango', 'papaya', 'muskmelon', 'watermelon',
      'spinach', 'palak', 'cauliflower', 'gobhi', 'ladyfinger', 'bhindi',
      'carrot', 'gajar', 'peas', 'matar', 'capsicum', 'shimla', 'brinjal', 'baingan',
    ];

    for (final p in catalog) {
      if (seenIds.contains(p.id) || !isEligibleGrocery(p)) continue;
      final catName =
          '${p.category?.name ?? ''} ${p.category?.slug ?? ''}'.toLowerCase();
      final inProduceCat =
          (p.categoryId != null && produceCatIds.contains(p.categoryId)) ||
              catName.contains('fruit') ||
              catName.contains('veg') ||
              catName.contains('sabzi') ||
              catName.contains('fresh');
      final nameLower = p.name.toLowerCase();
      final matchesKeyword =
          produceKeywords.any((k) => nameLower.contains(k));

      if ((inProduceCat || matchesKeyword) && seenIds.add(p.id)) {
        resolved.add(p);
        if (resolved.length >= 10) return resolved;
      }
    }

    // 3. Backfill with top in-stock grocery products so the shelf is never sparse
    if (resolved.length < 6) {
      for (final p in catalog) {
        if (seenIds.contains(p.id) || !isEligibleGrocery(p)) continue;
        if (seenIds.add(p.id)) {
          resolved.add(p);
          if (resolved.length >= 8) break;
        }
      }
    }

    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final productsToShow = _resolveRealProducts(catalog, categories);

    if (productsToShow.isEmpty) return const SizedBox.shrink();

    final cardWidth = Responsive.productCardShelfWidth(context);
    final shelfHeight = Responsive.productShelfHeight(context);

    // 100% Server-editable palette & copy with crisp botanical defaults
    final bgTop = widget.card.backgroundColor;
    final bgMid = Color.lerp(bgTop, Colors.white, 0.55) ?? const Color(0xFFF3FDF7);
    final borderColor = widget.card.borderColor;
    final accentColor = widget.card.accentColor;
    final textColor = widget.card.textColor;
    final headerImage = (widget.card.heroImage ?? '').trim().isNotEmpty
        ? widget.card.heroImage!.trim()
        : 'bloom-panoramic-header.svg';
    final pillLabel = (widget.card.specialRibbon ?? '').trim().isNotEmpty
        ? widget.card.specialRibbon!.trim()
        : 'FARM FRESH';
    final headerTitle = widget.card.title.trim().isNotEmpty
        ? widget.card.title.trim()
        : 'Fresh Market';
    final headerSubtitle = widget.card.subtitle.trim().isNotEmpty
        ? widget.card.subtitle.trim()
        : 'Handpicked daily farm-fresh essentials';
    final ctaLabel = (widget.card.comboButtonLabel ?? '').trim().isNotEmpty
        ? widget.card.comboButtonLabel!.trim()
        : 'See all fresh picks';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35, 1.0],
          colors: [bgTop, bgMid, Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Server-Editable Panoramic Bloom Header with Soft Blend
          _BloomPanoramicHeader(
            image: headerImage,
            pillLabel: pillLabel,
            title: headerTitle,
            subtitle: headerSubtitle,
            itemCount: productsToShow.length,
            bgTop: bgTop,
            borderColor: borderColor,
            accentColor: accentColor,
            textColor: textColor,
          ),

          const SizedBox(height: 8),

          // 2. Real Grocery ProductCard Horizontal Shelf
          SizedBox(
            height: shelfHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: productsToShow.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
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

          // 3. Server-Editable Footer CTA Bar with Live Product Thumbnails
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 0,
              child: InkWell(
                onTap: _navigateToCategory,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bgMid, Colors.white],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _LiveProductAvatarStack(
                        products: productsToShow,
                        accentColor: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panoramic Branded Bloom Header + Clean Title Strip
// ─────────────────────────────────────────────────────────────────────────────

class _BloomPanoramicHeader extends StatelessWidget {
  final String image;
  final String pillLabel;
  final String title;
  final String subtitle;
  final int itemCount;
  final Color bgTop;
  final Color borderColor;
  final Color accentColor;
  final Color textColor;

  const _BloomPanoramicHeader({
    required this.image,
    required this.pillLabel,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.bgTop,
    required this.borderColor,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 82,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CampaignArtwork(
                image: image,
                width: double.infinity,
                height: 82,
                fit: BoxFit.cover,
              ),
              // Soft bottom gradient to blend artwork seamlessly into the card surface
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgTop.withValues(alpha: 0.0),
                        bgTop,
                      ],
                    ),
                  ),
                ),
              ),
              // Top-Left: Server-Editable Pill Badge
              Positioned(
                top: 8,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: borderColor,
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        size: 11,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        pillLabel.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Top-Right: Item Count Badge
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$itemCount picks',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.35,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.72),
                        height: 1.2,
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlapping Live Product Thumbnails for Footer CTA
// ─────────────────────────────────────────────────────────────────────────────

class _LiveProductAvatarStack extends StatelessWidget {
  final List<Product> products;
  final Color accentColor;

  const _LiveProductAvatarStack({
    required this.products,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final preview = products.take(3).toList();
    if (preview.isEmpty) return const SizedBox.shrink();

    final stackWidth = 22.0 + ((preview.length - 1) * 13.0);
    return SizedBox(
      width: stackWidth,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < preview.length; i++)
            Positioned(
              left: i * 13.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (preview[i].imageUrl != null &&
                          preview[i].imageUrl!.startsWith('http'))
                      ? Image.network(
                          preview[i].imageUrl!,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.eco_rounded,
                            size: 12,
                            color: accentColor,
                          ),
                        )
                      : Icon(
                          Icons.eco_rounded,
                          size: 12,
                          color: accentColor,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
