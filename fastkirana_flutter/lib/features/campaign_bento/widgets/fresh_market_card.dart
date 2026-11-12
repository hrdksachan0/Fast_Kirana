import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../campaign_bento_models.dart';
import '../campaign_bento_provider.dart';
import 'campaign_artwork.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../categories/category_products_screen.dart';
import '../../../core/routes/page_transitions.dart';

/// Thematic Curated Bento Card matching Zepto's signature "bloom" archetype:
/// - Full panoramic summer fruit skyline banner with cloud typography ("bloom")
/// - Soft sky-blue card surface with 24px curvature
/// - 3-Card horizontal peeking carousel with "select >" bronze badge, wishlist heart, and floating pink '+' button
/// - Full-width rounded "See All ▸" footer button routing directly to Fruits & Vegetables category
class FreshMarketCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const FreshMarketCard({super.key, required this.card});

  @override
  ConsumerState<FreshMarketCard> createState() => _FreshMarketCardState();
}

class _FreshMarketCardState extends ConsumerState<FreshMarketCard> {
  void _increment(CampaignBentoItemConfig item) {
    HapticFeedback.lightImpact();
    ref.read(campaignBentoProvider.notifier).addItemToCart(item, quantity: 1);
  }

  void _decrement(CampaignBentoItemConfig item) {
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).decrement(item.id);
  }

  void _navigateToCategory() {
    HapticFeedback.lightImpact();
    final categoriesAsync = ref.read(categoriesProvider);
    final allCats = categoriesAsync.value ?? [];
    final match = allCats.firstWhere(
      (c) =>
          c.slug.toLowerCase().contains('fruit') ||
          c.name.toLowerCase().contains('fruit') ||
          c.slug.toLowerCase().contains('veg') ||
          c.name.toLowerCase().contains('veg'),
      orElse: () => const Category(
        id: 'CAT-FRUITS',
        name: 'Fruits & Vegetables',
        slug: 'fruits-vegetables',
      ),
    );

    Navigator.push(
      context,
      FadeSlideRoute(page: CategoryProductsScreen(category: match)),
    );
  }

  List<CampaignBentoItemConfig> _resolveBloomItems(
    List<Product> catalog,
    List<Category> categories,
  ) {
    final List<CampaignBentoItemConfig> resolved = [];
    final Set<String> seenIds = {};

    // 1. Strictly show products configured by admin in widget.card.items
    for (final item in widget.card.items) {
      if (seenIds.add(item.id)) {
        resolved.add(item);
      }
    }

    // If admin has configured items, strictly return ONLY those items!
    if (resolved.isNotEmpty) {
      return resolved;
    }

    // 2. Only if no items are configured, fallback to live Ghatampur catalog produce
    final produceCatIds = categories
        .where((c) {
          final key = '${c.name} ${c.slug}'.toLowerCase();
          return key.contains('fruit') ||
              key.contains('veg') ||
              key.contains('sabzi') ||
              key.contains('fresh');
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

    final matches = catalog.where((p) {
      if (seenIds.contains(p.id)) return false;
      if (!p.isAvailable || p.stock <= 0) return false;
      if (p.restaurantId != null && p.restaurantId!.isNotEmpty) return false;
      if (p.menuSection != null && p.menuSection!.isNotEmpty) return false;

      final catName = '${p.category?.name ?? ''} ${p.category?.slug ?? ''}'.toLowerCase();
      final inProduceCat = (p.categoryId != null && produceCatIds.contains(p.categoryId)) ||
          catName.contains('fruit') ||
          catName.contains('veg') ||
          catName.contains('sabzi');
      if (inProduceCat) return true;

      final nameLower = p.name.toLowerCase();
      return produceKeywords.any((k) => nameLower.contains(k));
    });

    for (final p in matches) {
      if (resolved.length >= 8) break;
      seenIds.add(p.id);
      final double mrp = p.mrp > p.price ? p.mrp : 0;
      String? discountTag;
      if (mrp > p.price) {
        final saved = (mrp - p.price).round();
        if (saved > 0) discountTag = '₹$saved OFF';
      }
      resolved.add(CampaignBentoItemConfig(
        id: p.id,
        productId: p.id,
        realProduct: p,
        name: p.name,
        weight: p.unit.isNotEmpty ? p.unit : '500 g',
        price: p.price,
        originalPrice: mrp > p.price ? mrp : null,
        discountTag: discountTag,
        image: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
            ? p.imageUrl!
            : 'ref-fresh-tomato.png',
      ));
    }

    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isStoreOpen = settings?.groceryMartOpen ?? true;
    final catalog = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final displayItems = _resolveBloomItems(catalog, categories);

    if (displayItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2EFFF),
            Color(0xFFEFF6FF),
            Color(0xFFF4F9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFE4FD), width: 1.2),
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
          // 1. Panoramic Branded Summer Fruit Header ("bloom")
          const _BloomPanoramicHeader(),

          const SizedBox(height: 12),

          // 2. Horizontal 3-Product Shelf Carousel
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _ThematicProductCard(
                  item: item,
                  isStoreOpen: isStoreOpen,
                  onAdd: () => _increment(item),
                  onIncrement: () => _increment(item),
                  onDecrement: () => _decrement(item),
                );
              },
            ),
          ),

          // 3. Wide Full-Width "See All ▸" Footer Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: InkWell(
              onTap: _navigateToCategory,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ],
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
// Panoramic Branded Header (Fruit Skyline + Cloud Typography)
// ─────────────────────────────────────────────────────────────────────────────

