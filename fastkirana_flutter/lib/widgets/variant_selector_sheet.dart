import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/store_settings_provider.dart';
import '../core/utils/restaurant_utils.dart';
import 'cart_conflict_dialog.dart';

class VariantSelectorSheet extends ConsumerStatefulWidget {
  final Product product;

  const VariantSelectorSheet({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, Product product) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VariantSelectorSheet(product: product),
    );
  }

  @override
  ConsumerState<VariantSelectorSheet> createState() => _VariantSelectorSheetState();
}

class _VariantSelectorSheetState extends ConsumerState<VariantSelectorSheet> {
  // For Restaurant / Food customization flow
  int _selectedVariantIndex = 0;
  int _foodQuantity = 1;
  final Map<String, Set<String>> _selectedAddons = {};

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) =>
        t.contains('non-veg') ||
        t.contains('nonveg') ||
        t == 'egg' ||
        t.contains('chicken') ||
        t.contains('mutton') ||
        t.contains('fish'))) {
      return false;
    }
    final nl = product.name.toLowerCase();
    if (nl.contains('chicken') || nl.contains('egg') || nl.contains('mutton') || nl.contains('fish')) {
      return false;
    }
    return true;
  }

  Product _buildVariantProduct(ProductVariant variant, {List<AddonItem> selectedAddonItems = const []}) {
    // Calculate addon total
    final addonTotal = selectedAddonItems.fold(0.0, (sum, a) => sum + a.price);
    final finalPrice = variant.price + addonTotal;
    final finalMrp = (variant.mrp > 0 ? variant.mrp : variant.price) + addonTotal;

    final discount = finalMrp > finalPrice && finalMrp > 0
        ? ((finalMrp - finalPrice) / finalMrp * 100).round()
        : 0;

    // Build addon suffix for name and ID uniqueness
    final addonSuffix = selectedAddonItems.isNotEmpty
        ? ' + ${selectedAddonItems.map((a) => a.name).join(', ')}'
        : '';
    final addonIdSuffix = selectedAddonItems.isNotEmpty
        ? '_addons_${selectedAddonItems.map((a) => a.name.replaceAll(' ', '-')).join('_')}'
        : '';

    return Product(
      id: '${widget.product.id}_${variant.name}$addonIdSuffix',
      name: '${widget.product.name} (${variant.name})$addonSuffix',
      slug: widget.product.slug,
      description: widget.product.description,
      imageUrl: widget.product.imageUrl,
      categoryId: widget.product.categoryId,
      restaurantId: widget.product.restaurantId,
      mrp: finalMrp,
      price: finalPrice,
      discount: discount.toDouble(),
      unit: variant.name,
      stock: widget.product.stock,
      isAvailable: widget.product.isAvailable,
      tags: widget.product.tags,
      variants: widget.product.variants,
      addons: widget.product.addons,
      minStock: widget.product.minStock,
      expiryDate: widget.product.expiryDate,
      costPrice: widget.product.costPrice,
      location: widget.product.location,
      isFlashDeal: widget.product.isFlashDeal,
      isTopPick: widget.product.isTopPick,
      isBestSeller: widget.product.isBestSeller,
      sortOrder: widget.product.sortOrder,
      availableStartTime: widget.product.availableStartTime,
      availableEndTime: widget.product.availableEndTime,
      barcode: widget.product.barcode,
      createdAt: widget.product.createdAt,
      category: widget.product.category,
      restaurant: widget.product.restaurant,
      menuSection: widget.product.menuSection,
    );
  }

  void _addFoodItemToCart(ProductVariant selectedVariant, bool isStoreOpen) {
    if (!isStoreOpen || !widget.product.isAvailable || widget.product.stock <= 0) return;

    // Validate required addon groups
    for (final group in widget.product.parsedAddons) {
      if (group.required) {
        final selected = _selectedAddons[group.title] ?? {};
        if (selected.isEmpty) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select an option for "${group.title}"',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    // Collect all selected addon items
    final List<AddonItem> addonItems = [];
    for (final group in widget.product.parsedAddons) {
      final selected = _selectedAddons[group.title] ?? {};
      for (final item in group.items) {
        if (selected.contains(item.name)) {
          addonItems.add(item);
        }
      }
    }

    final variantProduct = _buildVariantProduct(selectedVariant, selectedAddonItems: addonItems);
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(variantProduct);
    if (conflictRestaurant != null) {
      final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
      CartConflictDialog.show(
        context,
        product: variantProduct,
        existingOutletName: conflictRestaurant,
        groceryItemsCount: groceryCount,
        onConfirm: () {
          ref.read(cartProvider.notifier).replaceRestaurantItemsWith(variantProduct, _foodQuantity);
          Navigator.pop(context);
        },
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addProduct(variantProduct, _foodQuantity, selectedVariant.name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.parsedVariants;
    final isFood = isCafeProduct(widget.product) || isRestaurantProduct(widget.product);
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = widget.product.restaurant?.isOpen != false;
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    if (isFood) {
      return _buildFoodCustomizationSheet(context, variants, isStoreOpen);
    }
    return _buildGroceryPackSizeSheet(context, variants, isStoreOpen);
  }

  // =========================================================================
  // 1. RESTAURANT / FOOD CUSTOMIZATION SHEET (Swiggy / Zomato / Image 1 UI)
  // =========================================================================
  Widget _buildFoodCustomizationSheet(
    BuildContext context,
    List<ProductVariant> variants,
    bool isStoreOpen,
  ) {
    final effectiveVariant = variants.isNotEmpty && _selectedVariantIndex < variants.length
        ? variants[_selectedVariantIndex]
        : (variants.isNotEmpty
            ? variants[0]
            : ProductVariant(
                name: widget.product.unit.isNotEmpty ? widget.product.unit : 'Standard',
                price: widget.product.price,
                mrp: widget.product.mrp,
                stock: widget.product.stock,
              ));
    final selectedVariant = effectiveVariant;

    final isVeg = _isVeg(widget.product);
    // Calculate addon total from all selected addons
    double addonTotal = 0;
    for (final group in widget.product.parsedAddons) {
      final selected = _selectedAddons[group.title] ?? {};
      for (final item in group.items) {
        if (selected.contains(item.name)) {
          addonTotal += item.price;
        }
      }
    }
    final currentPrice = (selectedVariant.price + addonTotal) * _foodQuantity;
    final currentMrp = ((selectedVariant.mrp > 0 ? selectedVariant.mrp : widget.product.mrp) + addonTotal) * _foodQuantity;
    final hasDiscount = currentMrp > currentPrice;
    final isOutOfStock = !widget.product.isAvailable || widget.product.stock <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Dark Circular Close Button above sheet
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF2B2F38),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Main White Sheet Container
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Product Thumbnail
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.product.imageUrl!.startsWith('/')
                                    ? 'https://www.fastkirana.in${widget.product.imageUrl}'
                                    : widget.product.imageUrl!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Text('🍔', style: TextStyle(fontSize: 22)),
                                ),
                              )
                            : const Center(
                                child: Text('🍔', style: TextStyle(fontSize: 22)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Product Name
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 15.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Options List
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Title (Only if product has variants / portion sizes)
                      if (variants.isNotEmpty) ...[
                        Text(
                          'Choose Option',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 15),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select any 1',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Options Box (White rounded card with border)
                        Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: variants.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF3F4F6),
                            indent: 14,
                            endIndent: 14,
                          ),
                          itemBuilder: (ctx, index) {
                            final v = variants[index];
                            final isSelected = index == _selectedVariantIndex;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedVariantIndex = index;
                                });
                              },
                              borderRadius: BorderRadius.vertical(
                                top: index == 0 ? const Radius.circular(16) : Radius.zero,
                                bottom: index == variants.length - 1 ? const Radius.circular(16) : Radius.zero,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Row(
                                  children: [
                                    // Veg / Non-Veg Indicator
                                    _VegNonVegBadge(isVeg: isVeg, size: 16),
                                    const SizedBox(width: 10),

                                    // Variant Name
                                    Expanded(
                                      child: Text(
                                        v.name,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14.5),
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),

                                    // Price (if difference or standard)
                                    if (v.price > 0) ...[
                                      Text(
                                        '₹${v.price.toInt()}',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],

                                    // Radio Selector Circle
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF00875A) : const Color(0xFF9CA3AF),
                                          width: isSelected ? 2 : 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Center(
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00875A),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                      // ── Add-on / Extras Groups ──
                      ...widget.product.parsedAddons.map((group) {
                        final selectedSet = _selectedAddons[group.title] ?? {};
                        final isRadio = group.maxSelect == 1;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group Title
                              Text(
                                group.title,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 15),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRadio
                                    ? 'Select any 1${group.required ? ' (Required)' : ''}'
                                    : 'Select upto ${group.maxSelect}${group.required ? ' (Required)' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Addon Items Card
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: group.items.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF3F4F6),
                                    indent: 14,
                                    endIndent: 14,
                                  ),
                                  itemBuilder: (ctx, idx) {
                                    final addon = group.items[idx];
                                    final isChecked = selectedSet.contains(addon.name);

                                    return InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          final current = _selectedAddons[group.title] ?? {};
                                          if (isRadio) {
                                            // Radio: toggle same = deselect, else replace
                                            if (current.contains(addon.name)) {
                                              current.remove(addon.name);
                                            } else {
                                              current.clear();
                                              current.add(addon.name);
                                            }
                                          } else {
                                            // Checkbox: toggle
                                            if (current.contains(addon.name)) {
                                              current.remove(addon.name);
                                            } else if (current.length < group.maxSelect) {
                                              current.add(addon.name);
                                            }
                                          }
                                          _selectedAddons[group.title] = current;
                                        });
                                      },
                                      borderRadius: BorderRadius.vertical(
                                        top: idx == 0 ? const Radius.circular(16) : Radius.zero,
                                        bottom: idx == group.items.length - 1 ? const Radius.circular(16) : Radius.zero,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        child: Row(
                                          children: [
                                            // Addon Name
                                            Expanded(
                                              child: Text(
                                                addon.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.scaledFontSize(context, 14),
                                                  fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                                  color: const Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),

                                            // Price
                                            Padding(
                                              padding: const EdgeInsets.only(right: 12),
                                              child: Text(
                                                addon.price > 0 ? '+ ₹${addon.price.toInt()}' : 'Free',
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.scaledFontSize(context, 13),
                                                  fontWeight: FontWeight.w700,
                                                  color: addon.price > 0 ? const Color(0xFF4B5563) : const Color(0xFF00875A),
                                                ),
                                              ),
                                            ),

                                            // Checkbox / Radio indicator
                                            if (isRadio)
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isChecked ? const Color(0xFF00875A) : const Color(0xFF9CA3AF),
                                                    width: isChecked ? 2 : 1.5,
                                                  ),
                                                ),
                                                child: isChecked
                                                    ? Center(
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration: const BoxDecoration(
                                                            color: Color(0xFF00875A),
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                              )
                                            else
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(4),
                                                  color: isChecked ? const Color(0xFF00875A) : Colors.transparent,
                                                  border: Border.all(
                                                    color: isChecked ? const Color(0xFF00875A) : const Color(0xFF9CA3AF),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: isChecked
                                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                    : null,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 10
                      : 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Quantity Stepper [- 1 +]
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _foodQuantity > 1
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _foodQuantity--);
                                  }
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                            color: _foodQuantity > 1 ? const Color(0xFF00875A) : const Color(0xFF9CA3AF),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_foodQuantity',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 15),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00875A),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _foodQuantity++);
                            },
                            icon: const Icon(Icons.add, size: 18),
                            color: const Color(0xFF00875A),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add Item Button
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (isOutOfStock || !isStoreOpen)
                              ? null
                              : () => _addFoodItemToCart(selectedVariant, isStoreOpen),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isOutOfStock
                                    ? 'Item Sold Out'
                                    : !isStoreOpen
                                        ? 'Store Closed'
                                        : 'Add Item | ₹${currentPrice.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14.5),
                                  fontWeight: FontWeight.w800,
                                  color: (isOutOfStock || !isStoreOpen)
                                      ? const Color(0xFF9CA3AF)
                                      : Colors.white,
                                ),
                              ),
                              if (hasDiscount && !isOutOfStock && isStoreOpen) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${currentMrp.toInt()}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    );
  }

  // =========================================================================
  // 2. GROCERY PACK SIZE SELECTOR SHEET (Zepto / Blinkit / Image 2 UI)
  // =========================================================================
  Widget _buildGroceryPackSizeSheet(
    BuildContext context,
    List<ProductVariant> variants,
    bool isStoreOpen,
  ) {
    final minPrice = variants.isNotEmpty
        ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toInt()
        : widget.product.price.toInt();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle Pill (Image 2)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Product Info Header (Image 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.product.imageUrl!.startsWith('/')
                                    ? 'https://www.fastkirana.in${widget.product.imageUrl}'
                                    : widget.product.imageUrl!,
                                fit: BoxFit.contain,
                                memCacheWidth: 120,
                                memCacheHeight: 120,
                                maxWidthDiskCache: 200,
                                maxHeightDiskCache: 200,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Text('🛒', style: TextStyle(fontSize: 24)),
                                ),
                              )
                            : const Center(
                                child: Text('🛒', style: TextStyle(fontSize: 24)),
                              ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Options count (Image 2)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        variants.isNotEmpty
                            ? '${variants.length} Options (from ₹$minPrice)'
                            : (widget.product.unit.isNotEmpty &&
                                    widget.product.unit != '1 pc' &&
                                    widget.product.unit != '1 unit'
                                ? widget.product.unit
                                : 'Options available'),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Close Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF6B7280)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Section Title (Image 2: "SELECT OPTION / PACK SIZE")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              'SELECT OPTION / PACK SIZE',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Variants Cards List (Image 2: Clean white cards with green ADD button)
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final v = variants[index];
                return _buildGroceryVariantCard(context, v, isStoreOpen);
              },
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 12
                : 16,
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryVariantCard(
    BuildContext context,
    ProductVariant variant,
    bool isStoreOpen,
  ) {
    final cart = ref.watch(cartProvider).value;
    final variantProductId = '${widget.product.id}_${variant.name}';
    final cartItem = cart?.items.cast<dynamic>().firstWhere(
      (i) => i.productId == variantProductId || (i.productId == widget.product.id && i.selectedVariant == variant.name),
      orElse: () => null,
    );
    final inCartQty = cartItem?.quantity ?? 0;

    final discount = variant.mrp > variant.price && variant.mrp > 0
        ? ((variant.mrp - variant.price) / variant.mrp * 100).round()
        : 0;

    final isSelected = inCartQty > 0;
    final isSoldOut = !widget.product.isAvailable || widget.product.stock <= 0;
    final variantProduct = _buildVariantProduct(variant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF00875A) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Variant Title & Pricing (Image 2)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '₹${variant.price.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (variant.mrp > variant.price) ...[
                      const SizedBox(width: 7),
                      Text(
                        '₹${variant.mrp.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                    if (discount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$discount% OFF',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Right: Solid Green "ADD" Button or Stepper (Image 2)
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Sold Out',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          else if (!isStoreOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Closed',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          else if (inCartQty == 0)
            SizedBox(
              height: 38,
              width: 96,
              child: ElevatedButton(
                onPressed: () {
                  final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(variantProduct);
                  if (conflictRestaurant != null) {
                    final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
                    CartConflictDialog.show(
                      context,
                      product: variantProduct,
                      existingOutletName: conflictRestaurant,
                      groceryItemsCount: groceryCount,
                      onConfirm: () {
                        ref.read(cartProvider.notifier).replaceRestaurantItemsWith(variantProduct, 1);
                      },
                    );
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  ref.read(cartProvider.notifier).addProduct(variantProduct, 1, variant.name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00875A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'ADD',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 38,
              width: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF00875A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).decrement(variantProductId);
                    },
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                    child: const SizedBox(
                      width: 30,
                      height: 38,
                      child: Center(
                        child: Icon(Icons.remove, size: 17, color: Colors.white),
                      ),
                    ),
                  ),
                  Text(
                    '$inCartQty',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).addProduct(variantProduct, 1, variant.name);
                    },
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                    child: const SizedBox(
                      width: 30,
                      height: 38,
                      child: Center(
                        child: Icon(Icons.add, size: 17, color: Colors.white),
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
}

class _VegNonVegBadge extends StatelessWidget {
  final bool isVeg;
  final double size;

  const _VegNonVegBadge({required this.isVeg, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? const Color(0xFF00875A) : const Color(0xFFDC2626);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: isVeg
          ? Center(
              child: Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : Center(
              child: CustomPaint(
                size: Size(size * 0.48, size * 0.48),
                painter: _TrianglePainter(color),
              ),
            ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
