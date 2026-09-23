import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/dish_timing.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/cart_conflict_dialog.dart';
import '../cart/cart_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selectedVariant;
  final Map<String, Set<String>> _selectedAddons = {};
  bool _isFavorite = false;
  bool _isNotified = false;
  static const Color primaryRed = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    final variants = widget.product.parsedVariants;
    if (variants.isNotEmpty) {
      _selectedVariant = variants.reduce((a, b) => a.price < b.price ? a : b);
    }
  }

  Product _buildCustomizedProduct(Product p, ProductVariant? variant, List<AddonItem> selectedAddonItems) {
    final addonTotal = selectedAddonItems.fold(0.0, (sum, a) => sum + a.price);
    final basePrice = variant?.price ?? p.price;
    final baseMrp = variant != null ? (variant.mrp > 0 ? variant.mrp : variant.price) : (p.mrp > 0 ? p.mrp : p.price);
    final finalPrice = basePrice + addonTotal;
    final finalMrp = (baseMrp > 0 ? baseMrp : basePrice) + addonTotal;

    final discount = finalMrp > finalPrice && finalMrp > 0
        ? ((finalMrp - finalPrice) / finalMrp * 100).round()
        : 0;

    final addonSuffix = selectedAddonItems.isNotEmpty
        ? ' + ${selectedAddonItems.map((a) => a.name).join(', ')}'
        : '';
    final addonIdSuffix = selectedAddonItems.isNotEmpty
        ? '_addons_${selectedAddonItems.map((a) => a.name.replaceAll(' ', '-')).join('_')}'
        : '';
    final baseId = variant != null ? '${p.id}_${variant.name}' : p.id;
    final baseName = variant != null ? '${p.name} (${variant.name})' : p.name;
    final unitName = variant != null ? variant.name : p.unit;

    return Product(
      id: '$baseId$addonIdSuffix',
      name: '$baseName$addonSuffix',
      slug: p.slug,
      description: p.description,
      imageUrl: p.imageUrl,
      categoryId: p.categoryId,
      restaurantId: p.restaurantId,
      mrp: finalMrp,
      price: finalPrice,
      discount: discount.toDouble(),
      unit: unitName,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags,
      variants: p.variants,
      addons: p.addons,
      minStock: p.minStock,
      expiryDate: p.expiryDate,
      costPrice: p.costPrice,
      location: p.location,
      isFlashDeal: p.isFlashDeal,
      isTopPick: p.isTopPick,
      isBestSeller: p.isBestSeller,
      sortOrder: p.sortOrder,
      availableStartTime: p.availableStartTime,
      availableEndTime: p.availableEndTime,
      barcode: p.barcode,
      createdAt: p.createdAt,
      category: p.category,
      restaurant: p.restaurant,
      menuSection: p.menuSection,
    );
  }

  void _addToCart(Product p, ProductVariant? activeVariant, List<AddonItem> selectedAddonItems, bool isStoreOpen) {
    if (!isStoreOpen || !p.isAvailable || p.stock <= 0) return;

    // Validate required addon groups
    for (final group in p.parsedAddons) {
      if (group.required) {
        final selected = _selectedAddons[group.title] ?? {};
        if (selected.isEmpty) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select an option for "${group.title}"',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppDesignSystem.red600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    }

    final customizedProduct = _buildCustomizedProduct(p, activeVariant, selectedAddonItems);
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(customizedProduct);
    if (conflictRestaurant != null) {
      _promptRestaurantConflict(context, customizedProduct, activeVariant?.name);
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addProduct(customizedProduct, 1, activeVariant?.name);
  }

  void _promptRestaurantConflict(BuildContext context, Product product, String? variantName) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant == null) return;

    final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
    final newOutlet = getOutletName(product);

    CartConflictDialog.show(
      context,
      product: product,
      existingOutletName: conflictRestaurant,
      groceryItemsCount: groceryCount,
      onConfirm: () {
        ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1, variantName);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.emerald700,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Switched to $newOutlet order',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareProduct(Product p, double activePrice) {
    HapticFeedback.lightImpact();
    final priceStr = '₹${activePrice.toStringAsFixed(0)}';
    final productSlug = p.slug.isNotEmpty ? p.slug : p.id;
    final shareText = '''🛒 Check out ${p.name} ($priceStr) on FastKirana!\n\n⚡ Instant 10-Min Delivery in Ghatampur!\nOrder now: https://www.fastkirana.in/products/$productSlug''';
    Share.share(shareText, subject: 'Buy ${p.name} on FastKirana');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final variants = p.parsedVariants;
    final hasVariants = variants.isNotEmpty;
    final activeVariant = _selectedVariant ?? (hasVariants ? variants.first : null);

    // Calculate addon total
    double addonTotal = 0.0;
    final List<AddonItem> selectedAddonItems = [];
    for (final group in p.parsedAddons) {
      final selected = _selectedAddons[group.title] ?? {};
      for (final item in group.items) {
        if (selected.contains(item.name)) {
          addonTotal += item.price;
          selectedAddonItems.add(item);
        }
      }
    }

    final basePrice = activeVariant?.price ?? p.price;
    final baseMrp = activeVariant?.mrp ?? p.mrp;
    final activePrice = basePrice + addonTotal;
    final activeMrp = (baseMrp > 0 ? baseMrp : basePrice) + addonTotal;
    final activeUnit = activeVariant != null
        ? activeVariant.name
        : (p.unit.isNotEmpty && p.unit != '1 pc' && p.unit != '1 unit'
            ? p.unit
            : (isRestaurantProduct(p) ? 'Freshly Prepared' : 'Standard Pack'));

    final effectiveProduct = _buildCustomizedProduct(p, activeVariant, selectedAddonItems);
    final effectiveProductId = effectiveProduct.id;

    final cart = ref.watch(cartProvider).value;
    final cartItem = cart?.items.where((i) =>
        i.productId == effectiveProductId ||
        (selectedAddonItems.isEmpty && activeVariant == null && (i.productId == p.id || i.product.id == p.id)) ||
        (selectedAddonItems.isEmpty && activeVariant != null && i.selectedVariant == activeVariant.name && (i.productId == p.id || i.product.id == p.id))).firstOrNull;
    final inCartQty = cartItem?.quantity ?? 0;
    final discountPct = activeMrp > activePrice && activeMrp > 0
        ? (((activeMrp - activePrice) / activeMrp) * 100).toInt()
        : p.discount.toInt();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: Stack(
          children: [
            // Scrollable Content
            ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 0, 0, 100 + bottomInset),
            children: [
              // 1. Product Image Carousel with Discount Badge
              Stack(
                children: [
                  Container(
                    height: 360,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    child: Center(
                      child: Hero(
                        tag: 'product_image_${p.id}',
                        child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: p.imageUrl!,
                                height: 260,
                                fit: BoxFit.contain,
                                memCacheWidth: 800,
                                memCacheHeight: 800,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(color: primaryRed),
                                ),
                                errorWidget: (_, __, ___) => Center(child: Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 72)))),
                              )
                            : Center(child: Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 72)))),
                      ),
                    ),
                  ),

                  // Discount Badge
                  if (discountPct > 0)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.statusCancelled,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDesignSystem.rose200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                            const SizedBox(width: 4),
                            Text(
                              '$discountPct% OFF',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w900,
                                color: primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // 2. Product Details Box
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Speed & Outlet Badge Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.green50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignSystem.emerald200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 14, color: AppDesignSystem.emerald600),
                              const SizedBox(width: 4),
                              Text(
                                'FAST DELIVERY',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: AppDesignSystem.emerald700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRestaurantProduct(p)) ...[
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final outletName = getOutletName(p);
                              Color chipColor = AppDesignSystem.amber600;
                              Color chipBg = AppDesignSystem.amber50;
                              if (outletName.contains('Wedson')) {
                                chipColor = AppDesignSystem.orange600;
                                chipBg = AppDesignSystem.orange50;
                              } else if (outletName.contains('Bal Udyan')) {
                                chipColor = AppDesignSystem.violet600;
                                chipBg = AppDesignSystem.violet50;
                              } else if (outletName.contains('Pari') || outletName.contains('Dairy')) {
                                chipColor = AppDesignSystem.emerald700;
                                chipBg = AppDesignSystem.green50;
                              } else if (outletName.contains('A.S')) {
                                chipColor = AppDesignSystem.cyan600;
                                chipBg = AppDesignSystem.sky50;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: chipColor.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded, size: 13, color: chipColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      outletName,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w800,
                                        color: chipColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      p.name,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 20),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.gray900,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 150.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 150.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 4),

                    // Unit
                    Text(
                      activeUnit,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 250.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 250.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 14),

                    // Price and MRP Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${activePrice.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 24),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.gray900,
                          ),
                        ),
                        if (activeMrp > activePrice) ...[
                          const SizedBox(width: 10),
                          Text(
                            '₹${activeMrp.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 16),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              color: AppDesignSystem.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.green100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save ₹${(activeMrp - activePrice).toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.green700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 350.ms).slideY(begin: 0.06, end: 0, duration: 350.ms, delay: 350.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 18),

                    // Variants / Pack Sizes (if available)
                    if (variants.isNotEmpty) ...[
                      Text(
                        'Select Pack Size / Variant',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.gray900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: variants.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final variant = variants[index];
                            final isSelected = _selectedVariant?.name == variant.name;

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedVariant = variant);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppDesignSystem.statusCancelled : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? primaryRed : AppDesignSystem.border,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      variant.name,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12),
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? primaryRed : AppDesignSystem.gray900,
                                      ),
                                    ),
                                    Text(
                                      '₹${variant.price.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w900,
                                        color: isSelected ? primaryRed : AppDesignSystem.gray600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Customization / Addon Options (if available)
                    if (p.parsedAddons.isNotEmpty) ...[
                      ...p.parsedAddons.map((group) {
                        final selectedSet = _selectedAddons[group.title] ?? {};
                        final isRadio = group.maxSelect == 1;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    group.title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 14),
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.gray900,
                                    ),
                                  ),
                                  if (group.required)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppDesignSystem.statusCancelled,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'REQUIRED',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9.5),
                                          fontWeight: FontWeight.w900,
                                          color: primaryRed,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRadio
                                    ? 'Select any 1'
                                    : 'Select up to ${group.maxSelect}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w500,
                                  color: AppDesignSystem.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppDesignSystem.border),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: group.items.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppDesignSystem.surfaceMuted,
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
                                            if (current.contains(addon.name)) {
                                              if (!group.required) {
                                                current.remove(addon.name);
                                              }
                                            } else {
                                              current.clear();
                                              current.add(addon.name);
                                            }
                                          } else {
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
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            // Radio / Checkbox
                                            if (isRadio)
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isChecked ? primaryRed : AppDesignSystem.gray400,
                                                    width: isChecked ? 2 : 1.5,
                                                  ),
                                                ),
                                                child: isChecked
                                                    ? Center(
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration: const BoxDecoration(
                                                            color: primaryRed,
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
                                                  borderRadius: BorderRadius.circular(5),
                                                  color: isChecked ? primaryRed : Colors.transparent,
                                                  border: Border.all(
                                                    color: isChecked ? primaryRed : AppDesignSystem.gray400,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: isChecked
                                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                                    : null,
                                              ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                addon.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                                  fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                                  color: isChecked ? AppDesignSystem.gray900 : AppDesignSystem.gray700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              addon.price > 0 ? '+ ₹${addon.price.toInt()}' : 'Free',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 13),
                                                fontWeight: FontWeight.w700,
                                                color: addon.price > 0 ? AppDesignSystem.gray700 : AppDesignSystem.emerald700,
                                              ),
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

                    // Product Highlights & Quality Promise
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppDesignSystem.border),
                      ),
                      child: Column(
                        children: [
                          _buildQualityRow('⚡ Superfast express delivery from local darkstore'),
                          const Divider(height: 14, color: AppDesignSystem.surfaceMuted),
                          _buildQualityRow('🛡️ 100% Genuine & Quality assured by FastKirana'),
                          const Divider(height: 14, color: AppDesignSystem.surfaceMuted),
                          _buildQualityRow('🔒 100% Secure Checkout via UPI & Cards'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description (if exists)
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      Text(
                        'Product Details',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.gray900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDesignSystem.border),
                        ),
                        child: Text(
                          p.description!,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w500,
                            color: AppDesignSystem.gray600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // 3. Floating Glass Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppDesignSystem.gray900),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isFavorite = !_isFavorite);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 20,
                              color: _isFavorite ? primaryRed : AppDesignSystem.gray900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Bounceable(
                          onTap: () => _shareProduct(p, activePrice),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.share_outlined, size: 20, color: AppDesignSystem.gray900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Bounceable(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, size: 20, color: AppDesignSystem.gray900),
                              ),
                              if ((cart?.totalItems ?? 0) > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: const BoxDecoration(
                                      color: primaryRed,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${cart!.totalItems}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Sticky Bottom Add to Cart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (inCartQty == 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Price',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                        Text(
                          '₹${activePrice.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 20),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.gray900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                  ],
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isFood = isRestaurantProduct(p);
                        final settings = ref.watch(storeSettingsProvider).valueOrNull;
                        final isGroceryOpen = settings?.groceryMartOpen ?? true;
                        final isRestaurantOpen = RestaurantScheduleHelper.isProductRestaurantOpen(
                          p,
                          storeSettings: settings,
                        );
                        final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

                        final isOutOfStock = p.stock <= 0 || !p.isAvailable;
                        final timingStatus = isFood && (p.availableStartTime != null && p.availableStartTime!.trim().isNotEmpty)
                            ? checkDishTimeAvailability(
                                p.availableStartTime,
                                p.availableEndTime,
                              )
                            : const DishTimingStatus(isAvailableNow: true);

                        if (isOutOfStock) {
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() => _isNotified = true);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppDesignSystem.slate900,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.notifications_active_rounded, color: AppDesignSystem.warning, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '🔔 We will notify you instantly when ${p.name} is back in stock!',
                                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isNotified ? AppDesignSystem.green50 : AppDesignSystem.amber50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _isNotified ? AppDesignSystem.emerald200 : AppDesignSystem.yellow200,
                                  width: 1.2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isNotified ? Icons.check_circle_rounded : Icons.notifications_active_outlined,
                                    size: 17,
                                    color: _isNotified ? AppDesignSystem.emerald700 : AppDesignSystem.amber700,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _isNotified ? 'Notification Enabled ✓' : 'Notify When Available',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13),
                                      fontWeight: FontWeight.w900,
                                      color: _isNotified ? AppDesignSystem.emerald700 : AppDesignSystem.amber700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!timingStatus.isAvailableNow) {
                          return Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppDesignSystem.amber50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppDesignSystem.yellow200),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              timingStatus.nextAvailableTimeStr != null
                                   ? 'Next @ ${timingStatus.nextAvailableTimeStr}'
                                  : 'Not Available Right Now',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.amber600,
                              ),
                            ),
                          );
                        }

                        if (!isStoreOpen) {
                          return Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppDesignSystem.slate100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppDesignSystem.slate200),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Store Currently Closed',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate400,
                              ),
                            ),
                          );
                        }

                        if (inCartQty > 0) {
                          return Row(
                            children: [
                              // 1. Compact Stepper (- Qty +)
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          ref.read(cartProvider.notifier).decrement(cartItem?.productId ?? (cartItem?.id ?? effectiveProductId));
                                        },
                                        child: Container(
                                          width: 34,
                                          height: 48,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.remove_rounded, size: 18, color: primaryRed),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 26),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$inCartQty',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14.5),
                                          fontWeight: FontWeight.w900,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(13)),
                                        onTap: () {
                                           if (p.stock > 0 && inCartQty >= p.stock) {
                                            HapticFeedback.heavyImpact();
                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Only ${p.stock} units available in stock!',
                                                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: Colors.white),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: AppDesignSystem.red600,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                            return;
                                          }
                                          final conflictRestaurant =
                                              ref.read(cartProvider.notifier).checkRestaurantConflict(effectiveProduct);
                                          if (conflictRestaurant != null) {
                                            _promptRestaurantConflict(context, effectiveProduct, _selectedVariant?.name);
                                            return;
                                          }
                                          HapticFeedback.lightImpact();
                                          ref.read(cartProvider.notifier).increment(cartItem?.product ?? effectiveProduct);
                                        },
                                        child: Container(
                                          width: 34,
                                          height: 48,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.add_rounded, size: 18, color: primaryRed),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 2. Direct "View Cart & Checkout ➔" Action Button
                              Expanded(
                                child: Bounceable(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
                                  },
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppDesignSystem.green700, AppDesignSystem.accentDark],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppDesignSystem.green700.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${cart?.totalItems ?? inCartQty} ${(cart?.totalItems ?? inCartQty) == 1 ? 'ITEM' : 'ITEMS'}',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white.withValues(alpha: 0.85),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Text(
                                              '₹${(cart?.subtotal ?? (inCartQty * activePrice)).toInt()}',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'View Cart',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return GestureDetector(
                          onTap: () => _addToCart(p, activeVariant, selectedAddonItems, isStoreOpen),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryRed, AppDesignSystem.primaryDark],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add to Cart',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 14),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
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
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildQualityRow(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.gray700,
            ),
          ),
        ),
      ],
    );
  }
}
