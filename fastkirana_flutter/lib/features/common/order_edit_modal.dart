import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/app_toast.dart';
import '../../core/services/admin_notification_service.dart';
import 'order_edit/add_item_search_sheet.dart';

class OrderEditModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final bool isRestaurant;
  final bool isAdmin;
  final String? restaurantId;
  final VoidCallback onOrderUpdated;

  const OrderEditModal({
    super.key,
    required this.order,
    required this.isRestaurant,
    this.isAdmin = false,
    this.restaurantId,
    required this.onOrderUpdated,
  });

  @override
  ConsumerState<OrderEditModal> createState() => _OrderEditModalState();
}

class _OrderEditModalState extends ConsumerState<OrderEditModal> {
  late List<Map<String, dynamic>> _items;
  final Set<String> _outOfStockProductIds = {};
  bool _isSaving = false;

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color brandAmber = Color(0xFFD97706);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    final rawItems = widget.order['items'];
    if (rawItems is List) {
      _items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      _items = [];
    }
  }

  double _calculateSubtotal() {
    double sum = 0.0;
    for (final it in _items) {
      final qty = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : 1;
      final price = (it['price'] is num)
          ? (it['price'] as num).toDouble()
          : (double.tryParse(it['price']?.toString() ?? '0') ?? 0.0);
      sum += price * qty;
    }
    return sum;
  }

  void _updateQuantity(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final currentQty =
          (_items[index]['quantity'] is num) ? (_items[index]['quantity'] as num).toInt() : 1;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        final pId = _items[index]['productId']?.toString();
        if (pId != null && pId.isNotEmpty && !pId.startsWith('custom_')) {
          _outOfStockProductIds.add(pId);
        }
        _items.removeAt(index);
      } else {
        _items[index]['quantity'] = newQty;
      }
    });
  }

  void _removeItem(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final pId = _items[index]['productId']?.toString();
      if (pId != null && pId.isNotEmpty && !pId.startsWith('custom_')) {
        _outOfStockProductIds.add(pId);
      }
      _items.removeAt(index);
    });
  }

  void _showEditItemPriceDialog(int index) {
    final item = _items[index];
    final currentPrice = (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
    final controller = TextEditingController(text: currentPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Override Price: ${item['name']}',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Superpower: Set custom unit price for this order item',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                prefixText: '₹ ',
                labelText: 'Unit Price',
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: slateMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isAdmin ? brandAmber : primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newPrice = double.tryParse(controller.text.trim());
              if (newPrice != null && newPrice >= 0) {
                setState(() {
                  _items[index]['price'] = newPrice;
                });
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              }
            },
            child: Text('Update Price', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openItemPickerSheet({int? swapIndex}) {
    HapticFeedback.selectionClick();
    final effectiveRestId = widget.restaurantId ?? widget.order['restaurantId']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AddItemSearchSheet(
        isAdmin: widget.isAdmin,
        isRestaurant: widget.isRestaurant,
        restaurantId: effectiveRestId,
        isSwapMode: swapIndex != null,
        targetSwapItemName: swapIndex != null ? _items[swapIndex]['name'] : null,
        onProductSelected: (itemMap) {
          setState(() {
            if (swapIndex != null) {
              // Swap Mode: replace the item at swapIndex
              final oldPId = _items[swapIndex]['productId']?.toString();
              if (oldPId != null && oldPId.isNotEmpty && !oldPId.startsWith('custom_')) {
                _outOfStockProductIds.add(oldPId);
              }
              final oldQty = (_items[swapIndex]['quantity'] is num)
                  ? (_items[swapIndex]['quantity'] as num).toInt()
                  : 1;

              _items[swapIndex] = {
                ...itemMap,
                'quantity': oldQty, // Inherit previous quantity
              };
              AppToast.showSuccess(context, 'Swapped with ${itemMap['name']} ⇄');
            } else {
              // Add Mode: append to items list or increment quantity
              final existingIndex = _items.indexWhere(
                (it) => it['productId'] != null && it['productId'] == itemMap['productId'],
              );
              if (existingIndex != -1) {
                final currQty = (_items[existingIndex]['quantity'] is num)
                    ? (_items[existingIndex]['quantity'] as num).toInt()
                    : 1;
                _items[existingIndex]['quantity'] = currQty + 1;
              } else {
                _items.add(itemMap);
              }
              AppToast.showSuccess(context, 'Added ${itemMap['name']} to Order');
            }
          });
          HapticFeedback.heavyImpact();
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      AppToast.showError(context, 'Cannot save order with 0 items. Reject or cancel instead.');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    final orderId = (widget.order['id'] ?? widget.order['_id'])?.toString() ?? '';
    final readableId = widget.order['readableId']?.toString() ?? orderId;

    try {
      final dio = ref.read(dioProvider);
      final roleHeader = widget.isAdmin ? 'ADMIN' : (widget.isRestaurant ? 'CHEF' : 'PICKER');

      final payload = {
        'updatedItems': _items.map((it) => {
          'productId': it['productId'] ?? it['id'],
          'name': it['name'],
          'price': (it['price'] is num)
              ? (it['price'] as num).toDouble()
              : (double.tryParse(it['price']?.toString() ?? '0') ?? 0.0),
          'quantity': (it['quantity'] is num) ? (it['quantity'] as num).toInt() : 1,
          'selectedVariant': it['selectedVariant'],
          'notes': it['notes'],
          'imageUrl': it['imageUrl'],
        }).toList(),
        'outOfStockProductIds': _outOfStockProductIds.toList(),
      };

      final response = await dio.post(
        '/api/orders/$orderId/edit',
        data: payload,
        options: Options(headers: {
          'x-user-role': roleHeader,
          if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty)
            'x-restaurant-id': widget.restaurantId,
          'x-user-phone': '7054470303',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          AppToast.showSuccess(
            context,
            'Order #$readableId Updated! ⚡',
            subtitle: 'Bill adjusted & items synced across all consoles.',
          );
          widget.onOrderUpdated();
        }
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to update order');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (e is DioException) {
          final serverErr = e.response?.data;
          if (serverErr is Map && serverErr['error'] != null) {
            errorMsg = serverErr['error'].toString();
          } else if (serverErr is String && serverErr.isNotEmpty) {
            errorMsg = serverErr;
          }
        }
        AppToast.showError(context, 'Update Failed', subtitle: errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _sendCustomerSubstitution(Map<String, dynamic> item) {
    final phone = widget.order['user']?['phone'] ?? widget.order['customerPhone'] ?? widget.order['address']?['phone'] ?? '';
    final custName = widget.order['user']?['name'] ?? widget.order['customerName'] ?? 'Customer';
    final itemName = item['name']?.toString() ?? 'Item';
    final orderId = widget.order['readableId']?.toString() ?? widget.order['id']?.toString() ?? '';

    if (phone.toString().isEmpty) {
      AppToast.showInfo(context, 'No customer phone number available');
      return;
    }

    AdminNotificationService.sendSubstitutionWhatsApp(
      customerPhone: phone.toString(),
      customerName: custName.toString(),
      orderId: orderId,
      unavailableItem: itemName,
      suggestedReplacement: 'similar alternative',
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final orderId = widget.order['readableId'] ?? widget.order['id'] ?? '';

    final Color themeColor = widget.isAdmin
        ? brandAmber
        : (widget.isRestaurant ? primaryRed : brandGreen);

    final String titleText = widget.isAdmin
        ? 'Order Super-Editor'
        : (widget.isRestaurant ? 'Modify Kitchen Dishes' : 'Modify Picking Items');

    final String addButtonLabel = widget.isAdmin
        ? 'Add Item (Catalog / Custom)'
        : (widget.isRestaurant ? 'Add Dish from Menu' : 'Add Grocery Item');

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.isAdmin)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.bolt_rounded, size: 20, color: brandAmber),
                          )
                        else if (widget.isRestaurant)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text('👨‍🍳', style: TextStyle(fontSize: 16)),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text('📦', style: TextStyle(fontSize: 16)),
                          ),
                        Flexible(
                          child: Text(
                            titleText,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 16),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                        ),
                        if (widget.isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              'SUPERPOWER',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w900,
                                color: brandAmber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #$orderId  •  Live bill update on add/swap',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action: + Add Item to Order Button
          Bounceable(
            onTap: () => _openItemPickerSheet(swapIndex: null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isAdmin ? Icons.bolt_rounded : Icons.add_circle_outline_rounded,
                    color: themeColor,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    addButtonLabel,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 8),

          // Items List
          Flexible(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.remove_shopping_cart_rounded, size: 40, color: AppDesignSystem.slate400),
                          const SizedBox(height: 8),
                          Text('No items in this order', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: slateDark)),
                          const SizedBox(height: 4),
                          Text('Tap "+ Add Item" above to add items', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: AppDesignSystem.slate100),
                    itemBuilder: (context, idx) {
                      final it = _items[idx];
                      final name = (it['name'] ?? 'Item').toString();
                      final variant = it['selectedVariant']?.toString();
                      final notes = it['notes']?.toString();
                      final isCustom = it['isCustom'] == true || (it['productId']?.toString().startsWith('custom_') ?? false);
                      final price = (it['price'] is num)
                          ? (it['price'] as num).toDouble()
                          : (double.tryParse(it['price']?.toString() ?? '0') ?? 0.0);
                      final qty = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : 1;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                    ),
                                    if (isCustom)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Custom',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w800,
                                            color: AppDesignSystem.blue700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (variant != null && variant.isNotEmpty)
                                  Text(
                                    'Variant: $variant',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: brandAmber,
                                    ),
                                  ),
                                if (notes != null && notes.isNotEmpty)
                                  Text(
                                    'Note: $notes',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                      color: slateMuted,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () => _showEditItemPriceDialog(idx),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${price.toStringAsFixed(0)} each  •  Total: ₹${(price * qty).toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 11.5),
                                          fontWeight: FontWeight.w700,
                                          color: themeColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.edit_outlined, size: 12, color: themeColor),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Actions Row (Swap, Stepper, Delete)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // WhatsApp Contact Customer button (for pickers)
                              if (!widget.isRestaurant && !widget.isAdmin)
                                IconButton(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppDesignSystem.green600),
                                  tooltip: 'Suggest substitution via WhatsApp',
                                  onPressed: () => _sendCustomerSubstitution(it),
                                ),

                              // ⇄ Swap Button
                              Bounceable(
                                onTap: () => _openItemPickerSheet(swapIndex: idx),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF475569)),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Swap',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 10.5),
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Quantity Stepper
                              Container(
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.slate50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: slateBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _updateQuantity(idx, -1),
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Icon(Icons.remove_rounded, size: 14, color: slateDark),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        '$qty',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12),
                                          fontWeight: FontWeight.w900,
                                          color: slateDark,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _updateQuantity(idx, 1),
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Icon(Icons.add_rounded, size: 14, color: slateDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Delete Item
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppDesignSystem.red600),
                                onPressed: () => _removeItem(idx),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const Divider(height: 24, color: slateBorder),

          // Total & Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEW SUBTOTAL',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w900,
                      color: slateMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${subtotal.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 20),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Saving...' : (widget.isAdmin ? 'Save Order ⚡' : 'Save Changes'),
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

