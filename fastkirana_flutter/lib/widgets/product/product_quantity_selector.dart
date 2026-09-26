import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../cart_conflict_dialog.dart';
import '../variant_selector_sheet.dart';

// ─── Add To Cart Button & Quantity Stepper ─────────────────────────────────

class AddToCartButton extends ConsumerWidget {
  final BuildContext scaffoldContext;
  final Product product;
  final int inCartQty;
  final bool hasVariants;
  final bool isOutOfStock;
  final bool isTimingClosed;
  final String? nextSlot;
  final bool isStoreOpen;
  final bool isFood;
  final List<Color> gradientColors;
  final Color primaryColor;
  final double uiScale;

  const AddToCartButton({
    super.key,
    required this.scaffoldContext,
    required this.product,
    required this.inCartQty,
    required this.hasVariants,
    required this.isOutOfStock,
    required this.isTimingClosed,
    this.nextSlot,
    required this.isStoreOpen,
    required this.isFood,
    required this.gradientColors,
    required this.primaryColor,
    required this.uiScale,
  });

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget btn;
    if (isOutOfStock) {
      btn = _soldOut();
    } else if (!isStoreOpen) {
      btn = _storeClosed();
    } else if (inCartQty > 0) {
      btn = _stepper(context, ref);
    } else {
      btn = _addButton(context, ref);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: btn,
    );
  }

  Widget _soldOut() {
    return Container(
      height: s(30),
      padding: EdgeInsets.symmetric(horizontal: s(8)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(s(8)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: s(0.9)),
      ),
      alignment: Alignment.center,
      child: Text(
        'SOLD OUT',
        style: GoogleFonts.plusJakartaSans(
          fontSize: s(9.0),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _storeClosed() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: s(8)),
                Expanded(
                  child: Text(
                    isFood
                        ? '${product.restaurant?.name ?? "This Restaurant"} is currently closed.'
                        : 'FastKirana Grocery Darkstore is currently closed.',
                    style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        height: s(30),
        padding: EdgeInsets.symmetric(horizontal: s(7)),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.8), width: s(0.85)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: s(11), color: const Color(0xFF64748B)),
            SizedBox(width: s(2.5)),
            Text(
              'CLOSED',
              style: GoogleFonts.plusJakartaSans(
                fontSize: s(9.0),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(BuildContext context, WidgetRef ref) {
    return Container(
      height: s(31),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(s(8)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.30),
            blurRadius: s(6),
            offset: Offset(0, s(2)),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(s(8))),
            onTap: () {
              HapticFeedback.lightImpact();
              if (hasVariants) {
                VariantSelectorSheet.show(context, product);
              } else {
                ref.read(cartProvider.notifier).decrement(product.id);
              }
            },
            child: SizedBox(
              width: s(26),
              height: s(31),
              child: Center(
                child: Icon(Icons.remove_rounded, size: s(14), color: Colors.white),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(minWidth: s(18)),
            alignment: Alignment.center,
            child: Text(
              '$inCartQty',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: s(12.5),
                letterSpacing: -0.2,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(s(8))),
            onTap: () {
              if (hasVariants) {
                VariantSelectorSheet.show(context, product);
              } else {
                if (product.stock > 0 && inCartQty >= product.stock) {
                  HapticFeedback.heavyImpact();
                  _showStockLimitSnackbar();
                  return;
                }
                final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                if (conflict != null) {
                  _showConflictDialog(context, ref);
                } else {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).increment(product);
                }
              }
            },
            child: SizedBox(
              width: s(26),
              height: s(31),
              child: Center(
                child: Icon(Icons.add_rounded, size: s(14), color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context, WidgetRef ref) {
    return Bounceable(
      scaleFactor: 0.92,
      onTap: () {
        HapticFeedback.lightImpact();
        if (hasVariants) {
          VariantSelectorSheet.show(context, product);
        } else {
          _handleAdd(context, ref);
        }
      },
      child: Container(
        height: s(31),
        padding: EdgeInsets.symmetric(horizontal: s(12)),
        decoration: BoxDecoration(
          color: isFood ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(s(8)),
          border: Border.all(
            color: isFood ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
            width: s(1.3),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: s(5),
              offset: Offset(0, s(1.5)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ADD',
              style: GoogleFonts.plusJakartaSans(
                fontSize: s(12.0),
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: s(2.5)),
            Icon(Icons.add_rounded, size: s(15), color: primaryColor),
          ],
        ),
      ),
    );
  }

  void _showStockLimitSnackbar() {
    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
            SizedBox(width: s(8)),
            Expanded(
              child: Text(
                'Only ${product.stock} units available in stock!',
                style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref) {
    CartConflictDialog.show(
      scaffoldContext,
      product: product,
      existingOutletName: ref.read(cartProvider.notifier).currentRestaurantName ?? '',
      groceryItemsCount: ref.read(cartProvider.notifier).groceryItemsCount,
      onConfirm: () => ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1),
    );
  }

  void _handleAdd(BuildContext context, WidgetRef ref) {
    if (product.stock <= 0 || !product.isAvailable) {
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: Text('${product.name} is currently out of stock.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
        ),
      );
      return;
    }
    final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflict != null) {
      _showConflictDialog(context, ref);
      return;
    }
    final success = ref.read(cartProvider.notifier).addProduct(product, 1);
    if (!success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
              SizedBox(width: s(8)),
              Expanded(
                child: Text(
                  'Cannot add more! Only ${product.stock} units available in stock.',
                  style: GoogleFonts.inter(fontSize: s(12), fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(10))),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─── Variant Pill Widget ───────────────────────────────────────────────────

class VariantPill extends StatelessWidget {
  final Product product;
  final List variants;
  final bool hasVariants;
  final bool isOutOfStock;
  final bool isFood;
  final double uiScale;

  const VariantPill({
    super.key,
    required this.product,
    required this.variants,
    required this.hasVariants,
    required this.isOutOfStock,
    required this.isFood,
    required this.uiScale,
  });

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context) {
    if (hasVariants) {
      final label = variants.isNotEmpty ? '${variants.length} Options' : 'Customise';
      return GestureDetector(
        onTap: () {
          if (!isOutOfStock) VariantSelectorSheet.show(context, product);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: s(4)),
          padding: EdgeInsets.symmetric(horizontal: s(6), vertical: s(2.2)),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(s(6)),
            border: Border.all(color: const Color(0xFFE2E8F0), width: s(0.85)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: s(9.2),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              SizedBox(width: s(2)),
              Icon(Icons.keyboard_arrow_down_rounded, size: s(12), color: const Color(0xFF64748B)),
            ],
          ),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(bottom: s(4)),
      padding: EdgeInsets.symmetric(horizontal: s(5.5), vertical: s(2)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(s(5)),
        border: Border.all(color: const Color(0xFFF1F5F9), width: s(0.85)),
      ),
      child: Text(
        product.unit.isNotEmpty && product.unit != '1 unit' ? product.unit : (isFood ? 'Serves 1' : '1 pc'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: s(9.2),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
