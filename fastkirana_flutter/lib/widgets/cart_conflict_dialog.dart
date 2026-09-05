import '../core/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/product.dart';
import '../core/utils/restaurant_utils.dart';

class CartConflictDialog extends StatelessWidget {
  final Product product;
  final String existingOutletName;
  final int groceryItemsCount;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const CartConflictDialog({
    super.key,
    required this.product,
    required this.existingOutletName,
    required this.groceryItemsCount,
    required this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Product product,
    required String existingOutletName,
    required int groceryItemsCount,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CartConflictDialog(
        product: product,
        existingOutletName: existingOutletName,
        groceryItemsCount: groceryItemsCount,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newOutletName = getOutletName(product);
    final newOutletShortName = newOutletName.split(' ').first;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. TOP ICON BADGE
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppDesignSystem.statusPending,
                shape: BoxShape.circle,
                border: Border.all(color: AppDesignSystem.yellow200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignSystem.warning.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 26,
                  color: AppDesignSystem.amber600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. TITLE
            Text(
              'Switch Restaurant?',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 18),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 3. DESCRIPTION
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate500,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Your cart contains dishes from '),
                  TextSpan(
                    text: existingOutletName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.amber600,
                    ),
                  ),
                  const TextSpan(
                    text: '. You can only order food from 1 restaurant at a time.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. SELECTED DISH PREVIEW CARD
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                children: [
                  // Product Thumbnail
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppDesignSystem.slate100),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!.startsWith('/')
                                  ? 'https://www.fastkirana.in${product.imageUrl}'
                                  : product.imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              maxWidthDiskCache: 200,
                              maxHeightDiskCache: 200,
                              errorWidget: (_, __, ___) => Center(child: Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                            )
                          : Center(child: Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.green50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.emerald200),
                          ),
                          child: Text(
                            newOutletName.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.emerald700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.name,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${product.price.toInt()} • ${product.unit}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 5. GROCERY SAFETY REASSURANCE BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.emerald200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppDesignSystem.green600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groceryItemsCount > 0
                          ? 'Your $groceryItemsCount Grocery item(s) will stay safe in your cart!'
                          : 'Grocery items can always be combined with any restaurant!',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.green700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. ACTION BUTTONS (Cancel & Confirm Switch)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(false);
                      onCancel?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: AppDesignSystem.slate300),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppDesignSystem.orange600,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Switch to $newOutletShortName',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

