import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/admin_notification_service.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/restaurant_utils.dart';
import '../../../../data/models/order.dart';

class _ShareOutletOption {
  final String id;
  final String title;
  final String subtitle;
  final String icon; // '🍽️' or '🛒' or '📦'
  final bool isRestaurant;
  final bool isCombined;
  final String token;
  final List<OrderItem> items;
  final String message;
  final String? phone;

  _ShareOutletOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isRestaurant,
    this.isCombined = false,
    required this.token,
    required this.items,
    required this.message,
    this.phone,
  });
}

/// Modal bottom sheet for sharing separate KOT & order packing slips via WhatsApp or system share sheet.
/// Intelligently separates Restaurant Kitchen orders and Grocery Darkstore orders
/// so cooks never get grocery lists and grocery pickers never get food prep notes!
class AdminShareSheet {
  static void show(
    BuildContext context,
    Order order, {
    List<Order>? allOrders,
    String? initialOutletId,
  }) {
    HapticFeedback.lightImpact();

    Order resolvedOrder = order;
    if (order.combinedId != null &&
        order.combinedId!.isNotEmpty &&
        (order.subOrders == null || order.subOrders!.length < 2) &&
        allOrders != null) {
      final siblings = allOrders.where((o) => o.combinedId == order.combinedId).toList();
      if (siblings.length > 1) {
        final primary = siblings.firstWhere(
          (o) => (o.readableId ?? '').toUpperCase().endsWith('-G'),
          orElse: () => siblings.first,
        );

        final allItems = <OrderItem>[];
        final seenItemKeys = <String>{};
        for (final sub in siblings) {
          if (sub.items != null) {
            for (final item in sub.items!) {
              final key = item.id.isNotEmpty
                  ? item.id
                  : '${item.name.toLowerCase().trim()}_${item.selectedVariant?.toLowerCase().trim() ?? ""}_${item.notes?.toLowerCase().trim() ?? ""}';
              if (seenItemKeys.add(key)) {
                final isRest = item.isRestaurantItem || (sub.isRestaurantOrder && item.restaurantId != null);
                allItems.add(item.copyWith(
                  restaurantId: isRest ? (item.restaurantId ?? sub.restaurantId) : null,
                  shopName: isRest
                      ? (item.shopName ?? sub.shopName ?? 'Restaurant Kitchen')
                      : 'FastMinute Dark Store',
                ));
              }
            }
          }
        }

        final combinedTotal = siblings.fold<double>(0.0, (sum, o) => sum + o.total);
        final baseReadableId = (primary.readableId ?? '').replaceAll(RegExp(r'-[GR]\d*$', caseSensitive: false), '');

        resolvedOrder = primary.copyWith(
          readableId: baseReadableId.isNotEmpty ? baseReadableId : primary.readableId,
          items: allItems,
          total: combinedTotal,
          combinedId: order.combinedId,
          isCombined: true,
          subOrders: siblings,
        );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AdminShareSheetContent(order: resolvedOrder, initialOutletId: initialOutletId),
    );
  }
}

class _AdminShareSheetContent extends StatefulWidget {
  final Order order;
  final String? initialOutletId;

  const _AdminShareSheetContent({
    required this.order,
    this.initialOutletId,
  });

  @override
  State<_AdminShareSheetContent> createState() => _AdminShareSheetContentState();
}

class _AdminShareSheetContentState extends State<_AdminShareSheetContent> {
  late List<_ShareOutletOption> _options;
  final Set<String> _sharedSlips = {};
  String? _previewingOutletId;

  @override
  void initState() {
    super.initState();
    _options = _buildOptions(widget.order);
  }

