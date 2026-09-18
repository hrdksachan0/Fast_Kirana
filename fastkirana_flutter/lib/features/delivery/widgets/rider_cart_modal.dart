import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/utils/validators.dart';

/// Opens the high-end "Photo View" Cart Modal for riders.
void showRiderCartModal(BuildContext context, Map<String, dynamic> order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RiderCartModal(order: order),
  );
}

/// A compact photo preview strip + "View Cart" button for Rider Cards.
class RiderCartPreviewWidget extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onViewCart;

  const RiderCartPreviewWidget({
    super.key,
    required this.order,
    this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final totalQty = items.fold<int>(
      0,
      (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1),
    );

    const maxThumbs = 4;
    final displayItems = items.take(maxThumbs).toList();
    final remainingCount = items.length > maxThumbs ? items.length - maxThumbs : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Items count + View Cart Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.indigo50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      size: 14,
                      color: AppDesignSystem.indigo700,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'ITEMS (${items.length})',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.indigo900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF), // indigo-100
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$totalQty qty',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.indigo700,
                      ),
                    ),
                  ),
                ],
              ),
              // View Cart Button
              Bounceable(
                onTap: () {
                  if (onViewCart != null) {
                    onViewCart!();
                  } else {
                    showRiderCartModal(context, order);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppDesignSystem.indigo500.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: AppDesignSystem.indigo700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View Cart',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.indigo700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: AppDesignSystem.indigo700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Photo Preview Strip
          Bounceable(
            onTap: () {
              if (onViewCart != null) {
                onViewCart!();
              } else {
                showRiderCartModal(context, order);
              }
            },
            child: Row(
              children: [
                ...displayItems.map((item) {
                  final rawImg = item['imageUrl'] ?? item['image'];
                  final imgUrl = Helpers.getImageUrl(rawImg?.toString());
                  final qty = item['quantity'] ?? 1;

                  return Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppDesignSystem.slate200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Center(
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.fastfood_outlined,
                                      size: 22,
                                      color: AppDesignSystem.slate400,
                                    ),
                                  )
                                : const Icon(
                                    Icons.fastfood_outlined,
                                    size: 22,
                                    color: AppDesignSystem.slate400,
                                  ),
                          ),
                        ),
                        if (qty is num && qty > 1)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.slate900,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${qty}x',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                if (remainingCount > 0)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppDesignSystem.slate300, style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Text(
                        '+$remainingCount',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate700,
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

                // Tap Prompt
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Photo View',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppDesignSystem.slate400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The BottomSheet modal presenting the exact "Photo View" type order cart.
class RiderCartModal extends StatelessWidget {
  final Map<String, dynamic> order;

  const RiderCartModal({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final isCombined = order['isCombined'] == true;
    final subOrders = (order['subOrders'] as List<dynamic>?) ?? [];
    final items = (order['items'] as List<dynamic>?) ?? [];
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = (order['paymentMethod'] ?? '').toString().toUpperCase().trim();
    final paymentStatus = (order['paymentStatus'] ?? '').toString().toUpperCase().trim();
    final isPaid = paymentStatus == 'PAID';
    final isCod = paymentMethod == 'COD' || paymentMethod.isEmpty;

    // Group items by outlet/suborder if multi-store
    List<_StoreGroup> groups = [];
    if (isCombined && subOrders.isNotEmpty) {
      for (final sub in subOrders) {
        if (sub is! Map) continue;
        final subMap = Map<String, dynamic>.from(sub);
        final subReadableId = (subMap['readableId'] ?? '').toString();
        final rawRestId = subMap['restaurantId']?.toString() ?? subMap['restaurant_id']?.toString();
        final rawShopName = (subMap['shopName'] ?? subMap['shop_name'])?.toString();
        final isRest = subReadableId.endsWith('-R') ||
            subReadableId.contains('-R-') ||
            subMap['orderType'] == 'RESTAURANT' ||
            (rawRestId != null && rawRestId.isNotEmpty && rawRestId != 'null') ||
            (rawShopName != null && RestaurantRegistry.find(rawShopName) != null);
        final shopName = (rawShopName?.trim().isNotEmpty == true &&
                rawShopName != 'FASTKIRANA DARK STORE' &&
                rawShopName != 'FastKirana Dark Store' &&
                rawShopName != 'FastKirana Store')
            ? rawShopName!.trim()
            : (isRest ? (RestaurantRegistry.getName(rawRestId) ?? 'RESTAURANT') : 'FASTKIRANA DARK STORE');
        final subItems = (subMap['items'] as List<dynamic>?) ?? [];

        groups.add(_StoreGroup(
          outletIcon: isRest ? '🍽️' : '🛒',
          storeTitle: shopName.toUpperCase(),
          badgeId: subReadableId.isNotEmpty ? '#$subReadableId' : '#$orderNum',
          items: subItems,
          isRestaurant: isRest,
        ));
      }
    } else {
      // Single store order
      final rawRestId = order['restaurantId']?.toString() ?? order['restaurant_id']?.toString();
      final rawShopName = (order['shopName'] ?? order['shop_name'])?.toString();
      final isFood = (order['orderType'] == 'RESTAURANT') ||
          (rawRestId != null && rawRestId.isNotEmpty && rawRestId != 'null') ||
          orderNum.contains('-R') ||
          (rawShopName != null && RestaurantRegistry.find(rawShopName) != null) ||
          items.any((it) {
            final itName = (it is Map ? it['name'] : null)?.toString();
            final itRestId = (it is Map ? (it['restaurantId'] ?? it['restaurant_id']) : null)?.toString();
            return (itRestId != null && itRestId.isNotEmpty && itRestId != 'null') ||
                RestaurantRegistry.isFoodDishName(itName);
          });
      final shopName = (rawShopName?.trim().isNotEmpty == true &&
              rawShopName != 'FASTKIRANA DARK STORE' &&
              rawShopName != 'FastKirana Dark Store' &&
              rawShopName != 'FastKirana Store')
          ? rawShopName!.trim()
          : (isFood ? (RestaurantRegistry.getName(rawRestId) ?? 'RESTAURANT') : 'FASTKIRANA DARK STORE');

      groups.add(_StoreGroup(
        outletIcon: isFood ? '🍽️' : '🛒',
        storeTitle: shopName.toUpperCase(),
        badgeId: '#$orderNum',
        items: items,
        isRestaurant: isFood,
      ));
    }

    final totalItemsCount = items.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Order Cart Items',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5), // emerald-50
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.emerald200),
                          ),
                          child: Text(
                            '$totalItemsCount items',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.emerald700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #$orderNum • Photo View',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),
                // Close button
                Bounceable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate700),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Main Scrollable Body with Store Groups & Photo View Items
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (context, groupIdx) {
                final group = groups[groupIdx];
                return _buildStoreGroupCard(context, group);
              },
            ),
          ),

          // Bottom Fixed Summary Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppDesignSystem.slate200, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Total Value & Payment Mode
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL BILL VALUE',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              '₹${total.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 17),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? AppDesignSystem.green100
                                    : (isCod ? AppDesignSystem.statusPending : AppDesignSystem.statusCancelled),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPaid ? 'PAID ONLINE' : (isCod ? 'COD CASH' : 'UNPAID'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 8.5),
                                  fontWeight: FontWeight.w900,
                                  color: isPaid
                                      ? AppDesignSystem.green700
                                      : (isCod ? AppDesignSystem.amber700 : AppDesignSystem.red600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Close / Confirm Button
                  Bounceable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppDesignSystem.slate900, AppDesignSystem.slate800],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
    );
  }

  /// Builds a Store Group Card matching the user's reference image:
  /// Header: 🛒 FASTKIRANA DARK STORE               #1749-G
  /// Items: Photo + Title + Variant + Line Price + (Qty x UnitPrice)
  Widget _buildStoreGroupCard(BuildContext context, _StoreGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0), // light border
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header Row: 🛒 FASTKIRANA DARK STORE    #1749-G
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFFAF7F5), // Light warm tinted header
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      group.outletIcon,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      group.storeTitle,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF475569), // slate-600 uppercase
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  group.badgeId,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8), // slate-400
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Items List inside this Store Group
          ...group.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == group.items.length - 1;

            final title = item['title'] ?? item['name'] ?? 'Item';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
            final lineTotal = unitPrice * qty;
            final variant = item['selectedVariant'] ?? item['variant'] ?? item['unit'];
            final rawImg = item['imageUrl'] ?? item['image'];
            final imgUrl = Helpers.getImageUrl(rawImg?.toString());
            final isRefunded = item['isRefunded'] == true || (item['refundAmount'] as num? ?? 0) > 0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Product Photo Container (52x52 with rounded corners)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Center(
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 1.8),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.fastfood_outlined,
                                      size: 22,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  )
                                : const Icon(
                                    Icons.fastfood_outlined,
                                    size: 22,
                                    color: Color(0xFF94A3B8),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Product Title + Variant
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A), // slate-900
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (variant != null && variant.toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                variant.toString().trim(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B), // slate-500
                                ),
                              ),
                            ],
                            if (isRefunded) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4E6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '↩️ Refunded',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFBE123C),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Price Block: Bold total price + (qty x unitPrice)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${lineTotal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$qty × ₹${unitPrice.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StoreGroup {
  final String outletIcon;
  final String storeTitle;
  final String badgeId;
  final List<dynamic> items;
  final bool isRestaurant;

  _StoreGroup({
    required this.outletIcon,
    required this.storeTitle,
    required this.badgeId,
    required this.items,
    required this.isRestaurant,
  });
}
