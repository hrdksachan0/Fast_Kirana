import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../data/models/product.dart';

import '../../providers/cart_provider.dart';

import '../cart_conflict_dialog.dart';

import '../variant_selector_sheet.dart';

import '../../core/utils/stock_notice_helper.dart';

import '../../core/utils/app_haptics.dart';



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

  final bool isZeptoStyle;



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

    this.isZeptoStyle = false,

  });



  double s(double v) => v * uiScale;



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget btn;
    String stateKey;
    if (isOutOfStock) {
      btn = _soldOut();
      stateKey = 'sold_out';
    } else if (!isStoreOpen) {
      btn = _storeClosed();
      stateKey = 'closed';
    } else if (inCartQty > 0) {
      btn = _stepper(context, ref);
      stateKey = 'stepper';
    } else if (isZeptoStyle) {
      btn = _zeptoAddButton(context, ref);
      stateKey = 'zepto_add';
    } else {
      btn = _addButton(context, ref);
      stateKey = 'add';
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 190),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerRight,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.88, end: 1.0).animate(animation),
                alignment: Alignment.centerRight,
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(stateKey),
            child: btn,
          ),
        ),
      ),
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

        AppHaptics.subtleTap();

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

                        : 'FastMinute Grocery Darkstore is currently closed.',

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

        height: s(26),

        padding: EdgeInsets.symmetric(horizontal: s(5.5), vertical: s(2)),

        decoration: BoxDecoration(

          color: Colors.white.withValues(alpha: 0.94),

          borderRadius: BorderRadius.circular(s(7)),

          border: Border.all(color: const Color(0xFFCBD5E1), width: s(0.85)),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: 0.08),

              blurRadius: 3,

              offset: const Offset(0, 1),

            ),

          ],

        ),

        alignment: Alignment.center,

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(Icons.schedule_rounded, size: s(10.5), color: const Color(0xFF64748B)),

            SizedBox(width: s(2)),

            Text(

              'CLOSED',

              style: GoogleFonts.plusJakartaSans(

                fontSize: s(8.5),

                fontWeight: FontWeight.w800,

                color: const Color(0xFF64748B),

                letterSpacing: 0,

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _stepper(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).value;
    final matchingItems = cart?.items.where((i) => i.productId == product.id || i.productId.startsWith('${product.id}_')).toList() ?? [];
    final stepperColor = isFood ? primaryColor : const Color(0xFF318616);

    final int effectiveMaxStock = hasVariants
        ? (matchingItems.length == 1
            ? product.getStockForVariant(matchingItems.first.selectedVariant)
            : 0)
        : product.stock;
    final bool isMaxStockReached = effectiveMaxStock > 0 && inCartQty >= effectiveMaxStock;
    final Color plusColor = isMaxStockReached
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white;

    final double stepperHeight = isFood ? s(36) : s(44);
    final double stepperWidth = isFood ? s(68) : s(76);
    final double stepperRadius = isFood ? s(8.5) : s(10.5);

    return Container(
      height: stepperHeight,
      width: stepperWidth,
      decoration: BoxDecoration(
        color: stepperColor,
        borderRadius: BorderRadius.circular(stepperRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: s(3.5),
            offset: Offset(0, s(1.2)),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Decrement Button — full left-third edge-to-edge touch target (zero dead edge)
          Expanded(
            flex: 10,
            child: Semantics(
              button: true,
              label: 'Decrease quantity',
              child: Bounceable(
                scaleFactor: 0.82,
                onTap: () {
                  AppHaptics.smoothTick();
                  if (hasVariants) {
                    if (matchingItems.length == 1) {
                      ref.read(cartProvider.notifier).decrement(matchingItems.first.productId);
                    } else {
                      VariantSelectorSheet.show(context, product);
                    }
                  } else {
                    ref.read(cartProvider.notifier).decrement(product.id);
                  }
                },
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: s(11.5),
                      height: s(2.1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(s(1.2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Count — ALWAYS absorbs taps so tapping the number never leaks to ProductCard!
          Expanded(
            flex: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (hasVariants) {
                  AppHaptics.smoothTick();
                  VariantSelectorSheet.show(context, product);
                }
              },
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.78, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text(
                    '$inCartQty',
                    key: ValueKey(inCartQty),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: s(16.5),
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Increment Button — full right-third edge-to-edge touch target (zero dead edge)
          Expanded(
            flex: 10,
            child: Semantics(
              button: true,
              label: 'Increase quantity',
              child: Bounceable(
                scaleFactor: 0.82,
                onTap: () {
                  if (hasVariants) {
                    if (matchingItems.length == 1) {
                      final singleItem = matchingItems.first;
                      final effectiveItemStock = product.getStockForVariant(singleItem.selectedVariant);
                      if (effectiveItemStock > 0 && inCartQty >= effectiveItemStock) {
                        AppHaptics.alertPulse();
                        _showStockLimitSnackbar(ref, customStock: effectiveItemStock);
                        return;
                      }
                      AppHaptics.smoothTick();
                      final success = ref.read(cartProvider.notifier).addProduct(singleItem.product, 1, singleItem.selectedVariant);
                      if (!success) {
                        _showStockLimitSnackbar(ref, customStock: effectiveItemStock);
                      }
                    } else {
                      VariantSelectorSheet.show(context, product);
                    }
                  } else {
                    if (product.stock > 0 && inCartQty >= product.stock) {
                      AppHaptics.alertPulse();
                      _showStockLimitSnackbar(ref);
                      return;
                    }
                    final conflict = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
                    if (conflict != null) {
                      _showConflictDialog(context, ref);
                    } else {
                      AppHaptics.smoothTick();
                      ref.read(cartProvider.notifier).increment(product);
                    }
                  }
                },
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: SizedBox(
                      width: s(11.5),
                      height: s(11.5),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: s(11.5),
                            height: s(2.1),
                            decoration: BoxDecoration(
                              color: plusColor,
                              borderRadius: BorderRadius.circular(s(1.2)),
                            ),
                          ),
                          Container(
                            width: s(2.1),
                            height: s(11.5),
                            decoration: BoxDecoration(
                              color: plusColor,
                              borderRadius: BorderRadius.circular(s(1.2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context, WidgetRef ref) {
    if (!isFood && hasVariants) {
      final variants = product.parsedVariants;
      final optCount = variants.isNotEmpty ? variants.length : 2;

      return Bounceable(
        scaleFactor: 0.94,
        onTap: () {
          AppHaptics.smoothAdd();
          VariantSelectorSheet.show(context, product);
        },
        child: Container(
          width: s(64),
          height: s(45),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(10.5)),
            border: Border.all(
              color: const Color(0xFF318616),
              width: s(1.4),
            ),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(s(10.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: s(3.5),
                offset: Offset(0, s(1.2)),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                flex: 11,
                child: Center(
                  child: Text(
                    'ADD',
                    style: GoogleFonts.inter(
                      fontSize: s(13.5),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF318616),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEAF6E8),
                  child: Column(
                    children: [
                      Container(
                        height: s(0.8),
                        color: const Color(0xFF318616).withValues(alpha: 0.22),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '$optCount options',
                            style: GoogleFonts.inter(
                              fontSize: s(8.6),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF318616),
                            ),
                          ),
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

    final btnColor = isFood ? primaryColor : const Color(0xFF318616);

    return Bounceable(
      scaleFactor: 0.94,
      onTap: () {
        AppHaptics.smoothAdd();
        if (hasVariants) {
          VariantSelectorSheet.show(context, product);
        } else {
          _handleAdd(context, ref);
        }
      },
      child: Container(
        width: isFood ? s(56) : s(60),
        height: isFood ? s(36) : s(43),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isFood ? s(8.5) : s(10.5)),
          border: Border.all(
            color: btnColor,
            width: s(1.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: s(3.5),
              offset: Offset(0, s(1.2)),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'ADD',
            style: GoogleFonts.inter(
              fontSize: isFood ? s(13.0) : s(14.0),
              fontWeight: FontWeight.w800,
              color: btnColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _zeptoAddButton(BuildContext context, WidgetRef ref) {

    return Bounceable(

      scaleFactor: 0.94,

      onTap: () {

        AppHaptics.smoothAdd();

        if (hasVariants) {

          VariantSelectorSheet.show(context, product);

        } else {

          _handleAdd(context, ref);

        }

      },

      child: Container(

        width: s(38),

        height: s(38),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(s(9.5)),

          border: Border.all(color: const Color(0xFF16A34A), width: s(1.6)),

          boxShadow: [

            BoxShadow(

              color: const Color(0xFF16A34A).withValues(alpha: 0.22),

              blurRadius: s(6),

              offset: Offset(0, s(2)),

            ),

          ],

        ),

        child: Center(

          child: Icon(Icons.add, size: s(27), color: const Color(0xFF16A34A)),

        ),

      ),

    );

  }



  void _showStockLimitSnackbar(WidgetRef ref, {int? customStock}) {

    final cartItems = ref.read(cartProvider).value?.totalItems ?? 0;

    StockNoticeHelper.showStockLimit(

      context: scaffoldContext,

      stock: customStock ?? product.getStockForVariant(null),

      hasFloatingCart: cartItems > 0,

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

    final cartItems = ref.read(cartProvider).value?.totalItems ?? 0;

    if (!product.isInStock) {

      StockNoticeHelper.showStockLimit(

        context: scaffoldContext,

        stock: 0,

        hasFloatingCart: cartItems > 0,

        customMessage: '${product.name} is currently out of stock.',

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

      final effStock = product.getStockForVariant(null);

      _showStockLimitSnackbar(ref, customStock: effStock);

    }

  }

}



// ─── Variant Pill Widget ───────────────────────────────────────────────────



class VariantPill extends StatelessWidget {
  final dynamic product;
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

  String _resolveUnitString() {
    try {
      final dynamic p = product;
      dynamic raw;
      try {
        raw = p.unit;
      } catch (_) {}
      if (raw == null) {
        try {
          raw = p.name;
        } catch (_) {}
      }
      if (raw == null) {
        try {
          raw = p.title;
        } catch (_) {}
      }
      if (raw == null) return isFood ? 'Serves 1' : '1 pc';
      final u = raw.toString().trim();
      if (u.isEmpty || u == '1 unit') return isFood ? 'Serves 1' : '1 pc';
      if (u.toLowerCase() == 'serving') return '1 Serving';
      return u;
    } catch (_) {
      return isFood ? 'Serves 1' : '1 pc';
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (hasVariants) {
        final firstVarName = variants.isNotEmpty ? (variants.first.name ?? '').toString().trim() : '';
        final displayUnit = firstVarName.isNotEmpty ? firstVarName : _resolveUnitString();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!isOutOfStock) VariantSelectorSheet.show(context, product);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayUnit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: s(10.2),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: s(1)),
              Icon(Icons.keyboard_arrow_down_rounded, size: s(12.5), color: const Color(0xFF64748B)),
            ],
          ),
        );
      }

      return Text(
        _resolveUnitString(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: s(11.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

