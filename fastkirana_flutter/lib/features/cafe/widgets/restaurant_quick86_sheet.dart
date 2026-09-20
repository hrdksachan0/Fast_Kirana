import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Modal bottom sheet allowing quick toggle of 86 / out of stock status for menu items
class RestaurantQuick86Sheet {
  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> menuItems,
    required void Function(Map<String, dynamic> item) onToggleItemAvailability,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = menuItems.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            final inStockCount = menuItems.where((p) => p['isAvailable'] == true).length;
            final outStockCount = menuItems.length - inStockCount;

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick 86 / Stock Controls',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 17),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.slate900,
                                ),
                              ),
                              Text(
                                'Toggle sold-out dishes instantly',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  color: AppDesignSystem.slate500,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppDesignSystem.slate500),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    // Summary Pills
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.green50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppDesignSystem.emerald200),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$inStockCount',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 15),
                                      fontWeight: FontWeight.w900,
                                      color: AppDesignSystem.success,
                                    ),
                                  ),
                                  Text(
                                    'In Stock',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10),
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.rose50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppDesignSystem.rose200),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$outStockCount',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 15),
                                      fontWeight: FontWeight.w900,
                                      color: AppDesignSystem.primary,
                                    ),
                                  ),
                                  Text(
                                    'Out of Stock (86)',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10),
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (v) => setModalState(() => searchQuery = v),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search menu dishes...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              color: AppDesignSystem.slate500,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppDesignSystem.slate500),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppDesignSystem.slate200),
                    // Items List
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate200),
                        itemBuilder: (context, idx) {
                          final item = filteredItems[idx];
                          final isAvailable = item['isAvailable'] ?? true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.slate50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppDesignSystem.slate200),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🍲',
                                      style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                      Text(
                                        '₹${item['price'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 11.5),
                                          color: AppDesignSystem.slate500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isAvailable,
                                  activeTrackColor: AppDesignSystem.success,
                                  onChanged: (val) {
                                    setModalState(() {
                                      item['isAvailable'] = val;
                                    });
                                    onToggleItemAvailability(item);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
