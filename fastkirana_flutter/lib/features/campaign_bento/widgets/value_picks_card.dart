import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../campaign_bento_models.dart';
import '../../../data/models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';

/// A curated Value Product variant
class ValueProduct {
  final String id;
  final String name;
  final String packLabel;
  final double price;
  final String unitPriceLabel;
  final int artIndex;
  final String? imageUrl;
  final bool isBetterValue;
  final Product? realProduct;

  const ValueProduct({
    required this.id,
    required this.name,
    required this.packLabel,
    required this.price,
    required this.unitPriceLabel,
    this.artIndex = 0,
    this.imageUrl,
    this.isBetterValue = false,
    this.realProduct,
  });

  Product toProduct() {
    if (realProduct != null) return realProduct!;
    return Product(
      id: id,
      name: name,
      slug: id,
      description: packLabel,
      imageUrl: imageUrl ?? 'assets/navratri/essentials-atlas.jpg',
      mrp: price * 1.25,
      price: price,
      discount: isBetterValue ? 20.0 : 10.0,
      unit: packLabel,
      stock: 99,
      isAvailable: true,
      tags: const ['campaign', 'value_picks'],
      minStock: 1,
      costPrice: price * 0.8,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    );
  }
}

/// A comparison pair of standard pack vs value bulk pack
class ValuePair {
  final String id;
  final ValueProduct left;
  final ValueProduct right;
  final String savingLabel;

  const ValuePair({
    required this.id,
    required this.left,
    required this.right,
    required this.savingLabel,
  });

  List<ValueProduct> get products => [left, right];
}

/// Standard 5 pairs mirroring FastMinute Value Picks
const List<ValuePair> _defaultPairs = [
  ValuePair(
    id: 'atta',
    left: ValueProduct(
      id: 'vp-atta1',
      name: 'Whole wheat atta',
      packLabel: '1 kg',
      price: 60.0,
      unitPriceLabel: '₹60 / kg',
      artIndex: 0,
    ),
    right: ValueProduct(
      id: 'vp-atta5',
      name: 'Whole wheat atta',
      packLabel: '5 kg',
      price: 250.0,
      unitPriceLabel: '₹50 / kg',
      artIndex: 0,
      isBetterValue: true,
    ),
    savingLabel: 'Save ₹50 when you pick the 5 kg pack',
  ),
  ValuePair(
    id: 'rice',
    left: ValueProduct(
      id: 'vp-rice1',
      name: 'Basmati rice',
      packLabel: '1 kg',
      price: 99.0,
      unitPriceLabel: '₹99 / kg',
      artIndex: 1,
    ),
    right: ValueProduct(
      id: 'vp-rice5',
      name: 'Basmati rice',
      packLabel: '5 kg',
      price: 450.0,
      unitPriceLabel: '₹90 / kg',
      artIndex: 1,
      isBetterValue: true,
    ),
    savingLabel: 'Save ₹45 when you pick the 5 kg pack',
  ),
  ValuePair(
    id: 'oil',
    left: ValueProduct(
      id: 'vp-oil05',
      name: 'Sunflower oil',
      packLabel: '500 ml',
      price: 85.0,
      unitPriceLabel: '₹170 / litre',
      artIndex: 2,
    ),
    right: ValueProduct(
      id: 'vp-oil1',
      name: 'Sunflower oil',
      packLabel: '1 litre',
      price: 160.0,
      unitPriceLabel: '₹160 / litre',
      artIndex: 2,
      isBetterValue: true,
    ),
    savingLabel: 'Save ₹10 when you pick the 1 litre bottle',
  ),
  ValuePair(
    id: 'sugar',
    left: ValueProduct(
      id: 'vp-sugar1',
      name: 'Refined sugar',
      packLabel: '1 kg',
      price: 48.0,
      unitPriceLabel: '₹48 / kg',
      artIndex: 3,
    ),
    right: ValueProduct(
      id: 'vp-sugar5',
      name: 'Refined sugar',
      packLabel: '5 kg',
      price: 225.0,
      unitPriceLabel: '₹45 / kg',
      artIndex: 3,
      isBetterValue: true,
    ),
    savingLabel: 'Save ₹15 when you pick the 5 kg pack',
  ),
  ValuePair(
    id: 'dal',
    left: ValueProduct(
      id: 'vp-dal05',
      name: 'Arhar dal',
      packLabel: '500 g',
      price: 70.0,
      unitPriceLabel: '₹140 / kg',
      artIndex: 4,
    ),
    right: ValueProduct(
      id: 'vp-dal1',
      name: 'Arhar dal',
      packLabel: '1 kg',
      price: 130.0,
      unitPriceLabel: '₹130 / kg',
      artIndex: 4,
      isBetterValue: true,
    ),
    savingLabel: 'Save ₹10 when you pick the 1 kg pack',
  ),
];