  static List<_ShareOutletOption> _buildOptions(Order order) {
    final List<_ShareOutletOption> list = [];
    final allItems = order.items ?? [];

    // 1. If explicit subOrders are present in a combined order
    if (order.isCombined && order.subOrders != null && order.subOrders!.length > 1) {
      for (int i = 0; i < order.subOrders!.length; i++) {
        final sub = order.subOrders![i];
        final isRest = sub.isRestaurantOrder;
        final subItems = sub.items ?? [];
        final token = sub.readableId ?? (order.readableId != null ? '${order.readableId}-${isRest ? "R" : "G"}' : sub.id);
        final outletName = isRest
            ? ((sub.shopName != null &&
                    sub.shopName!.trim().isNotEmpty &&
                    !sub.shopName!.toLowerCase().contains('dark store') &&
                    !sub.shopName!.toLowerCase().contains('fastminute store') &&
                    !sub.shopName!.toLowerCase().contains('fastkirana store'))
                ? sub.shopName!.trim()
                : (RestaurantRegistry.getName(sub.restaurantId) ?? 'Restaurant Kitchen'))
            : 'FastMinute Mart';

        final msg = isRest
            ? AdminNotificationService.formatRestaurantKOTMessage(
                order,
                specificItems: subItems,
                outletName: outletName,
                orderToken: token,
              )
            : AdminNotificationService.formatGroceryPackingMessage(
                order,
                specificItems: subItems,
                outletName: outletName,
                orderToken: token,
              );

        list.add(_ShareOutletOption(
          id: isRest ? 'restaurant_${sub.id}' : 'grocery_${sub.id}',
          title: outletName,
          subtitle: '${subItems.length} items',
          icon: isRest ? '🍽️' : '🛒',
          isRestaurant: isRest,
          token: token,
          items: subItems,
          message: msg,
          phone: sub.shopPhone ?? (isRest ? RestaurantRegistry.find(sub.restaurantId)?.phone : null),
        ));
      }
    } else if (order.isRestaurantOrder && !order.isCombined) {
      // Pure non-combined Restaurant order: ALL items belong to this restaurant KOT!
      final restToken = order.readableId ?? order.displayId;
      final restOutletName = (order.shopName != null &&
              order.shopName!.trim().isNotEmpty &&
              !order.shopName!.toLowerCase().contains('dark store') &&
              !order.shopName!.toLowerCase().contains('fastminute store') &&
              !order.shopName!.toLowerCase().contains('fastkirana store'))
          ? order.shopName!.trim()
          : (RestaurantRegistry.getName(order.restaurantId) ?? 'Restaurant Kitchen');

      list.add(_ShareOutletOption(
        id: 'restaurant',
        title: restOutletName,
        subtitle: '${allItems.length} food items',
        icon: '🍽️',
        isRestaurant: true,
        token: restToken,
        items: allItems,
        message: AdminNotificationService.formatRestaurantKOTMessage(
          order,
          specificItems: allItems,
          outletName: restOutletName,
          orderToken: restToken,
        ),
        phone: order.shopPhone ?? RestaurantRegistry.find(order.restaurantId)?.phone,
      ));
    } else if (!order.isRestaurantOrder && !order.isCombined) {
      // Pure non-combined Grocery order: ALL items belong to FastMinute Mart!
      final groceryToken = order.readableId ?? order.displayId;
      list.add(_ShareOutletOption(
        id: 'grocery',
        title: 'FastMinute Mart',
        subtitle: '${allItems.length} grocery items',
        icon: '🛒',
        isRestaurant: false,
        token: groceryToken,
        items: allItems,
        message: AdminNotificationService.formatGroceryPackingMessage(
          order,
          specificItems: allItems,
          outletName: 'FastMinute Mart (Dark Store)',
          orderToken: groceryToken,
        ),
      ));
    } else {
      // 2. Partition items by isRestaurantItem
      final restItems = allItems.where((i) => i.isRestaurantItem).toList();
      final groceryItems = allItems.where((i) => !i.isRestaurantItem).toList();

      if (restItems.isNotEmpty && groceryItems.isNotEmpty) {
        // Both restaurant and grocery items present!
        final restToken = order.readableId != null ? '${order.readableId}-R' : '${order.displayId}-R';
        final groceryToken = order.readableId != null ? '${order.readableId}-G' : '${order.displayId}-G';
        final restOutletName = (order.shopName != null &&
                order.shopName!.trim().isNotEmpty &&
                !order.shopName!.toLowerCase().contains('dark store') &&
                !order.shopName!.toLowerCase().contains('fastminute store') &&
                !order.shopName!.toLowerCase().contains('fastkirana store'))
            ? order.shopName!.trim()
            : (RestaurantRegistry.getName(order.restaurantId) ?? 'Restaurant Kitchen');

        list.add(_ShareOutletOption(
          id: 'restaurant',
          title: restOutletName,
          subtitle: '${restItems.length} food items',
          icon: '🍽️',
          isRestaurant: true,
          token: restToken,
          items: restItems,
          message: AdminNotificationService.formatRestaurantKOTMessage(
            order,
            specificItems: restItems,
            outletName: restOutletName,
            orderToken: restToken,
          ),
          phone: order.shopPhone ?? RestaurantRegistry.find(order.restaurantId)?.phone,
        ));

        list.add(_ShareOutletOption(
          id: 'grocery',
          title: 'FastMinute Mart',
          subtitle: '${groceryItems.length} grocery items',
          icon: '🛒',
          isRestaurant: false,
          token: groceryToken,
          items: groceryItems,
          message: AdminNotificationService.formatGroceryPackingMessage(
            order,
            specificItems: groceryItems,
            outletName: 'FastMinute Mart (Dark Store)',
            orderToken: groceryToken,
          ),
        ));
      } else if (restItems.isNotEmpty || order.isRestaurantOrder) {
        final items = restItems.isNotEmpty ? restItems : allItems;
        final restToken = order.readableId ?? order.displayId;
        final restOutletName = (order.shopName != null &&
                order.shopName!.trim().isNotEmpty &&
                !order.shopName!.toLowerCase().contains('dark store') &&
                !order.shopName!.toLowerCase().contains('fastminute store') &&
                !order.shopName!.toLowerCase().contains('fastkirana store'))
            ? order.shopName!.trim()
            : (RestaurantRegistry.getName(order.restaurantId) ?? 'Restaurant Kitchen');

        list.add(_ShareOutletOption(
          id: 'restaurant',
          title: restOutletName,
          subtitle: '${items.length} items',
          icon: '🍽️',
          isRestaurant: true,
          token: restToken,
          items: items,
          message: AdminNotificationService.formatRestaurantKOTMessage(
            order,
            specificItems: items,
            outletName: restOutletName,
            orderToken: restToken,
          ),
          phone: order.shopPhone ?? RestaurantRegistry.find(order.restaurantId)?.phone,
        ));
      } else {
        // Pure grocery
        final items = groceryItems.isNotEmpty ? groceryItems : allItems;
        final groceryToken = order.readableId ?? order.displayId;

        list.add(_ShareOutletOption(
          id: 'grocery',
          title: 'FastMinute Mart',
          subtitle: '${items.length} items',
          icon: '🛒',
          isRestaurant: false,
          token: groceryToken,
          items: items,
          message: AdminNotificationService.formatGroceryPackingMessage(
            order,
            specificItems: items,
            outletName: 'FastMinute Mart (Dark Store)',
            orderToken: groceryToken,
          ),
        ));
      }
    }

    // Always add Combined Full Order option if there are multiple parts
    if (list.length > 1) {
      list.add(_ShareOutletOption(
        id: 'combined_full',
        title: 'Full Combined Order',
        subtitle: '${allItems.length} total items',
        icon: '📦',
        isRestaurant: false,
        isCombined: true,
        token: order.readableId ?? order.displayId,
        items: allItems,
        message: AdminNotificationService.formatCombinedOrderMessage(order),
      ));
    }

    return list;
  }

