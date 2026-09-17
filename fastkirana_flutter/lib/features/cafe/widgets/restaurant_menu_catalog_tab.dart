import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../../core/theme/design_system.dart';

class RestaurantMenuCatalogTab extends StatefulWidget {
  final List<Map<String, dynamic>> menuItems;
  final String restaurantName;
  final VoidCallback onAddDish;
  final Function(Map<String, dynamic>) onToggleAvailability;

  const RestaurantMenuCatalogTab({
    super.key,
    required this.menuItems,
    required this.restaurantName,
    required this.onAddDish,
    required this.onToggleAvailability,
  });

  @override
  State<RestaurantMenuCatalogTab> createState() => _RestaurantMenuCatalogTabState();
}

class _RestaurantMenuCatalogTabState extends State<RestaurantMenuCatalogTab> {
  String _menuSearchQuery = '';
  String _menuStockFilter = 'ALL'; // ALL, IN_STOCK, OUT_STOCK
  final TextEditingController _menuSearchController = TextEditingController();
  Timer? _menuSearchDebounce;

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color bgMain = AppDesignSystem.slate50;

  @override
  void dispose() {
    _menuSearchDebounce?.cancel();
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 48, color: slateMuted),
            const SizedBox(height: 12),
            Text(
              'No menu items loaded',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: slateDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Dishes for ${widget.restaurantName} will appear here',
              style: GoogleFonts.inter(fontSize: 12, color: slateMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              onPressed: widget.onAddDish,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: Text(
                'Add First Dish',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final query = _menuSearchQuery.trim().toLowerCase();
    final inStockCount = widget.menuItems.where((p) => p['isAvailable'] == true).length;
    final outStockCount = widget.menuItems.length - inStockCount;

    // Filter items by search query and stock filter
    final filteredItems = widget.menuItems.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final category = (item['category'] is Map ? item['category']['name'] : '').toString().toLowerCase();
      final priceStr = (item['price'] ?? '').toString();

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          category.contains(query) ||
          priceStr.contains(query);

      if (!matchesQuery) return false;

      final isAvailable = item['isAvailable'] ?? true;
      if (_menuStockFilter == 'IN_STOCK') return isAvailable == true;
      if (_menuStockFilter == 'OUT_STOCK') return isAvailable == false;
      return true;
    }).toList();

    return Column(
      children: [
        // ─── 1. Search Bar & Filter Header ──────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          color: bgMain,
          child: Column(
            children: [
              // Modern Search Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _menuSearchQuery.isNotEmpty ? primaryRed : AppDesignSystem.slate200,
                    width: _menuSearchQuery.isNotEmpty ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _menuSearchController,
                  onChanged: (val) {
                    _menuSearchDebounce?.cancel();
                    _menuSearchDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _menuSearchQuery = val);
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: slateDark),
                  decoration: InputDecoration(
                    hintText: 'Search dish name, price or category...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.slate400, fontWeight: FontWeight.w500),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.slate500),
                    suffixIcon: _menuSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18, color: AppDesignSystem.slate400),
                            onPressed: () {
                              _menuSearchController.clear();
                              setState(() {
                                _menuSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips (All, In Stock, 86 / Out of Stock)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMenuFilterChip(
                      label: 'All Dishes (${widget.menuItems.length})',
                      isSelected: _menuStockFilter == 'ALL',
                      color: slateDark,
                      onTap: () => setState(() => _menuStockFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _buildMenuFilterChip(
                      label: '🟢 In Stock ($inStockCount)',
                      isSelected: _menuStockFilter == 'IN_STOCK',
                      color: AppDesignSystem.green700,
                      onTap: () => setState(() => _menuStockFilter = 'IN_STOCK'),
                    ),
                    const SizedBox(width: 8),
                    _buildMenuFilterChip(
                      label: '🔴 86 / Out of Stock ($outStockCount)',
                      isSelected: _menuStockFilter == 'OUT_STOCK',
                      color: primaryRed,
                      onTap: () => setState(() => _menuStockFilter = 'OUT_STOCK'),
                    ),
                    const SizedBox(width: 8),
                    Bounceable(
                      onTap: widget.onAddDish,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add Dish',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── 2. Dishes List / Empty State ─────────────────────────────────────
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Icon(Icons.search_off_rounded, size: 32, color: AppDesignSystem.slate400),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No dishes found',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _menuSearchQuery.isNotEmpty
                              ? 'No items match "$_menuSearchQuery"'
                              : 'No dishes match selected stock filter',
                          style: GoogleFonts.inter(fontSize: 12.5, color: slateMuted),
                          textAlign: TextAlign.center,
                        ),
                        if (_menuSearchQuery.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              _menuSearchController.clear();
                              setState(() {
                                _menuSearchQuery = '';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: slateDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: Text(
                              'Clear Search',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, idx) {
                    final item = filteredItems[idx];
                    final isAvailable = item['isAvailable'] ?? true;
                    final num price = (item['price'] is num)
                        ? (item['price'] as num)
                        : (num.tryParse(item['price']?.toString() ?? '0') ?? 0);

                    final String name = item['name']?.toString() ?? 'Dish';
                    final String? imageUrl = (item['images'] is List && (item['images'] as List).isNotEmpty)
                        ? item['images'][0].toString()
                        : item['image']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isAvailable ? AppDesignSystem.slate100 : AppDesignSystem.statusCancelled,
                          width: isAvailable ? 1.2 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Dish Thumbnail / Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isAvailable ? AppDesignSystem.slate50 : AppDesignSystem.statusCancelled,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAvailable ? AppDesignSystem.slate200 : AppDesignSystem.red200,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (imageUrl != null && imageUrl.trim().isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 200,
                                      memCacheHeight: 200,
                                      maxWidthDiskCache: 200,
                                      maxHeightDiskCache: 200,
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Text('🍲', style: TextStyle(fontSize: 20)),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('🍲', style: TextStyle(fontSize: 20)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dish Info & Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isAvailable ? slateDark : AppDesignSystem.slate400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '₹${price.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isAvailable ? AppDesignSystem.slate900 : AppDesignSystem.slate400,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAvailable ? AppDesignSystem.green100 : AppDesignSystem.statusCancelled,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAvailable ? 'LIVE' : '86 • OFF',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: isAvailable ? AppDesignSystem.green700 : AppDesignSystem.red600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Availability Switch
                          Switch.adaptive(
                            value: isAvailable,
                            activeColor: brandGreen,
                            activeTrackColor: AppDesignSystem.emerald200,
                            inactiveTrackColor: AppDesignSystem.slate200,
                            onChanged: (_) => widget.onToggleAvailability(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Bounceable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppDesignSystem.slate200,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppDesignSystem.slate500,
          ),
        ),
      ),
    );
  }
}