/// The Value Picks Bento Zone Card
class ValuePicksCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const ValuePicksCard({super.key, required this.card});

  @override
  ConsumerState<ValuePicksCard> createState() => _ValuePicksCardState();
}

class _ValuePicksCardState extends ConsumerState<ValuePicksCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pages;
  late final AnimationController _clock;
  late int _rawPage;
  Timer? _holdTimer;
  bool _holding = false;
  bool _touching = false;
  bool _dragging = false;
  bool _hovering = false;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  bool _animating = false;
  bool _foreground = true;

  List<ValuePair> _cachedPairs = const [];
  List<ValuePair> get _pairs => _cachedPairs;

  ValueProduct _fromRealProduct(Product p, {bool isBetterValue = false, String? unitLabel}) {
    final mrpSaved = (p.mrp > p.price) ? (p.mrp - p.price).round() : 0;
    final label = unitLabel ??
        (mrpSaved > 0 ? 'Save ₹$mrpSaved' : (p.unit.isNotEmpty ? p.unit : 'Best value'));
    return ValueProduct(
      id: p.id,
      name: p.name,
      packLabel: p.unit.isNotEmpty ? p.unit : '1 pc',
      price: p.price,
      unitPriceLabel: label,
      imageUrl: p.imageUrl,
      isBetterValue: isBetterValue,
      realProduct: p,
    );
  }

  List<ValuePair> _resolveRealPairs(List<Product> catalog) {
    final List<ValuePair> pairs = [];
    final Set<String> usedIds = {};

    // 1. Prefer real DB-linked items from /api/campaign-bento
    final linked = widget.card.items
        .where((i) => i.realProduct != null && i.realProduct!.isAvailable && i.realProduct!.stock > 0)
        .toList();
    for (int i = 0; i + 1 < linked.length && pairs.length < 5; i += 2) {
      final l = linked[i].realProduct!;
      final r = linked[i + 1].realProduct!;
      if (!usedIds.add(l.id) || !usedIds.add(r.id)) continue;
      final saved = ((r.mrp > r.price ? r.mrp - r.price : 0) + (l.mrp > l.price ? l.mrp - l.price : 0)).round();
      pairs.add(ValuePair(
        id: 'linked-${l.id}-${r.id}',
        left: _fromRealProduct(l, unitLabel: linked[i].unitPriceComparison),
        right: _fromRealProduct(r, isBetterValue: true, unitLabel: linked[i + 1].unitPriceComparison),
        savingLabel: saved > 0 ? 'Save ₹$saved on this value combo' : 'Great value pack comparison',
      ));
    }
    // If admin has configured value pick pairs, strictly show only those pairs!
    if (pairs.isNotEmpty) return pairs;

    // Check if configured card items have fallback items
    if (widget.card.items.length >= 2) {
      for (int i = 0; i + 1 < widget.card.items.length; i += 2) {
        final it1 = widget.card.items[i];
        final it2 = widget.card.items[i + 1];
        pairs.add(ValuePair(
          id: 'bento-${it1.id}-${it2.id}',
          left: ValueProduct(
            id: it1.id,
            name: it1.name,
            packLabel: it1.weight,
            price: it1.price,
            unitPriceLabel: it1.unitPriceComparison ?? it1.weight,
            imageUrl: it1.effectiveImage,
          ),
          right: ValueProduct(
            id: it2.id,
            name: it2.name,
            packLabel: it2.weight,
            price: it2.price,
            unitPriceLabel: it2.unitPriceComparison ?? it2.weight,
            imageUrl: it2.effectiveImage,
          ),
          savingLabel: 'Great value pack comparison',
        ));
      }
      if (pairs.isNotEmpty) return pairs;
    }

    // 2. Only if no items are configured, fallback to auto-pair from catalog
    final grocery = catalog.where((p) {
      if (usedIds.contains(p.id)) return false;
      if (!p.isAvailable || p.stock <= 0 || p.price <= 0) return false;
      if (p.restaurantId != null && p.restaurantId!.isNotEmpty) return false;
      if (p.menuSection != null && p.menuSection!.isNotEmpty) return false;
      return true;
    }).toList();

    // Group by categoryId to pair comparable items (smaller price left, bigger/value pack right)
    final Map<String, List<Product>> byCat = {};
    for (final p in grocery) {
      final key = p.categoryId ?? 'general';
      byCat.putIfAbsent(key, () => []).add(p);
    }

    for (final entry in byCat.entries) {
      if (pairs.length >= 5) break;
      final list = entry.value;
      if (list.length < 2) continue;
      list.sort((a, b) => a.price.compareTo(b.price));
      for (int i = 0; i + 1 < list.length && pairs.length < 5; i += 2) {
        final l = list[i];
        final r = list[i + 1];
        if (!usedIds.add(l.id) || !usedIds.add(r.id)) continue;
        final saved = (r.mrp > r.price ? (r.mrp - r.price).round() : 0);
        pairs.add(ValuePair(
          id: 'cat-${l.id}-${r.id}',
          left: _fromRealProduct(l),
          right: _fromRealProduct(r, isBetterValue: true),
          savingLabel: saved > 0
              ? 'Save ₹$saved when you pick ${r.name}'
              : 'Compare & pick the best value pack',
        ));
      }
    }

    return pairs.isNotEmpty ? pairs : _defaultPairs;
  }
  int get _index => _pairs.isEmpty ? 0 : _rawPage % _pairs.length;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canPlay =>
      !_isTest &&
      _pairs.length > 1 &&
      _foreground &&
      _tickerEnabled &&
      !_reduceMotion &&
      !_holding &&
      !_touching &&
      !_dragging &&
      !_hovering &&
      !_animating;

  @override
  void initState() {
    super.initState();
    _rawPage = 5000;
    _pages = PageController(initialPage: _rawPage);
    _foreground = (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _canPlay) {
          unawaited(_turnPage(1));
        }
      });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncClock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
  }

  void _syncClock() {
    if (!mounted) return;
    if (_canPlay) {
      if (_clock.value >= 1) _clock.value = 0;
      _clock.forward();
    } else {
      _clock.stop(canceled: false);
    }
  }

  void _hold() {
    _holdTimer?.cancel();
    _holding = true;
    _clock.reset();
    _holdTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      _holding = false;
      _syncClock();
    });
  }

  Future<void> _turnPage(int delta, {bool manual = false}) async {
    if (manual) _hold();
    if (!mounted || _animating || !_pages.hasClients || _pairs.length < 2 || delta == 0) return;
    _animating = true;
    _clock.stop(canceled: false);
    final target = math.max(0, _rawPage + delta);
    try {
      if (_reduceMotion) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      if (mounted) {
        _animating = false;
        _clock.reset();
        _syncClock();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _pages.dispose();
    _clock.dispose();
    super.dispose();
  }

  int _quantityFor(String id) {
    final cart = ref.watch(cartProvider).value;
    if (cart == null) return 0;
    for (final item in cart.items) {
      if (item.productId == id || item.product.id == id) {
        return item.quantity;
      }
    }
    return 0;
  }

  void _onQuantityChanged(ValueProduct product, int newQty) {
    HapticFeedback.lightImpact();
    _hold();
    final notifier = ref.read(cartProvider.notifier);
    final currentQty = _quantityFor(product.id);

    if (newQty <= 0) {
      notifier.decrement(product.id);
    } else if (currentQty == 0) {
      notifier.addProduct(product.toProduct(), newQty);
    } else if (newQty > currentQty) {
      notifier.increment(product.toProduct());
    } else {
      notifier.decrement(product.id);
    }
  }

  void _showAllProductsSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    _hold();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFEF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All Value Picks',
                        style: TextStyle(
                          fontFamily: 'NotoSerif',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF29422F),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, color: Color(0xFF89917C)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final allProducts = _pairs.expand((p) => p.products).toList();
                      return ListView.separated(
                        itemCount: allProducts.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFEAECE0)),
                        itemBuilder: (context, index) {
                          final prod = allProducts[index];
                          final qty = _quantityFor(prod.id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox.square(
                                  dimension: 52,
                                  child: ProductArtwork(product: prod),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod.name,
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF29422F),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${prod.packLabel} · ₹${prod.price.toInt()} (${prod.unitPriceLabel})',
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 11,
                                          color: Color(0xFF89917C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 88,
                                  child: ValueQuantityButton(
                                    product: prod,
                                    quantity: qty,
                                    onChanged: (q) => _onQuantityChanged(prod, q),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    _cachedPairs = _resolveRealPairs(catalog);
    if (_cachedPairs.isEmpty) return const SizedBox.shrink();

    const butter = Color(0xFFF9EFB6);
    const borderColor = Color(0xFFF0E3A2);
    const ink = Color(0xFF29422F);
    const green = Color(0xFF365B38);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: butter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCA8A04).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Compact Header Row (Single-row layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 10, color: Color(0xFFFFF6C7)),
                        SizedBox(width: 3.5),
                        Text(
                          'VALUE PICKS',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Color(0xFFFFF6C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Compare & Save',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showAllProductsSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5D895), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 13, color: ink),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Carousel of paired cards (Balanced proportion & zero overlap)
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 8) / 2;
            final textScale = math.max(1.0, MediaQuery.textScalerOf(context).scale(13) / 13);
            final height = (cardWidth - 14) / 1.42 + 132 + (textScale - 1) * 35;

            return MouseRegion(
              onEnter: (_) {
                _hovering = true;
                _syncClock();
              },
              onExit: (_) {
                _hovering = false;
                _syncClock();
              },
              child: Listener(
                onPointerDown: (_) {
                  _touching = true;
                  _hold();
                },
                onPointerUp: (_) {
                  _touching = false;
                  _hold();
                },
                onPointerCancel: (_) {
                  _touching = false;
                  _syncClock();
                },
                child: SizedBox(
                  height: height,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _dragging = true;
                        _hold();
                      }
                      if (notification is ScrollEndNotification) {
                        _dragging = false;
                        _syncClock();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      key: const ValueKey('value-carousel'),
                      controller: _pages,
                      onPageChanged: (raw) {
                        setState(() => _rawPage = raw);
                        _clock.reset();
                      },
                      itemBuilder: (context, raw) {
                        final pair = _pairs[raw % _pairs.length];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              if (i == 1) const SizedBox(width: 8),
                              Expanded(
                                child: ValueProductCard(
                                  key: ValueKey('${pair.id}-${pair.products[i].id}-$raw'),
                                  product: pair.products[i],
                                  quantity: _quantityFor(pair.products[i].id),
                                  onQuantityChanged: (qty) =>
                                      _onQuantityChanged(pair.products[i], qty),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          }),

          // Single-Row Compact Footer: Saving Label on Left + Progress Indicator on Right
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 12.5, color: Color(0xFF69864B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _pairs[_index].savingLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5E6D38),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _pairs.length; i++)
                        InkWell(
                          onTap: () => _turnPage(i - _index, manual: true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: i == _index ? 16 : 5,
                            height: 4.5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: i == _index
                                  ? LinearProgressIndicator(
                                      value: _clock.value,
                                      backgroundColor: const Color(0xFFE0D5A0),
                                      valueColor: AlwaysStoppedAnimation(
                                        green.withValues(alpha: 0.8),
                                      ),
                                    )
                                  : const ColoredBox(color: Color(0xFFD9D19E)),
                            ),
                          ),
                        ),
                    ],
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

/// Product Artwork Cropper for the 3x2 Atlas
class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    super.key,
    required this.product,
    this.side,
  });

  final ValueProduct product;
  final double? side;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('assets/navratri/essentials-atlas')) {
      if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ImageFallback(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
        );
      } else if (imageUrl.startsWith('assets/')) {
        return Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ImageFallback(),
        );
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final s = side ?? math.min(constraints.maxWidth, constraints.maxHeight);
      final column = product.artIndex % 3;
      final row = product.artIndex ~/ 3;
      return Center(
        child: SizedBox.square(
          dimension: s,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: s * 3,
              maxWidth: s * 3,
              minHeight: s * 2,
              maxHeight: s * 2,
              child: Transform.translate(
                offset: Offset(-column * s, -row * s),
                child: Image.asset(
                  'assets/navratri/essentials-atlas.jpg',
                  width: s * 3,
                  height: s * 2,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF9BA38B), size: 38),
      );
}

/// Quantity Button with Add / Minus-Qty-Plus
class ValueQuantityButton extends StatelessWidget {
  const ValueQuantityButton({
    super.key,
    required this.product,
    required this.quantity,
    required this.onChanged,
    this.accent,
    this.filled = false,
  });

  final ValueProduct product;
  final int quantity;
  final ValueChanged<int> onChanged;
  final Color? accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = accent ?? const Color(0xFF365B38);
    final active = quantity > 0 || filled;
    final foreground = active ? Colors.white : ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
      side: BorderSide(color: active ? ink : ink.withValues(alpha: 0.45)),
    );
    return SizedBox(
      height: 30,
      child: Material(
        color: active ? ink : const Color(0xFFFFFEFA),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: quantity == 0
            ? InkWell(
                key: ValueKey('value-add-${product.id}'),
                onTap: () => onChanged(1),
                child: Semantics(
                  button: true,
                  label: 'Add ${product.name}, ${product.packLabel}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.add, size: 14, color: foreground),
                    ],
                  ),
                ),
              )
            : Row(children: [
                Expanded(
                  child: IconButton(
                    key: ValueKey('value-minus-${product.id}'),
                    tooltip: 'Remove one ${product.name}',
                    onPressed: () => onChanged(quantity - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.remove, size: 14, color: foreground),
                  ),
                ),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: IconButton(
                    key: ValueKey('value-plus-${product.id}'),
                    tooltip: 'Add one ${product.name}',
                    onPressed: () => onChanged(quantity + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.add, size: 14, color: foreground),
                  ),
                ),
              ]),
      ),
    );
  }
}

