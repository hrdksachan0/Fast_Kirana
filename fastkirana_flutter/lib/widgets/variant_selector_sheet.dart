import '../features/products/product_detail_screen.dart';
import 'package:fastminute_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/store_settings_provider.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/stock_notice_helper.dart';
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

  @override
  void initState() {
    super.initState();
    final variants = widget.product.parsedVariants;
    if (variants.isNotEmpty) {
      final firstInStock = variants.indexWhere((v) => v.stock > 0);
      _selectedVariantIndex = firstInStock != -1 ? firstInStock : 0;
    }
  }

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase().trim()).toList();
    if (tags.contains('veg') || tags.contains('pure-veg') || tags.contains('pureveg')) {
      return true;
    }
    if (tags.any((t) =>
        t == 'non-veg' ||
        t == 'nonveg' ||
        t == 'egg' ||
        t == 'chicken' ||
        t == 'mutton' ||
        t == 'fish' ||
        t.contains('non-veg') ||
        t.contains('nonveg'))) {
      return false;
    }
    final nl = product.name.toLowerCase();
    final words = nl.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();
    if (words.contains('chicken') ||
        words.contains('egg') ||
        words.contains('eggs') ||
        words.contains('mutton') ||
        words.contains('fish') ||
        words.contains('meat')) {
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
      stock: variant.stock,
      isAvailable: widget.product.isAvailable && variant.stock > 0,
      tags: widget.product.tags,
      variants: widget.product.variants,
      addons: widget.product.addons,
      minStock: widget.product.minStock,
      expiryDate: widget.product.expiryDate,
      costPrice: variant.costPrice > 0 ? variant.costPrice : widget.product.costPrice,
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
    if (!isStoreOpen || !widget.product.isAvailable || selectedVariant.stock <= 0) return;

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
    final isRestaurantOpen = RestaurantScheduleHelper.isProductRestaurantOpen(
      widget.product,
      storeSettings: settings,
    );
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
                costPrice: widget.product.costPrice,
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
    final isOutOfStock = !widget.product.isAvailable || effectiveVariant.stock <= 0;

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
                                memCacheWidth: 120,
                                memCacheHeight: 120,
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

                        // 2-Column or Horizontal Carousel Slider
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            if (variants.length <= 2) {
                              const spacing = 12.0;
                              final cardWidth = variants.length == 1
                                  ? (constraints.maxWidth - spacing) / 2
                                  : (constraints.maxWidth - (variants.length - 1) * spacing) / variants.length;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: List.generate(variants.length, (index) {
                                  final v = variants[index];
                                  final isSelected = index == _selectedVariantIndex;
                                  final isSoldOut = v.stock <= 0;
                                  final isCompact = cardWidth < 125;

                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: index < variants.length - 1 ? spacing : 0),
                                      child: _buildFoodVariantItem(context, v, index, isSelected, isSoldOut, isCompact, isVeg),
                                    ),
                                  );
                                }),
                              );
                            }

                            if (variants.length == 3) {
                              // Exactly 3 variants: Display all 3 side-by-side on screen without horizontal scroll
                              const spacing = 8.0;
                              final availableWidth = constraints.maxWidth;
                              final cardWidth = (availableWidth - 2 * spacing) / 3;

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: List.generate(variants.length, (index) {
                                      final v = variants[index];
                                      final isSelected = index == _selectedVariantIndex;
                                      final isSoldOut = v.stock <= 0;

                                      return Padding(
                                        padding: EdgeInsets.only(right: index < variants.length - 1 ? spacing : 0),
                                        child: SizedBox(
                                          width: cardWidth,
                                          child: _buildFoodVariantItem(context, v, index, isSelected, isSoldOut, true, isVeg),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              );
                            }

                            // 4+ variants: Show 3 full cards + 4th card peeking horizontally
                            const double spacing = 8.0;
                            final double cardWidth = ((constraints.maxWidth - 2 * spacing) / 3.15).clamp(100.0, 125.0);

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(variants.length, (index) {
                                    final v = variants[index];
                                    final isSelected = index == _selectedVariantIndex;
                                    final isSoldOut = v.stock <= 0;
                                    final isCompact = cardWidth < 125;

                                    return Padding(
                                      padding: EdgeInsets.only(right: index < variants.length - 1 ? spacing : 0),
                                      child: SizedBox(
                                        width: cardWidth,
                                        child: _buildFoodVariantItem(context, v, index, isSelected, isSoldOut, isCompact, isVeg),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
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
                                color: const Color(0xFFE20A22),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _foodQuantity++);
                            },
                            icon: const Icon(Icons.add, size: 18),
                            color: const Color(0xFFE20A22),
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
                            backgroundColor: const Color(0xFFE20A22),
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

  Widget _buildFoodVariantItem(
    BuildContext context,
    ProductVariant v,
    int index,
    bool isSelected,
    bool isSoldOut,
    bool isCompact,
    bool isVeg,
  ) {
    final hasImg = widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty;
    final imgUrl = hasImg
        ? (widget.product.imageUrl!.startsWith('/')
            ? 'https://www.fastkirana.in${widget.product.imageUrl!}'
            : widget.product.imageUrl!)
        : null;

    return InkWell(
      onTap: isSoldOut
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedVariantIndex = index;
              });
            },
      borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 10,
          vertical: isCompact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF9FA) : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE20A22) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x1AE20A22) : const Color(0x06000000),
              blurRadius: isSelected ? 6 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Top Row: Veg/Non-Veg Badge & Radio Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _VegNonVegBadge(isVeg: isVeg, size: isCompact ? 12 : 14),
                Container(
                  width: isCompact ? 16 : 18,
                  height: isCompact ? 16 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSoldOut
                          ? const Color(0xFFE2E8F0)
                          : (isSelected ? const Color(0xFFE20A22) : const Color(0xFF94A3B8)),
                      width: isSelected ? 2 : 1.2,
                    ),
                  ),
                  child: isSelected && !isSoldOut
                      ? Center(
                          child: Container(
                            width: isCompact ? 8 : 9,
                            height: isCompact ? 8 : 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE20A22),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 2. Food / Dish Image Thumbnail
            Container(
              height: isCompact ? 60 : 74,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imgUrl != null
                    ? Transform.scale(
                        scale: 1.05,
                        child: CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.contain,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(isVeg ? '🍕' : '🍗', style: TextStyle(fontSize: isCompact ? 24 : 30)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(isVeg ? '🍕' : '🍗', style: TextStyle(fontSize: isCompact ? 24 : 30)),
                      ),
              ),
            ),

            const SizedBox(height: 6),

            // 3. Variant / Portion Name
            Text(
              v.name,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 11.5 : 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSoldOut ? const Color(0xFF9CA3AF) : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // 4. Price & MRP Row
            if (isSoldOut)
              Text(
                'Sold Out',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${v.price.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 13 : 14.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (v.mrp > v.price) ...[
                    const SizedBox(width: 3),
                    Text(
                      '₹${v.mrp.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 9.5 : 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Floating Circular (X) Button situated outside/above sheet
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: Color(0xDD27272A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          ),
        ),

        // 2. White Modal Container
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Info Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product Thumbnail
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.product.imageUrl!.startsWith('/')
                                    ? 'https://www.fastkirana.in${widget.product.imageUrl!}'
                                    : widget.product.imageUrl!,
                                fit: BoxFit.contain,
                                memCacheWidth: 120,
                                memCacheHeight: 120,
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

                    // Name
                    Expanded(
                      child: Text(
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
                    ),

                    // View Details Link
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: widget.product),
                          ),
                        );
                      },
                      child: Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Section Label: "Quantity"
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(
                  'Quantity',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),

              // Adaptive Cards Layout:
              // - 1 or 2 variants: 2 wide columns fitting the screen width
              // - 3 variants: Exactly 3 cards fit comfortably side-by-side on screen
              // - 4+ variants: 3 full cards visible + 4th card peeking horizontally
              Flexible(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (variants.length <= 2) {
                      const spacing = 12.0;
                      final availableWidth = constraints.maxWidth - 32;
                      final cardWidth = variants.length == 1
                          ? availableWidth * 0.52
                          : (availableWidth - (variants.length - 1) * spacing) / variants.length;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            for (int i = 0; i < variants.length; i++) ...[
                              if (i > 0) const SizedBox(width: spacing),
                              SizedBox(
                                width: cardWidth,
                                child: _buildZeptoVariantCard(context, variants[i], isStoreOpen, cardWidth: cardWidth),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    if (variants.length == 3) {
                      // Exactly 3 variants: Display all 3 side-by-side without horizontal scrolling
                      const spacing = 8.0;
                      final availableWidth = constraints.maxWidth - 24; // 12px padding on each side
                      final cardWidth = (availableWidth - 2 * spacing) / 3;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < variants.length; i++) ...[
                                if (i > 0) const SizedBox(width: spacing),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildZeptoVariantCard(
                                    context,
                                    variants[i],
                                    isStoreOpen,
                                    cardWidth: cardWidth,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    // 4+ variants: Show 3 full cards + 4th card peeking
                    const double spacing = 8.0;
                    final availableWidth = constraints.maxWidth - 24;
                    final double cardWidth = ((availableWidth - 2 * spacing) / 3.15).clamp(100.0, 125.0);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < variants.length; i++) ...[
                              if (i > 0) const SizedBox(width: spacing),
                              SizedBox(
                                width: cardWidth,
                                child: _buildZeptoVariantCard(
                                  context,
                                  variants[i],
                                  isStoreOpen,
                                  cardWidth: cardWidth,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Confirm Bar (Solid FastMinute Red)
              _buildZeptoBottomBar(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZeptoVariantCard(
    BuildContext context,
    ProductVariant variant,
    bool isStoreOpen, {
    required double cardWidth,
  }) {
    final cart = ref.watch(cartProvider).value;
    final variantProductId = '${widget.product.id}_${variant.name}';
    final isDefaultVariant = widget.product.parsedVariants.isNotEmpty &&
        widget.product.parsedVariants.first.name == variant.name;

    final matchingItems = cart?.items.where((i) {
      if (i.productId == variantProductId) return true;
      if (i.productId == widget.product.id) {
        if (i.selectedVariant != null && i.selectedVariant!.isNotEmpty) {
          final s1 = i.selectedVariant!.trim().toLowerCase().replaceAll(' ', '');
          final s2 = variant.name.trim().toLowerCase().replaceAll(' ', '');
          return s1 == s2;
        }
        return isDefaultVariant;
      }
      return false;
    }).toList() ?? [];

    final inCartQty = matchingItems.fold<int>(0, (sum, i) => sum + i.quantity);

    final discount = variant.mrp > variant.price && variant.mrp > 0
        ? ((variant.mrp - variant.price) / variant.mrp * 100).round()
        : 0;

    final isSelected = inCartQty > 0;
    final isSoldOut = !widget.product.isAvailable || variant.stock <= 0;
    final variantProduct = _buildVariantProduct(variant);
    final isCompact = cardWidth < 125;

    // Compute unit price string (e.g. per 100g or per 100ml)
    String unitRateStr = '';
    final nameLower = variant.name.toLowerCase();
    final numMatch = RegExp(r'(\d+)\s*(g|gm|kg|ml|l|ltr)').firstMatch(nameLower);
    if (numMatch != null) {
      final val = double.tryParse(numMatch.group(1) ?? '') ?? 0;
      final unitType = numMatch.group(2) ?? '';
      if (val > 0) {
        if (unitType == 'g' || unitType == 'gm') {
          final per100 = (variant.price / val) * 100;
          unitRateStr = '₹${per100.toStringAsFixed(per100 < 10 ? 1 : 0)}/100 g';
        } else if (unitType == 'kg') {
          final per100 = (variant.price / (val * 1000)) * 100;
          unitRateStr = '₹${per100.toStringAsFixed(per100 < 10 ? 1 : 0)}/100 g';
        } else if (unitType == 'ml') {
          final per100 = (variant.price / val) * 100;
          unitRateStr = '₹${per100.toStringAsFixed(per100 < 10 ? 1 : 0)}/100 ml';
        } else if (unitType == 'l' || unitType == 'ltr') {
          final per100 = (variant.price / (val * 1000)) * 100;
          unitRateStr = '₹${per100.toStringAsFixed(per100 < 10 ? 1 : 0)}/100 ml';
        }
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF9FA) : Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(
          color: isSelected ? const Color(0xFFE20A22) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image with Add Button inside/below
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: isCompact ? 80 : 106,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                      ? Transform.scale(
                          scale: 1.05,
                          child: CachedNetworkImage(
                            imageUrl: widget.product.imageUrl!.startsWith('/')
                                ? 'https://www.fastkirana.in${widget.product.imageUrl!}'
                                : widget.product.imageUrl!,
                            fit: BoxFit.contain,
                            memCacheWidth: 200,
                            memCacheHeight: 200,
                            errorWidget: (_, __, ___) => Center(
                              child: Text('🛒', style: TextStyle(fontSize: isCompact ? 24 : 30)),
                            ),
                          ),
                        )
                      : Center(
                          child: Text('🛒', style: TextStyle(fontSize: isCompact ? 24 : 30)),
                        ),
                ),
              ),

              // Stepper or Add Button overlaying bottom right of image box
              Positioned(
                bottom: 4,
                right: 4,
                child: isSoldOut
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          'Sold Out',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : (!isStoreOpen)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              'Closed',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : (inCartQty == 0)
                            ? InkWell(
                                onTap: () {
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
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: isCompact ? 26 : 32,
                                  height: isCompact ? 26 : 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE20A22), width: 1.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1AE20A22),
                                        blurRadius: 4,
                                        offset: Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(Icons.add, size: isCompact ? 15 : 18, color: const Color(0xFFE20A22)),
                                  ),
                                ),
                              )
                            : Container(
                                height: isCompact ? 26 : 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE20A22), width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1AE20A22),
                                      blurRadius: 4,
                                      offset: Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (matchingItems.isNotEmpty) {
                                          ref.read(cartProvider.notifier).decrement(matchingItems.last.productId);
                                        } else {
                                          ref.read(cartProvider.notifier).decrement(variantProductId);
                                        }
                                      },
                                      child: SizedBox(
                                        width: isCompact ? 20 : 26,
                                        height: isCompact ? 26 : 32,
                                        child: Center(
                                          child: Icon(Icons.remove, size: isCompact ? 12 : 15, color: const Color(0xFFE20A22)),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 3),
                                      child: Text(
                                        '$inCartQty',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE20A22),
                                          fontWeight: FontWeight.w900,
                                          fontSize: isCompact ? 11 : 13,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        if (variant.stock > 0 && inCartQty >= variant.stock) {
                                          HapticFeedback.heavyImpact();
                                          StockNoticeHelper.showStockLimit(
                                            context: context,
                                            stock: variant.stock,
                                            hasFloatingCart: true,
                                          );
                                          return;
                                        }
                                        HapticFeedback.lightImpact();
                                        final added = ref.read(cartProvider.notifier).addProduct(variantProduct, 1, variant.name);
                                        if (!added) {
                                          StockNoticeHelper.showStockLimit(
                                            context: context,
                                            stock: variant.stock,
                                            hasFloatingCart: true,
                                          );
                                        }
                                      },
                                      child: SizedBox(
                                        width: isCompact ? 20 : 26,
                                        height: isCompact ? 26 : 32,
                                        child: Center(
                                          child: Icon(Icons.add, size: isCompact ? 12 : 15, color: const Color(0xFFE20A22)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),

          SizedBox(height: isCompact ? 6 : 8),

          // 2. Pack Size Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              variant.name,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 3),

          // 3. Discount Tag
          if (discount > 0)
            Text(
              '$discount% OFF',
              style: GoogleFonts.inter(
                fontSize: isCompact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
              ),
            ),

          const SizedBox(height: 2),

          // 4. Price Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${variant.price.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 13 : 14.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (variant.mrp > variant.price) ...[
                const SizedBox(width: 3),
                Text(
                  '₹${variant.mrp.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 9.5 : 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),

          // 5. Unit Rate
          if (unitRateStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Text(
                unitRateStr,
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZeptoBottomBar(BuildContext context) {
    final cart = ref.watch(cartProvider).value;
    double productTotal = 0;
    int productTotalQty = 0;
    if (cart != null) {
      for (final item in cart.items) {
        if (item.productId == widget.product.id || item.productId.startsWith('${widget.product.id}_')) {
          productTotal += item.product.price * item.quantity;
          productTotalQty += item.quantity;
        }
      }
    }

    if (productTotalQty == 0) {
      return SizedBox(
        height: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 16,
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 10
            : 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE20A22), // FastMinute Red
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item Total: ₹${productTotal.toStringAsFixed(1)}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14.5),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Confirm',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
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
