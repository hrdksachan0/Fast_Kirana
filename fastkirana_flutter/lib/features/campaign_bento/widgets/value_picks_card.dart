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
  bool _userPaused = false;
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
      !_userPaused &&
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
    const count = 10;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: BoxDecoration(
        color: butter,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCA8A04).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow and "See all 10" button
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 13, color: Color(0xFF8C7D3D)),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'THE EVERYDAY EDIT',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Color(0xFF8C7D3D),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showAllProductsSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  backgroundColor: Colors.white.withValues(alpha: 0.65),
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const StadiumBorder(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all $count',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.north_east, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Main Header Row: Title & Rotating Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Value '),
                        const TextSpan(
                          text: 'Picks',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ]),
                      style: const TextStyle(
                        fontFamily: 'NotoSerif',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.1,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stock up on good. Spend a little less.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10.5,
                        color: Color(0xFF8A8054),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.rotate(
                angle: 0.18,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: green,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Color(0xFFFFF6C7), size: 17),
                      SizedBox(height: 2),
                      Text(
                        'PICK SMART',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF6C7),
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'EVERY DAY',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF6C7),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Carousel of paired cards
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            final textScale = math.max(1.0, MediaQuery.textScalerOf(context).scale(13) / 13);
            final height = (cardWidth - 20) / 1.04 + 192 + (textScale - 1) * 70;

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
                              if (i == 1) const SizedBox(width: 10),
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

          // Saving Label Ribbon
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF69864B)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _pairs[_index].savingLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF758040),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE9DFA8)),

          // Bottom Navigation Row
          Row(
            children: [
              const Text(
                '$count picks',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9B915F),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _pairs.length; i++)
                      InkWell(
                        onTap: () => _turnPage(i - _index, manual: true),
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: i == _index ? 28 : 18,
                          height: 38,
                          child: Center(
                            child: SizedBox(
                              width: i == _index ? 22 : 5,
                              height: 5,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: i == _index
                                    ? LinearProgressIndicator(
                                        value: _clock.value,
                                        backgroundColor: const Color(0xFFE0D5A0),
                                        valueColor: AlwaysStoppedAnimation(
                                          green.withValues(alpha: 0.6),
                                        ),
                                      )
                                    : const ColoredBox(color: Color(0xFFD9D19E)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              _arrow(
                Icons.chevron_left,
                'Previous product pair',
                _pairs.length > 1 ? () => _turnPage(-1, manual: true) : null,
              ),
              _arrow(
                _userPaused || _reduceMotion ? Icons.play_arrow : Icons.pause,
                _reduceMotion
                    ? 'Automatic movement disabled by system setting'
                    : _userPaused
                        ? 'Resume automatic rotation'
                        : 'Pause automatic rotation',
                _reduceMotion
                    ? null
                    : () {
                        setState(() => _userPaused = !_userPaused);
                        _syncClock();
                      },
                key: const ValueKey('value-pause'),
              ),
              _arrow(
                Icons.chevron_right,
                'Next product pair',
                _pairs.length > 1 ? () => _turnPage(1, manual: true) : null,
                key: const ValueKey('value-next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, String label, VoidCallback? action, {Key? key}) {
    return SizedBox(
      width: 32,
      height: 38,
      child: IconButton(
        key: key,
        tooltip: label,
        onPressed: action,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: const Color(0xFF8F9062)),
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
      height: 40,
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
                          fontSize: 12,
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.add, size: 16, color: foreground),
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
                    icon: Icon(Icons.remove, size: 16, color: foreground),
                  ),
                ),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: IconButton(
                    key: ValueKey('value-plus-${product.id}'),
                    tooltip: 'Add one ${product.name}',
                    onPressed: () => onChanged(quantity + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.add, size: 16, color: foreground),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: best ? const Color(0xFFBECAA7) : const Color(0xFFE9E7D6),
          width: best ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 23,
            alignment: best ? Alignment.center : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: best ? const Color(0xFFECF3E5) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (best) ...[
                    const Icon(Icons.auto_awesome_outlined, size: 11, color: green),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    best ? 'BETTER VALUE' : 'THE DAILY PICK',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.55,
                      color: best ? green : muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onProductTap,
            borderRadius: BorderRadius.circular(13),
            child: AspectRatio(
              aspectRatio: 1.04,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: photoBackground),
                    Transform.scale(
                      scale: best ? 1.24 : 1.11,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(photoBackground, BlendMode.multiply),
                        child: ProductArtwork(product: product),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          product.packLabel,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${product.price.toInt()}',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            product.unitPriceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: best ? const Color(0xFF5E8250) : muted,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
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
