import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/product.dart';
import '../../../providers/product_provider.dart';

/// Bottom sheet dialog to search product within domain OR add a custom item
class AddItemSearchSheet extends ConsumerStatefulWidget {
  final bool isAdmin;
  final bool isRestaurant;
  final String? restaurantId;
  final bool isSwapMode;
  final String? targetSwapItemName;
  final ValueChanged<Map<String, dynamic>> onProductSelected;

  const AddItemSearchSheet({
    super.key,
    required this.isAdmin,
    required this.isRestaurant,
    this.restaurantId,
    required this.isSwapMode,
    this.targetSwapItemName,
    required this.onProductSelected,
  });

  @override
  ConsumerState<AddItemSearchSheet> createState() => _AddItemSearchSheetState();
}

class _AddItemSearchSheetState extends ConsumerState<AddItemSearchSheet> {
  int _selectedTab = 0; // 0: Search Catalog, 1: Custom Item
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Admin filter chip: 'ALL', 'GROCERY', 'WEDSON', 'AS_REST', 'BAL_UDYAN'
  String _adminCatalogFilter = 'ALL';

  // Custom Item Form Controllers
  final _customNameController = TextEditingController();
  final _customPriceController = TextEditingController();
  final _customQtyController = TextEditingController(text: '1');
  final _customNotesController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    _customPriceController.dispose();
    _customQtyController.dispose();
    _customNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(homeProductCatalogProvider);

