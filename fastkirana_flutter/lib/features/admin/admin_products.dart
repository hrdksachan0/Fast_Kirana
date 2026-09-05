import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/theme/responsive.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminProductsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  // 0 = Grocery, 1 = Restaurant
  int _selectedCatalogType = 0;
  String _searchQuery = '';
  String _selectedGroceryCategoryId = 'ALL';
  String _selectedRestaurantOutlet = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  // Map to track local override toggles for instant UI responsiveness
  final Map<String, bool> _localAvailability = {};
  final Map<String, int> _localStock = {};

  static const Color primaryRed = AppDesignSystem.primary;

  final List<Map<String, String>> _restaurantOutlets = [
    {'id': 'ALL', 'name': 'All Outlets'},
    {'id': outletWedsonId, 'name': 'Wedson Restaurant'},
    {'id': outletAsRestaurantId, 'name': 'A.S. Restaurant'},
    {'id': outletBalUdyanId, 'name': 'Bal Udyan Restaurant'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.slate900),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Manage Catalog',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: primaryRed),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.refresh(productsProvider(null));
                    ref.refresh(categoriesProvider);
                  },
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // 1. Catalog Switcher (Grocery vs Restaurant)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.slate200, width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      index: 0,
                      label: 'Grocery Catalog',
                      icon: Icons.shopping_basket_rounded,
                      isSelected: _selectedCatalogType == 0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSegmentButton(
                      index: 1,
                      label: 'Restaurant Food',
                      icon: Icons.restaurant_rounded,
                      isSelected: _selectedCatalogType == 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Modern Search Box with Barcode Scanner & Instant Clear
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 19, color: AppDesignSystem.slate500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: _selectedCatalogType == 0
                            ? 'Search grocery items or barcode...'
                            : 'Search restaurant dishes & outlets...',
                        hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: AppDesignSystem.slate400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate400),
                      ),
                    ),
                  // Barcode Scanner Tool Button
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openBarcodeScannerDialog,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDesignSystem.blue200),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppDesignSystem.blue700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Category / Outlet Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: _selectedCatalogType == 0
                ? _buildGroceryCategoryChips(categoriesAsync)
                : _buildRestaurantOutletChips(),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate200),

          // 4. Products List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                // Step A: Separate Grocery vs Restaurant
                var filtered = products.where((p) {
                  final isRest = isRestaurantProduct(p);
                  if (_selectedCatalogType == 0) {
                    // Grocery mode: exclude restaurant dishes
                    return !isRest;
                  } else {
                    // Restaurant mode: only restaurant dishes
                    return isRest;
                  }
                }).toList();

                // Step B: Filter by Selected Category / Outlet
                if (_selectedCatalogType == 0) {
                  if (_selectedGroceryCategoryId == 'LOW_STOCK') {
                    filtered = filtered.where((p) {
                      final currentStock = _localStock[p.id] ?? p.stock;
                      return currentStock <= 5;
                    }).toList();
                  } else if (_selectedGroceryCategoryId != 'ALL') {
                    filtered = filtered.where((p) {
                      return p.categoryId == _selectedGroceryCategoryId ||
                          (p.category?.id == _selectedGroceryCategoryId) ||
                          (p.category?.slug == _selectedGroceryCategoryId);
                    }).toList();
                  }
                } else {
                  if (_selectedRestaurantOutlet != 'ALL') {
                    filtered = filtered.where((p) {
                      final pOutlet = getOutletName(p);
                      final matchOutlet = _restaurantOutlets.firstWhere(
                        (o) => o['id'] == _selectedRestaurantOutlet,
                        orElse: () => {'id': '', 'name': ''},
                      )['name'];
                      return p.restaurantId == _selectedRestaurantOutlet ||
                          (p.restaurant?.id == _selectedRestaurantOutlet) ||
                          (matchOutlet != null && pOutlet == matchOutlet);
                    }).toList();
                  }
                }

                // Step C: Search query filtering
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((p) {
                    final nameMatch = p.name.toLowerCase().contains(_searchQuery);
                    final catMatch = (p.category?.name ?? '').toLowerCase().contains(_searchQuery);
                    final outletMatch = getOutletName(p).toLowerCase().contains(_searchQuery);
                    return nameMatch || catMatch || outletMatch;
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedCatalogType == 0
                              ? Icons.shopping_basket_outlined
                              : Icons.restaurant_outlined,
                          size: 48,
                          color: AppDesignSystem.slate400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedCatalogType == 0
                              ? 'No grocery items found'
                              : 'No restaurant dishes found',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryRed,
                  onRefresh: () async {
                    ref.refresh(productsProvider(null));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return _buildProductAdminCard(p);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: primaryRed),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40, color: AppDesignSystem.danger),
                    const SizedBox(height: 10),
                    Text('Failed to load items: $err',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.slate500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCatalogType = index;
          _searchQuery = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? primaryRed : AppDesignSystem.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? primaryRed : AppDesignSystem.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroceryCategoryChips(AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) {
        // Filter grocery categories (exclude explicit restaurant categories)
        final groceryCategories = categories.where((c) {
          final slug = (c.slug).toLowerCase();
          return !slug.contains('restaurant') && !slug.contains('cafe');
        }).toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _buildCategoryChip(
                id: 'ALL',
                label: 'All Grocery',
                isSelected: _selectedGroceryCategoryId == 'ALL',
                onSelect: () => setState(() => _selectedGroceryCategoryId = 'ALL'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _buildCategoryChip(
                  id: 'LOW_STOCK',
                  label: '⚠️ Low Stock (< 5)',
                  isSelected: _selectedGroceryCategoryId == 'LOW_STOCK',
                  onSelect: () => setState(() => _selectedGroceryCategoryId = 'LOW_STOCK'),
                  badgeColor: AppDesignSystem.amber600,
                ),
              ),
              ...groceryCategories.map((cat) {
                final isSelected = _selectedGroceryCategoryId == cat.id ||
                    _selectedGroceryCategoryId == cat.slug;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _buildCategoryChip(
                    id: cat.id,
                    label: cat.name,
                    isSelected: isSelected,
                    onSelect: () => setState(() => _selectedGroceryCategoryId = cat.id),
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed)),
      ),
      error: (_, __) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _buildCategoryChip(
              id: 'ALL',
              label: 'All Grocery',
              isSelected: _selectedGroceryCategoryId == 'ALL',
              onSelect: () => setState(() => _selectedGroceryCategoryId = 'ALL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantOutletChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: _restaurantOutlets.map((outlet) {
          final isSelected = _selectedRestaurantOutlet == outlet['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildCategoryChip(
              id: outlet['id']!,
              label: outlet['name']!,
              isSelected: isSelected,
              onSelect: () => setState(() => _selectedRestaurantOutlet = outlet['id']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required bool isSelected,
    required VoidCallback onSelect,
    Color? badgeColor,
  }) {
    final activeColor = badgeColor ?? AppDesignSystem.slate900;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onSelect();
      },
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: Responsive.scaledFontSize(context, 11.5),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : (badgeColor ?? AppDesignSystem.slate600),
        ),
      ),
      selectedColor: activeColor,
      backgroundColor: badgeColor != null ? badgeColor.withValues(alpha: 0.12) : AppDesignSystem.slate100,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? activeColor : (badgeColor?.withValues(alpha: 0.4) ?? AppDesignSystem.slate200),
        ),
      ),
    );
  }

  Future<void> _updateProductStock(Product p, int newStock) async {
    final clampedStock = math.max(0, newStock);
    HapticFeedback.selectionClick();
    setState(() {
      _localStock[p.id] = clampedStock;
    });

    final sb = SupabaseService.client;
    if (sb != null) {
      try {
        await sb.from('products').update({
          'stock': clampedStock,
          'isAvailable': clampedStock > 0 ? (_localAvailability[p.id] ?? p.isAvailable) : false,
          'updatedAt': DateTime.now().toIso8601String(),
        }).eq('id', p.id);
      } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }
    }

    try {
      await ref.read(dioProvider).patch('/api/products/${p.id}', data: {
        'stock': clampedStock,
      });
    } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }
  }

  void _promptDirectStockInput(Product p, int currentStock) {
    final controller = TextEditingController(text: currentStock.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Quick Stock: ${p.name}',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter available inventory quantity for this product:',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Stock Units',
                hintText: 'e.g. 50',
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null) {
                _updateProductStock(p, val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Update Stock', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openBarcodeScannerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: primaryRed, size: 22),
            const SizedBox(width: 8),
            Text(
              'Barcode Search',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter or paste product barcode number to instantly locate item:',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'e.g. 8901234567890',
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate300)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              final query = controller.text.trim();
              if (query.isNotEmpty) {
                setState(() {
                  _searchQuery = query.toLowerCase();
                  _searchController.text = query;
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Search', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEditProductSheet(Product product) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductEditBottomSheet(
        product: product,
        onUpdated: () {
          ref.refresh(productsProvider(null));
        },
      ),
    );
  }

  Widget _buildProductAdminCard(Product p) {
    final isRestaurant = isRestaurantProduct(p);
    final outletName = isRestaurant ? getOutletName(p) : null;
    final currentStock = _localStock[p.id] ?? p.stock;
    final isLowStock = !isRestaurant && currentStock <= (p.minStock > 0 ? p.minStock : 5);
    final isAvailable = _localAvailability[p.id] ?? (p.isAvailable && (isRestaurant || currentStock > 0));
    final variants = p.parsedVariants;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !isAvailable
              ? AppDesignSystem.danger.withValues(alpha: 0.3)
              : (isLowStock ? AppDesignSystem.warning.withValues(alpha: 0.4) : AppDesignSystem.slate200),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Details Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppDesignSystem.slate100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (p.imageUrl != null && p.imageUrl!.startsWith('http'))
                        ? CachedNetworkImage(
                            imageUrl: p.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            memCacheHeight: 200,
                            maxWidthDiskCache: 200,
                            maxHeightDiskCache: 200,
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(
                                isRestaurant ? Icons.restaurant_rounded : Icons.shopping_basket_rounded,
                                size: 26,
                                color: AppDesignSystem.slate400,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              isRestaurant ? Icons.restaurant_rounded : Icons.shopping_basket_rounded,
                              size: 26,
                              color: AppDesignSystem.slate400,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        p.name,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Category or Restaurant Tag
                      Row(
                        children: [
                          if (isRestaurant && outletName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.statusPending,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                outletName,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.amber600,
                                ),
                              ),
                            ),
                          ] else if (p.category != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.slate100,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                p.category!.name,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignSystem.slate600,
                                ),
                              ),
                            ),
                          ],
                          if (p.unit.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${p.unit})',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w500,
                                color: AppDesignSystem.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price and Quick Interactive Stock Stepper
                      Row(
                        children: [
                          Text(
                            '₹${p.price.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          if (p.mrp > p.price) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${p.mrp.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                color: AppDesignSystem.slate400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Quick [-] [Stock] [+] Stepper
                          if (!isRestaurant) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? AppDesignSystem.statusPending
                                    : AppDesignSystem.slate100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isLowStock
                                      ? AppDesignSystem.warning.withValues(alpha: 0.5)
                                      : AppDesignSystem.slate300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // [-] Button
                                  InkWell(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    onTap: () => _updateProductStock(p, currentStock - 1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      child: Icon(
                                        Icons.remove_rounded,
                                        size: 14,
                                        color: isLowStock ? AppDesignSystem.amber600 : AppDesignSystem.slate700,
                                      ),
                                    ),
                                  ),
                                  // Stock Value (Tap to type)
                                  GestureDetector(
                                    onTap: () => _promptDirectStockInput(p, currentStock),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      color: Colors.white,
                                      child: Text(
                                        '$currentStock',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 11.5),
                                          fontWeight: FontWeight.w900,
                                          color: isLowStock ? AppDesignSystem.amber600 : AppDesignSystem.slate900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // [+] Button
                                  InkWell(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    onTap: () => _updateProductStock(p, currentStock + 1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 14,
                                        color: isLowStock ? AppDesignSystem.amber600 : AppDesignSystem.slate700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Availability Switch
                const SizedBox(width: 8),
                Column(
                  children: [
                    Switch(
                      value: isAvailable,
                      activeColor: AppDesignSystem.green600,
                      activeTrackColor: AppDesignSystem.green100,
                      inactiveTrackColor: AppDesignSystem.slate200,
                      onChanged: (val) async {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _localAvailability[p.id] = val;
                        });

                        final sb = SupabaseService.client;
                        if (sb != null) {
                          try {
                            await sb.from('products').update({'isAvailable': val}).eq('id', p.id);
                          } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }
                        }

                        try {
                          await ref.read(dioProvider).patch('/api/products/${p.id}', data: {'isAvailable': val});
                        } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${p.name} marked as ${val ? "IN STOCK / AVAILABLE" : "OUT OF STOCK / HIDDEN"}',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: val ? AppDesignSystem.green600 : AppDesignSystem.red600,
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    Text(
                      isAvailable ? 'Active' : 'Hidden',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9),
                        fontWeight: FontWeight.w800,
                        color: isAvailable ? AppDesignSystem.green600 : AppDesignSystem.red600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Bottom Action Button: Edit Price, Stock & Variants
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => _openEditProductSheet(p),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
              decoration: const BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_note_rounded, size: 18, color: AppDesignSystem.slate900),
                  const SizedBox(width: 6),
                  Text(
                    'Edit Price, Stock & Variants',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                  if (variants.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppDesignSystem.blue200),
                      ),
                      child: Text(
                        '${variants.length} Variants ⚡',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.blue700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPREHENSIVE PRODUCT & VARIANT EDIT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ProductEditBottomSheet extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback onUpdated;

  const _ProductEditBottomSheet({
    required this.product,
    required this.onUpdated,
  });

  @override
  ConsumerState<_ProductEditBottomSheet> createState() => _ProductEditBottomSheetState();
}

class _VariantEditItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController mrpController;
  final TextEditingController stockController;

  _VariantEditItem({
    required String name,
    required double price,
    required double mrp,
    required int stock,
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price.toInt().toString()),
        mrpController = TextEditingController(text: mrp.toInt().toString()),
        stockController = TextEditingController(text: stock.toString());

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    mrpController.dispose();
    stockController.dispose();
  }

  Map<String, dynamic> toJson() {
    final p = double.tryParse(priceController.text.trim()) ?? 0.0;
    final m = double.tryParse(mrpController.text.trim()) ?? p;
    final s = int.tryParse(stockController.text.trim()) ?? 999;
    return {
      'name': nameController.text.trim(),
      'price': p,
      'mrp': m > p ? m : p,
      'stock': s,
    };
  }
}

class _ProductEditBottomSheetState extends ConsumerState<_ProductEditBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;
  late TextEditingController _mrpController;
  late TextEditingController _stockController;
  late bool _isAvailable;
  bool _isSaving = false;

  final List<_VariantEditItem> _variantItems = [];

  static const Color primaryRed = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _unitController = TextEditingController(text: p.unit);
    _priceController = TextEditingController(text: p.price.toInt().toString());
    _mrpController = TextEditingController(text: p.mrp.toInt().toString());
    _stockController = TextEditingController(text: p.stock.toString());
    _isAvailable = p.isAvailable;

    // Initialize existing variants
    for (final v in p.parsedVariants) {
      _variantItems.add(_VariantEditItem(
        name: v.name,
        price: v.price,
        mrp: v.mrp,
        stock: v.stock,
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    for (final item in _variantItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    HapticFeedback.lightImpact();
    setState(() {
      _variantItems.add(_VariantEditItem(
        name: '${_variantItems.length + 1} Pack',
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        mrp: double.tryParse(_mrpController.text.trim()) ?? 0.0,
        stock: int.tryParse(_stockController.text.trim()) ?? 100,
      ));
    });
  }

  void _removeVariant(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final item = _variantItems.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name cannot be empty'), backgroundColor: primaryRed),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text.trim()) ?? price;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final unit = _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : '1 unit';

    final variantsJson = _variantItems.map((v) => v.toJson()).toList();

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final payload = {
        'name': name,
        'unit': unit,
        'price': price,
        'mrp': mrp > price ? mrp : price,
        'stock': stock,
        'isAvailable': _isAvailable,
        'variants': variantsJson.isNotEmpty ? variantsJson : null,
      };

      // 1. Direct Supabase Update
      final sb = SupabaseService.client;
      if (sb != null) {
        try {
          await sb.from('products').update({
            ...payload,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', widget.product.id);
        } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }
      }

      // 2. REST API Update
      try {
        await ref.read(dioProvider).patch('/api/products/${widget.product.id}', data: payload);
      } catch (e, _) { LoggerService.error('AdminProducts: silent catch', e); }

      widget.onUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Updated "$name" successfully!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: AppDesignSystem.green600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isRestaurant = isRestaurantProduct(widget.product);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              color: AppDesignSystem.slate900,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Product & Variants',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.product.name,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Scrollable Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Basic Product Info
                  _buildSectionTitle('BASIC PRODUCT DETAILS'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    label: 'Product Name',
                    controller: _nameController,
                    hint: 'e.g. Namaste India Desi Ghee',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Base Unit / Size',
                          controller: _unitController,
                          hint: 'e.g. 500 g, 1 kg, 1 unit',
                          icon: Icons.scale_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'In-Stock Status',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignSystem.slate500,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isAvailable ? 'Active' : 'Hidden',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12),
                                      fontWeight: FontWeight.w800,
                                      color: _isAvailable ? AppDesignSystem.green600 : AppDesignSystem.red600,
                                    ),
                                  ),
                                  Switch(
                                    value: _isAvailable,
                                    activeColor: AppDesignSystem.green600,
                                    onChanged: (val) => setState(() => _isAvailable = val),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Base Pricing & Stock
                  _buildSectionTitle('BASE PRICING & INVENTORY'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Selling Price (₹)',
                          controller: _priceController,
                          hint: 'e.g. 250',
                          keyboardType: TextInputType.number,
                          icon: Icons.currency_rupee_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          label: 'MRP / Original (₹)',
                          controller: _mrpController,
                          hint: 'e.g. 280',
                          keyboardType: TextInputType.number,
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      if (!isRestaurant) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            label: 'Stock (Qty)',
                            controller: _stockController,
                            hint: 'e.g. 50',
                            keyboardType: TextInputType.number,
                            icon: Icons.inventory_2_rounded,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 3. Variants Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('PRODUCT VARIANTS (${_variantItems.length})'),
                      InkWell(
                        onTap: _addVariant,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignSystem.blue200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: AppDesignSystem.blue700),
                              const SizedBox(width: 4),
                              Text(
                                '+ Add Variant',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.blue700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add multiple weight/pack options (e.g. 250g, 500g, 1kg) with custom price & stock.',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.slate500),
                  ),
                  const SizedBox(height: 10),

                  if (_variantItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.slate200),
                      ),
                      child: Center(
                        child: Text(
                          'No variants added yet. Tap "+ Add Variant" to create weight/size options.',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate400, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _variantItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final v = _variantItems[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppDesignSystem.slate300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppDesignSystem.slate900,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Variant #${idx + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: v.nameController,
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800),
                                      decoration: InputDecoration(
                                        hintText: 'Variant Name (e.g. 500 g, 1 kg)',
                                        hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate400),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppDesignSystem.slate300),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    onPressed: () => _removeVariant(idx),
                                    icon: const Icon(Icons.delete_outline_rounded, color: primaryRed, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniInput(
                                      label: 'Price (₹)',
                                      controller: v.priceController,
                                      hint: '100',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMiniInput(
                                      label: 'MRP (₹)',
                                      controller: v.mrpController,
                                      hint: '120',
                                    ),
                                  ),
                                  if (!isRestaurant) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildMiniInput(
                                        label: 'Stock',
                                        controller: v.stockController,
                                        hint: '50',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Fixed Save Button
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppDesignSystem.slate200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save & Update Catalog',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: Responsive.scaledFontSize(context, 11),
        fontWeight: FontWeight.w800,
        color: AppDesignSystem.slate500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11),
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.slate600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppDesignSystem.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesignSystem.slate200),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.slate900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate400),
              prefixIcon: icon != null ? Icon(icon, size: 18, color: AppDesignSystem.slate500) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInput({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 10),
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.slate500,
          ),
        ),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.slate400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppDesignSystem.slate300),
            ),
          ),
        ),
      ],
    );
  }
}