class _BloomPanoramicHeader extends StatelessWidget {
  const _BloomPanoramicHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Vector SVG Header Art (Pineapple, Orange, Dragonfruit, Lime & Sky)
          const CampaignArtwork(
            image: 'bloom-panoramic-header.svg',
            width: double.infinity,
            height: 114,
            fit: BoxFit.cover,
          ),

          // 2. Fallback / Enhancing Cloud Typography "bloom"
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'bloom',
                style: GoogleFonts.quicksand(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.2,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    ),
                  ],
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
// Exact Replica Product Tile (Zepto "bloom" specification)
// ─────────────────────────────────────────────────────────────────────────────

class _ThematicProductCard extends ConsumerWidget {
  final CampaignBentoItemConfig item;
  final bool isStoreOpen;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ThematicProductCard({
    required this.item,
    required this.isStoreOpen,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).value;
    final inCartQty = cart?.items
            .where((i) => i.productId == item.id || i.productId.startsWith('${item.id}_'))
            .fold<int>(0, (sum, i) => sum + i.quantity) ??
        0;

    final origPrice = item.originalPrice ?? (item.price * 1.35).roundToDouble();
    final discountAmount = (origPrice > item.price) ? (origPrice - item.price).round() : 0;

    return Container(
      width: 122,
      padding: const EdgeInsets.all(7.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Photo Container with "select >" badge, Heart & Floating Action Pill
          Container(
            height: 98,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Product Cutout Image
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CampaignArtwork(
                      image: item.effectiveImage,
                      width: 82,
                      height: 82,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Top-Left: Signature "select >" Pill Badge
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F), // Rich warm bronze from reference
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'select',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 1.5),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Right: Wishlist Heart Icon
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),

                // Bottom-Right: Signature Floating Action Pill (Pink '+' / Stepper / Closed)
                Positioned(
                  bottom: -6,
                  right: 4,
                  child: !isStoreOpen
                      ? GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'FastMinute Grocery Darkstore is currently closed at this hour.',
                                        style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF0F172A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 10.5, color: Color(0xFF64748B)),
                                SizedBox(width: 2.5),
                                Text(
                                  'CLOSED',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : item.isOutOfStock
                          ? Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.0),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'OUT',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            )
                          : inCartQty > 0
                          ? Container(
                              height: 27,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDB2777), // Pink/Rose from screenshot
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDB2777).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: onDecrement,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2.5),
                                      child: Icon(Icons.remove, size: 13, color: Colors.white),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: Text(
                                      '$inCartQty',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: onIncrement,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2.5),
                                      child: Icon(Icons.add, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: onAdd,
                              child: Container(
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDB2777), // Pink/Rose border from screenshot
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add,
                                    size: 22,
                                    color: Color(0xFFDB2777),
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Price Row: Solid Green Pill + Strike MRP
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A), // Solid green badge from screenshot
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '₹${item.price.toInt()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (origPrice > item.price) ...[
                const SizedBox(width: 4),
                Text(
                  '₹${origPrice.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),

          // 3. Discount Text: e.g. "₹22 OFF"
          if (discountAmount > 0)
            Text(
              '₹$discountAmount OFF',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
              ),
            ),
          const SizedBox(height: 3),

          // 4. Title (2-Lines max)
          SizedBox(
            height: 28,
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // 5. Weight / Unit
          Text(
            item.weight.isNotEmpty ? item.weight : '1 pc',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