    final titlePrefix = widget.isSwapMode
        ? 'Swap "${widget.targetSwapItemName ?? 'Item'}" with'
        : 'Add Item to Order';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.isAdmin ? '⚡ $titlePrefix' : titlePrefix,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate500),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // Tabs Switcher (Catalog Search vs Custom / Off-Menu item for all consoles)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedTab == 0
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Search Full Catalog',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _selectedTab == 0 ? AppDesignSystem.slate900 : AppDesignSystem.slate500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedTab == 1
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Custom / Off-Menu ✍️',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _selectedTab == 1 ? AppDesignSystem.slate900 : AppDesignSystem.slate500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Admin Domain Filter Chips (All, Grocery, Wedson, A.S., Bal Udyan)
          if (widget.isAdmin && _selectedTab == 0) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildAdminFilterChip('ALL', 'All Items'),
                  const SizedBox(width: 6),
                  _buildAdminFilterChip('GROCERY', '🛒 Grocery'),
                  const SizedBox(width: 6),
                  _buildAdminFilterChip(outletWedsonId, '🍽️ Wedson'),
                  const SizedBox(width: 6),
                  _buildAdminFilterChip(outletAsRestaurantId, '☕ A.S. Rest.'),
                  const SizedBox(width: 6),
                  _buildAdminFilterChip(outletBalUdyanId, '🌳 Bal Udyan'),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Domain Banner for Non-Admins
          if (!widget.isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: widget.isRestaurant ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isRestaurant ? Icons.restaurant_rounded : Icons.shopping_basket_rounded,
                    size: 16,
                    color: widget.isRestaurant ? AppDesignSystem.primary : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.isRestaurant
                          ? 'Showing dishes from this restaurant menu'
                          : 'Showing products from Dark Store Grocery catalog',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.isRestaurant ? AppDesignSystem.primary : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildCatalogSearchTab(catalogAsync)
                : _buildCustomItemTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFilterChip(String filterId, String label) {
    final isSelected = _adminCatalogFilter == filterId;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _adminCatalogFilter = filterId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : AppDesignSystem.slate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppDesignSystem.slate700,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogSearchTab(AsyncValue<List<Product>> catalogAsync) {
    return Column(
      children: [
        // Search Input
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppDesignSystem.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesignSystem.slate200),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: widget.isRestaurant
                        ? 'Search dishes in this restaurant...'
                        : (widget.isAdmin ? 'Search grocery, dishes, barcode...' : 'Search grocery catalog, barcode...'),
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.slate400),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate400),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Results List
        Expanded(
          child: catalogAsync.when(
            data: (products) {
              // 1. Apply Domain Filter
              var domainFiltered = products.where((p) {
                final isRest = isRestaurantProduct(p);

                if (widget.isAdmin) {
                  // Admin can filter by chip
                  if (_adminCatalogFilter == 'GROCERY') return !isRest;
                  if (_adminCatalogFilter != 'ALL') {
                    // Match specific restaurant outlet ID
                    final rId = (p.restaurantId ?? p.restaurant?.id ?? '').toLowerCase();
                    final target = _adminCatalogFilter.toLowerCase();
                    if (rId == target) return true;
                    if (target == outletAsRestaurantId.toLowerCase() && (rId == legacyAsRestaurantId || rId == 'as-restaurant' || rId == 'as-cafe')) return true;
                    if (target == outletWedsonId.toLowerCase() && (rId == legacyWedsonId || rId == 'wedson' || rId == 'wedson-restaurant')) return true;
                    if (target == outletBalUdyanId.toLowerCase() && (rId == legacyBalUdyanId || rId == 'bal-udyan' || rId == 'baludyan')) return true;
                    if (target == outletPariMilkId.toLowerCase() && (rId == legacyPariMilkId || rId == 'pari-milk' || rId == 'pari')) return true;
                    return false;
                  }
                  return true; // ALL
                } else if (widget.isRestaurant) {
                  // Restaurant Console: ONLY dishes from this restaurant
                  if (!isRest) return false;
                  if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
                    final rId = (p.restaurantId ?? p.restaurant?.id ?? '').toLowerCase();
                    final target = widget.restaurantId!.toLowerCase();
                    if (rId == target) return true;
                    if (target == outletAsRestaurantId.toLowerCase() && (rId == legacyAsRestaurantId || rId == 'as-restaurant' || rId == 'as-cafe')) return true;
                    if (target == outletWedsonId.toLowerCase() && (rId == legacyWedsonId || rId == 'wedson' || rId == 'wedson-restaurant')) return true;
                    if (target == outletBalUdyanId.toLowerCase() && (rId == legacyBalUdyanId || rId == 'bal-udyan' || rId == 'baludyan')) return true;
                    if (target == outletPariMilkId.toLowerCase() && (rId == legacyPariMilkId || rId == 'pari-milk' || rId == 'pari')) return true;
                    return false;
                  }
                  return true;
                } else {
                  // Picker Console: ONLY grocery items
                  return !isRest;
                }
              }).toList();

              // 2. Apply Search Query
              final q = _searchQuery;
              final filtered = q.isEmpty
                  ? domainFiltered.take(30).toList()
                  : domainFiltered.where((p) {
                      return p.name.toLowerCase().contains(q) ||
                          (p.barcode != null && p.barcode!.contains(q)) ||
                          (p.category?.name.toLowerCase().contains(q) ?? false) ||
                          p.tags.any((t) => t.toLowerCase().contains(q));
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 36, color: AppDesignSystem.slate400),
                      const SizedBox(height: 8),
                      Text('No matching items in this catalog', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      if (widget.isAdmin)
                        Text('Try custom item tab to add manual item', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.slate500)),
                    ],
                  ),
                );
              }

              final Color actionColor = widget.isAdmin
                  ? const Color(0xFFD97706)
                  : (widget.isRestaurant ? AppDesignSystem.primary : const Color(0xFF10B981));

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 8, color: AppDesignSystem.slate100),
                itemBuilder: (context, i) {
                  final p = filtered[i];
                  final isRest = isRestaurantProduct(p);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          isRest ? '🍽️' : '🛒',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          '₹${p.price.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isRest ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isRest ? (getOutletName(p)) : 'Grocery',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isRest ? AppDesignSystem.primary : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        widget.onProductSelected({
                          'productId': p.id,
                          'name': p.name,
                          'price': p.price,
                          'quantity': 1,
                          'imageUrl': p.imageUrl,
                          'isCustom': false,
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        widget.isSwapMode ? 'Swap ⇄' : 'Add +',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
            error: (e, _) => Center(child: Text('Error loading catalog: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomItemTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Text(
          'Add Custom / Phone-in Item',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
        ),
        Text(
          'Customer requested an off-menu or manual item? Enter details below:',
          style: GoogleFonts.inter(fontSize: 11.5, color: AppDesignSystem.slate500),
        ),
        const SizedBox(height: 14),

        // 1. Item Name
        TextField(
          controller: _customNameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Item Name *',
            hintText: 'e.g. Amul Makkhan 100g, Cigarette, Extra Chutney',
            filled: true,
            fillColor: AppDesignSystem.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Price & Qty Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  labelText: 'Price (₹) *',
                  prefixText: '₹ ',
                  hintText: '40',
                  filled: true,
                  fillColor: AppDesignSystem.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _customQtyController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  labelText: 'Qty *',
                  hintText: '1',
                  filled: true,
                  fillColor: AppDesignSystem.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Notes
        TextField(
          controller: _customNotesController,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'e.g. Special customer request on phone',
            filled: true,
            fillColor: AppDesignSystem.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
          ),
        ),
        const SizedBox(height: 20),

        // Submit Custom Item
        Bounceable(
          onTap: () {
            final name = _customNameController.text.trim();
            final price = double.tryParse(_customPriceController.text.trim()) ?? 0.0;
            final qty = int.tryParse(_customQtyController.text.trim()) ?? 1;
            final notes = _customNotesController.text.trim();

            if (name.isEmpty) {
              AppToast.showError(context, 'Please enter item name');
              return;
            }
            if (price <= 0) {
              AppToast.showError(context, 'Price must be greater than ₹0');
              return;
            }

            widget.onProductSelected({
              'productId': 'custom_${DateTime.now().millisecondsSinceEpoch}',
              'name': name,
              'price': price,
              'quantity': qty,
              'notes': notes.isNotEmpty ? notes : null,
              'isCustom': true,
            });
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.isAdmin
                  ? const Color(0xFFD97706)
                  : (widget.isRestaurant ? AppDesignSystem.primary : const Color(0xFF10B981)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                widget.isSwapMode ? 'Swap with Custom Item ⇄' : 'Add Custom Item to Order',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