  Future<void> _shareWhatsApp(String message, String token, {String? slipId}) async {
    if (slipId != null) {
      setState(() => _sharedSlips.add(slipId));
    }
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          AppToast.showSuccess(
            context,
            'Opened in WhatsApp! 📲',
            subtitle: 'Choose contact to send slip for #$token',
          );
        }
        return;
      }
    } catch (_) {}
    await Share.share(message, subject: 'FastMinute Order #$token');
  }

  Future<void> _shareDirectWhatsApp(String phone, String message, {String? slipId}) async {
    if (slipId != null) {
      setState(() => _sharedSlips.add(slipId));
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          AppToast.showSuccess(
            context,
            'WhatsApp Opened! 💬',
            subtitle: 'Message loaded for +91 $cleanPhone',
          );
        }
        return;
      }
    } catch (_) {}
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) return const SizedBox.shrink();

    final order = widget.order;
    final cleanCustomerPhone = (order.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final cleanRiderPhone = (order.deliveryBoyPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');

    final restaurantOptions = _options.where((o) => o.isRestaurant).toList();
    final groceryOptions = _options.where((o) => !o.isRestaurant && !o.isCombined).toList();
    final combinedOption = _options.firstWhere(
      (o) => o.isCombined,
      orElse: () => _options.first,
    );

    final isMultiOutlet = _options.length > 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMultiOutlet ? const Color(0xFFEFF6FF) : (restaurantOptions.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMultiOutlet ? const Color(0xFFBFDBFE) : (restaurantOptions.isNotEmpty ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                    width: 1,
                  ),
                ),
                child: Text(
                  isMultiOutlet ? '⚡' : (restaurantOptions.isNotEmpty ? '🍽️' : '🛒'),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Slips • Order #${order.readableId ?? order.displayId}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                    Text(
                      isMultiOutlet
                          ? 'Send KOT to Kitchen & Packing Slip to Mart separately'
                          : 'Send slip to cooks, dark store, rider, or customer',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 22, color: AppDesignSystem.slate400),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable outlet cards
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. RESTAURANT KITCHEN SLIPS
                  if (restaurantOptions.isNotEmpty) ...[
                    ...restaurantOptions.map((opt) => _buildOutletCard(
                          opt: opt,
                          accentColor: const Color(0xFFE11D48),
                          bgColor: const Color(0xFFFFF1F2),
                          borderColor: const Color(0xFFFECDD3),
                          buttonText: 'Share KOT to Kitchen (WhatsApp)',
                        )),
                    const SizedBox(height: 12),
                  ],

                  // 2. GROCERY DARK STORE SLIPS
                  if (groceryOptions.isNotEmpty) ...[
                    ...groceryOptions.map((opt) => _buildOutletCard(
                          opt: opt,
                          accentColor: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          borderColor: const Color(0xFFBBF7D0),
                          buttonText: 'Share Packing Slip to Mart (WhatsApp)',
                        )),
                    const SizedBox(height: 14),
                  ],

                  // 3. DELIVERY RIDER & CUSTOMER SECTION
                  _buildDeliveryAndCustomerSection(
                    context,
                    order: order,
                    cleanCustomerPhone: cleanCustomerPhone,
                    cleanRiderPhone: cleanRiderPhone,
                    combinedOption: combinedOption,
                    isMultiOutlet: isMultiOutlet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard({
    required _ShareOutletOption opt,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required String buttonText,
  }) {
    final isShared = _sharedSlips.contains(opt.id);
    final isPreviewOpen = _previewingOutletId == opt.id;
    final cleanDirectPhone = (opt.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet Title & Items Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(opt.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          Text(
                            'Slip #${opt.token} • ${opt.subtitle}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isShared)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Text(
                        'Shared',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Items summary chips
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...opt.items.take(4).map((it) {
                  final variant = (it.selectedVariant != null && it.selectedVariant!.isNotEmpty)
                      ? ' (${it.selectedVariant})'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• ${it.name}$variant × ${it.quantity}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.slate700, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                if (opt.items.length > 4)
                  Text(
                    '+ ${opt.items.length - 4} more items',
                    style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppDesignSystem.slate500),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: WhatsApp Share & Direct Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareWhatsApp(opt.message, opt.token, slipId: opt.id),
                  icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                  label: Text(
                    buttonText,
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Copy Button
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: opt.message));
                  AppToast.showSuccess(context, 'Slip Copied to Clipboard! 📋');
                },
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppDesignSystem.slate600),
                tooltip: 'Copy slip text',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              // Preview Toggle
              IconButton(
                onPressed: () {
                  setState(() {
                    _previewingOutletId = isPreviewOpen ? null : opt.id;
                  });
                },
                icon: Icon(
                  isPreviewOpen ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppDesignSystem.slate600,
                ),
                tooltip: 'Preview slip message',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),

          // Direct Send to Outlet Phone if available
          if (cleanDirectPhone.length >= 10) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _shareDirectWhatsApp(cleanDirectPhone, opt.message, slipId: opt.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.send_rounded, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'Direct WhatsApp to ${opt.title} (+91 $cleanDirectPhone)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Collapsible preview box
          if (isPreviewOpen) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    opt.message,
                    style: GoogleFonts.firaCode(fontSize: 9.5, color: AppDesignSystem.slate800, height: 1.3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryAndCustomerSection(
    BuildContext context, {
    required Order order,
    required String cleanCustomerPhone,
    required String cleanRiderPhone,
    required _ShareOutletOption combinedOption,
    required bool isMultiOutlet,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded, size: 18, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                'DELIVERY & CUSTOMER SLIPS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Send to Customer Tile
          if (cleanCustomerPhone.length >= 10) ...[
            _buildActionTile(
              icon: Icons.person_outline_rounded,
              iconColor: AppDesignSystem.orange600,
              title: 'Send Receipt to Customer (+91 $cleanCustomerPhone)',
              subtitle: 'Sends complete order receipt with items & delivery details',
              onTap: () {
                final custMsg = AdminNotificationService.formatCombinedOrderMessage(order);
                _shareDirectWhatsApp(cleanCustomerPhone, custMsg);
              },
            ),
            const SizedBox(height: 8),
          ],

          // Send to Rider Tile
          if (cleanRiderPhone.length >= 10) ...[
            _buildActionTile(
              icon: Icons.motorcycle_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: 'Send Checklist to Rider (+91 $cleanRiderPhone)',
              subtitle: 'Sends pickup & delivery checklist to assigned delivery partner',
              onTap: () {
                final riderMsg = AdminNotificationService.formatCombinedOrderMessage(order);
                _shareDirectWhatsApp(cleanRiderPhone, riderMsg);
              },
            ),
            const SizedBox(height: 8),
          ],

          // Share via Any App Tile
          _buildActionTile(
            icon: Icons.share_rounded,
            iconColor: AppDesignSystem.blue600,
            title: isMultiOutlet ? 'Share Full Combined Slip (Any App)' : 'Share via Any App',
            subtitle: 'Share slip via Telegram, SMS, Email, or system apps',
            onTap: () async {
              final msg = isMultiOutlet
                  ? AdminNotificationService.formatCombinedOrderMessage(order)
                  : combinedOption.message;
              await Share.share(msg, subject: 'FastMinute Order #${combinedOption.token}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.slate500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppDesignSystem.slate400),
          ],
        ),
      ),
    );
  }
}