/// The Product Card inside the Pair
class ValueProductCard extends StatelessWidget {
  const ValueProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    this.onProductTap,
  });

  final ValueProduct product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback? onProductTap;

  @override
  Widget build(BuildContext context) {
    final best = product.isBetterValue;
    final photoBackground = best ? const Color(0xFFF3F6ED) : const Color(0xFFF7F7EF);
    const green = Color(0xFF365B38);
    const muted = Color(0xFF89917C);
    const ink = Color(0xFF29422F);

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: best ? const Color(0xFFBECAA7) : const Color(0xFFE9E7D6),
          width: best ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: best ? const Color(0xFFECF3E5) : const Color(0xFFF1F5E9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (best) ...[
                    const Icon(Icons.auto_awesome, size: 9.5, color: green),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    best ? 'BETTER VALUE' : 'STANDARD PACK',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: best ? green : muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          InkWell(
            onTap: onProductTap,
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1.42,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: photoBackground),
                    Transform.scale(
                      scale: best ? 1.15 : 1.05,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(photoBackground, BlendMode.multiply),
                        child: ProductArtwork(product: product),
                      ),
                    ),
                    Positioned(
                      left: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          product.packLabel,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF687359),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 27,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${product.price.toInt()}',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  product.unitPriceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: best ? const Color(0xFF5E8250) : muted,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 5),
          ValueQuantityButton(
            product: product,
            quantity: quantity,
            onChanged: onQuantityChanged,
            accent: green,
            filled: best,
          ),
        ],
      ),
    );
  }
}
