import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/cart.dart';
import '../../../providers/cart_provider.dart';

/// Item Row inside Cart with Thumbnail, Price, Unit, Savings, and Stepper
class CartItemRow extends ConsumerWidget {
  final CartItem item;

  const CartItemRow({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prod = item.product;
    final qty = item.quantity;
    final mrp = prod.mrp > prod.price ? prod.mrp : prod.price;
    final saveAmount = (mrp - prod.price) * qty;
    final isFood = isRestaurantProduct(prod);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Image Container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppCachedImage(
                imageUrl: prod.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                memCacheHeight: 200,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name, Unit & Price Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prod.name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
                if (prod.unit.isNotEmpty && !isFood) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      prod.unit.trim(),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      '₹${(prod.price * qty).toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                    if (mrp > prod.price)
                      Text(
                        '₹${(mrp * qty).toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          color: AppDesignSystem.slate400,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (saveAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green100,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Save ₹${saveAmount.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.green800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // High-End Modern Stepper Button (- 1 +)
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).decrement(prod.id);
                    },
                    child: Container(
                      width: 32,
                      height: 34,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: AppDesignSystem.primary,
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  alignment: Alignment.center,
                  child: Text(
                    '$qty',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                    onTap: () {
                      if (prod.stock > 0 && qty >= prod.stock) {
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
                                    'Only ${prod.stock} units available in stock!',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
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
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).increment(prod);
                    },
                    child: Container(
                      width: 32,
                      height: 34,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppDesignSystem.primary,
                      ),
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

/// Card Grouping items by source (Grocery Darkstore vs Restaurant Outlet)
class CartItemsSection extends StatelessWidget {
  final bool isGrocery;
  final String title;
  final String subtitle;
  final List<CartItem> items;
  final TextEditingController? cookingInstructionsController;

  const CartItemsSection({
    super.key,
    required this.isGrocery,
    required this.title,
    required this.subtitle,
    required this.items,
    this.cookingInstructionsController,
  });

  static const List<String> _suggestions = [
    '🌶️ Less Spicy',
    '🥫 Extra Sauce',
    '🧅 No Onion / Garlic',
    '🍬 Less Sweet',
    '🍽️ Add Cutlery',
    '🔥 Extra Crispy',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isGrocery ? const Color(0xFFFBFDFA) : const Color(0xFFFCFBFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isGrocery ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isGrocery ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isGrocery ? '📦' : '🍕',
                    style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items inside the section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  CartItemRow(item: items[i]),
                  if (i < items.length - 1)
                    const Divider(height: 12, thickness: 0.8, color: Color(0xFFF1F5F9)),
                ],
                if (!isGrocery && cookingInstructionsController != null) ...[
                  const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
                  _buildCookingInstructions(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookingInstructions(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        final controller = cookingInstructionsController!;
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('👨‍🍳', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cooking Instructions',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        Text(
                          'Special requests for $title',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w500,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          controller.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded, size: 12, color: AppDesignSystem.slate500),
                            const SizedBox(width: 3),
                            Text(
                              'Clear',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),

              // Suggestion Chips (Tap to Toggle/Add)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _suggestions.map((chip) {
                    final isPresent = controller.text.contains(chip);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            String current = controller.text.trim();
                            if (isPresent) {
                              current = current.replaceAll(chip, '').replaceAll(', ,', ',').trim();
                              if (current.startsWith(',')) current = current.substring(1).trim();
                              if (current.endsWith(',')) current = current.substring(0, current.length - 1).trim();
                              controller.text = current;
                            } else {
                              if (current.isEmpty) {
                                controller.text = chip;
                              } else {
                                controller.text = '$current, $chip';
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: isPresent ? const Color(0xFFFFF1F2) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPresent ? AppDesignSystem.primary : const Color(0xFFE2E8F0),
                              width: isPresent ? 1.3 : 1.0,
                            ),
                          ),
                          child: Text(
                            chip,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: isPresent ? FontWeight.w800 : FontWeight.w600,
                              color: isPresent ? AppDesignSystem.primary : AppDesignSystem.slate700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 9),

              // Interactive Styled Input Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: controller,
                  maxLines: 2,
                  minLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.slate900,
                  ),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppDesignSystem.slate400),
                    hintText: 'Type instructions (e.g. less spicy, no onion)...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      color: AppDesignSystem.slate400,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
