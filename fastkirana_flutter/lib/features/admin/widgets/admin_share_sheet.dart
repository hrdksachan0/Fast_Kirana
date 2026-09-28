import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/admin_notification_service.dart';
import '../../../../core/theme/design_system.dart';
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
  });
}

/// Modal bottom sheet for sharing KOT & order receipts via WhatsApp or system share sheet.
/// Intelligently separates Restaurant Kitchen orders and Grocery Darkstore orders
/// so cooks never get grocery lists and grocery pickers never get food prep notes!
class AdminShareSheet {
  static void show(BuildContext context, Order order, {String? initialOutletId}) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AdminShareSheetContent(order: order, initialOutletId: initialOutletId),
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
  int _selectedIndex = 0;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _options = _buildOptions(widget.order);

    if (widget.initialOutletId != null) {
      final idx = _options.indexWhere((o) => o.id == widget.initialOutletId);
      if (idx != -1) _selectedIndex = idx;
    }
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
            ? ((sub.shopName != null && sub.shopName!.trim().isNotEmpty && !sub.shopName!.toLowerCase().contains('dark store'))
                ? sub.shopName!.trim()
                : (RestaurantRegistry.getName(sub.restaurantId) ?? 'Restaurant Kitchen'))
            : 'FastKirana Mart';

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
          id: sub.id.isNotEmpty ? sub.id : 'sub_$i',
          title: outletName,
          subtitle: '${subItems.length} items',
          icon: isRest ? '🍽️' : '🛒',
          isRestaurant: isRest,
          token: token,
          items: subItems,
          message: msg,
        ));
      }
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
        ));

        list.add(_ShareOutletOption(
          id: 'grocery',
          title: 'FastKirana Mart',
          subtitle: '${groceryItems.length} grocery items',
          icon: '🛒',
          isRestaurant: false,
          token: groceryToken,
          items: groceryItems,
          message: AdminNotificationService.formatGroceryPackingMessage(
            order,
            specificItems: groceryItems,
            outletName: 'FastKirana Mart (Dark Store)',
            orderToken: groceryToken,
          ),
        ));
      } else if (restItems.isNotEmpty || order.isRestaurantOrder) {
        final items = restItems.isNotEmpty ? restItems : allItems;
        final restToken = order.readableId ?? order.displayId;
        final restOutletName = (order.shopName != null &&
                order.shopName!.trim().isNotEmpty &&
                !order.shopName!.toLowerCase().contains('dark store'))
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
        ));
      } else {
        // Pure grocery
        final items = groceryItems.isNotEmpty ? groceryItems : allItems;
        final groceryToken = order.readableId ?? order.displayId;

        list.add(_ShareOutletOption(
          id: 'grocery',
          title: 'FastKirana Mart',
          subtitle: '${items.length} items',
          icon: '🛒',
          isRestaurant: false,
          token: groceryToken,
          items: items,
          message: AdminNotificationService.formatGroceryPackingMessage(
            order,
            specificItems: items,
            outletName: 'FastKirana Mart (Dark Store)',
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

  Future<void> _shareWhatsApp(String message, String token) async {
    Navigator.pop(context);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await Share.share(message, subject: 'FastKirana Order #$token');
  }

  Future<void> _shareDirectWhatsApp(String phone, String message) async {
    Navigator.pop(context);
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) return const SizedBox.shrink();

    final activeOption = _options[_selectedIndex.clamp(0, _options.length - 1)];
    final order = widget.order;
    final cleanCustomerPhone = (order.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final cleanRiderPhone = (order.deliveryBoyPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final isMultiOutlet = _options.length > 1;


    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
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
                    color: activeOption.isRestaurant ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activeOption.isRestaurant ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      width: 1,
                    ),
                  ),
                  child: Text(activeOption.icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Order #${activeOption.token}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                      Text(
                        isMultiOutlet
                            ? 'Separate slips for Restaurant Kitchen & Grocery Mart'
                            : 'Send order slip / KOT to cooks, dark store, or riders',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Preview Button
                IconButton(
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                  icon: Icon(
                    _showPreview ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppDesignSystem.slate600,
                  ),
                  tooltip: 'Preview Message',
                ),
              ],
            ),

            // If order has multiple outlets (Restaurant + Grocery), show clean, spacious selector tabs
            if (isMultiOutlet) ...[
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(_options.length, (idx) {
                    final opt = _options[idx];
                    final isSel = idx == _selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSel
                                ? (opt.isRestaurant ? const Color(0xFFE11D48) : const Color(0xFF16A34A))
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? Colors.transparent : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: (opt.isRestaurant ? const Color(0xFFE11D48) : const Color(0xFF16A34A)).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(opt.icon, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                '${opt.title} (${opt.items.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: isSel ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],


            // Message Preview Box (Collapsible)
            if (_showPreview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MESSAGE PREVIEW (${activeOption.title}):',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppDesignSystem.slate600),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: activeOption.message));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message copied to clipboard! ✅'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.copy_rounded, size: 12, color: AppDesignSystem.blue600),
                              const SizedBox(width: 3),
                              Text('Copy', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppDesignSystem.blue600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Text(
                          activeOption.message,
                          style: GoogleFonts.firaCode(fontSize: 10, color: AppDesignSystem.slate800, height: 1.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Option 1: WhatsApp (Pick ANY Contact / Group)
            _buildShareOptionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Share on WhatsApp',
              subtitle: 'Send ${activeOption.title} slip to any cook, rider, or contact',
              onTap: () => _shareWhatsApp(activeOption.message, activeOption.token),
            ),
            const SizedBox(height: 10),

            // Option 2: General Share Sheet (Any App)
            _buildShareOptionTile(
              icon: Icons.share_outlined,
              iconColor: AppDesignSystem.blue600,
              title: 'Share via Any App',
              subtitle: 'Telegram, SMS, Email, or other apps',
              onTap: () async {
                Navigator.pop(context);
                await Share.share(activeOption.message, subject: 'FastKirana Order #${activeOption.token}');
              },
            ),

            if (cleanCustomerPhone.length >= 10) ...[
              const SizedBox(height: 10),
              // Option 3: Direct to Customer
              _buildShareOptionTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppDesignSystem.orange600,
                title: 'Send to Customer ($cleanCustomerPhone)',
                subtitle: 'Send order confirmation receipt directly to customer on WhatsApp',
                onTap: () {
                  // For customer, use full combined receipt if multiple outlets
                  final custMsg = isMultiOutlet
                      ? AdminNotificationService.formatCombinedOrderMessage(order)
                      : activeOption.message;
                  _shareDirectWhatsApp(cleanCustomerPhone, custMsg);
                },
              ),
            ],

            if (cleanRiderPhone.length >= 10) ...[
              const SizedBox(height: 10),
              // Option 4: Direct to Rider
              _buildShareOptionTile(
                icon: Icons.delivery_dining_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'Send to Rider ($cleanRiderPhone)',
                subtitle: 'Send pickup & delivery checklist to assigned rider on WhatsApp',
                onTap: () => _shareDirectWhatsApp(cleanRiderPhone, activeOption.message),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildShareOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
          ],
        ),
      ),
    );
  }
}
