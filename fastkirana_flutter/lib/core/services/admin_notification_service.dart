import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order.dart';

class AdminNotificationService {
  /// Format a comprehensive, clean receipt message for Admin & Kitchen/Darkstore
  static String formatOrderWhatsAppMessage(Order order) {
    final orderId = order.readableId ?? (order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id);
    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'FastKirana Customer';
    final custPhone = order.customerPhone?.isNotEmpty == true ? order.customerPhone! : 'Not Provided';
    final custAddr = order.customerAddress?.isNotEmpty == true ? order.customerAddress! : 'Ghatampur Market, UP 209206';
    final items = order.items ?? [];

    final buffer = StringBuffer();
    buffer.writeln('🚨 *NEW FASTKIRANA ORDER #$orderId* 🚨\n');
    buffer.writeln('👤 *Customer:* $custName');
    buffer.writeln('📞 *Phone:* +91 $custPhone');
    buffer.writeln('📍 *Address:* $custAddr\n');
    
    buffer.writeln('🛒 *ORDERED ITEMS (${items.length}):*');
    for (final item in items) {
      buffer.writeln('• ${item.name} (${item.quantity}x) - ₹${(item.price * item.quantity).toInt()}');
    }
    buffer.writeln('');
    buffer.writeln('💰 *Item Total:* ₹${order.subtotal.toInt()}');
    if (order.discount > 0) buffer.writeln('🎟️ *Discount:* -₹${order.discount.toInt()}');
    buffer.writeln('📦 *Packaging Charge:* ₹${order.miscFee.toInt()}');
    buffer.writeln('🚚 *Delivery Fee:* ${order.deliveryFee == 0 ? "FREE" : "₹${order.deliveryFee.toInt()}"}');
    buffer.writeln('💳 *Total Amount:* ₹${order.total.toInt()} (${order.paymentMethod.displayName})');
    buffer.writeln('⚡ *Status:* Placed & Ready for Packing\n');
    if (order.notes?.isNotEmpty == true) {
      buffer.writeln('🔔 *Customer Note:* ${order.notes}\n');
    }
    buffer.writeln('🔗 *Manage in Admin Dashboard:*');
    buffer.writeln('https://fastkirana.in/admin');

    return buffer.toString();
  }

  /// Format clean restaurant / kitchen WhatsApp ticket with items, quantities, type, and notes
  static String formatRestaurantKOTMessage(Order order) {
    final orderId = order.readableId ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id);
    final items = order.items ?? [];
    final outlet = order.shopName?.isNotEmpty == true ? order.shopName! : 'FastKirana Kitchen';

    final orderDate = order.createdAt.toLocal();
    final hour = orderDate.hour > 12 ? orderDate.hour - 12 : (orderDate.hour == 0 ? 12 : orderDate.hour);
    final minute = orderDate.minute.toString().padLeft(2, '0');
    final period = orderDate.hour >= 12 ? 'pm' : 'am';
    final timeStr = '$hour:$minute $period';

    final deliveryMethod = (order.deliveryMethod ?? 'DELIVERY').toUpperCase();
    final typeStr = (deliveryMethod == 'PICKUP' || deliveryMethod == 'SELFPICKUP' || deliveryMethod == 'SELF_PICKUP')
        ? '🚶 Self Pickup (Customer Takeaway)'
        : '🛵 Doorstep Delivery (Rider Pickup)';

    final buffer = StringBuffer();
    buffer.writeln('🍽️ *FASTKIRANA KITCHEN ORDER*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 *Order Token:* #$orderId');
    buffer.writeln('⏰ *Order Time:* $timeStr');
    buffer.writeln('📦 *Type:* $typeStr');
    buffer.writeln('🏪 *Outlet:* $outlet');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *ITEMS TO PREPARE:*\n');

    int totalQty = 0;
    if (items.isNotEmpty) {
      for (int idx = 0; idx < items.length; idx++) {
        final item = items[idx];
        totalQty += item.quantity;
        final variant = (item.selectedVariant != null && item.selectedVariant!.isNotEmpty)
            ? ' (${item.selectedVariant})'
            : '';
        buffer.writeln('${idx + 1}. ${item.name}$variant  ➜  *Qty: ${item.quantity}*');
      }
    } else {
      buffer.writeln('1. Food Items  ➜  *Qty: 1*');
      totalQty = 1;
    }

    buffer.writeln('\n🔢 *Total Items to Pack:* $totalQty items');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    if (order.notes?.trim().isNotEmpty == true) {
      buffer.writeln('📝 *Customer Note:* ${order.notes!.trim()}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('👨‍🍳 *Chef Note:* Kripya fresh prepare karein aur safely pack karein');

    return buffer.toString();
  }

  /// Fire WhatsApp message directly to Admin WhatsApp number
  static Future<bool> fireAdminWhatsAppAlert(Order order, {String? targetPhone}) async {
    final phone = (targetPhone != null && targetPhone.trim().isNotEmpty)
        ? targetPhone.trim()
        : '7054470303';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = formatOrderWhatsAppMessage(order);
    final encodedMsg = Uri.encodeComponent(msg);
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$encodedMsg');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      debugPrint('WhatsApp dispatch error: $e');
    }
    return false;
  }

  /// 1-Tap Out-of-Stock Item Substitution WhatsApp Message to Customer
  static Future<bool> sendSubstitutionWhatsApp({
    required String customerPhone,
    required String customerName,
    required String orderId,
    required String unavailableItem,
    required String suggestedReplacement,
  }) async {
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    if (cleanPhone.length < 10) return false;

    final buffer = StringBuffer();
    buffer.writeln('🙏 *Namaste $customerName ji! (FastKirana Express)*\n');
    buffer.writeln('Aapke Order *#$orderId* me:');
    buffer.writeln('❌ *$unavailableItem* abhi out of stock ho gaya hai.');
    buffer.writeln('');
    buffer.writeln('✅ Kya hum iski jagah:');
    buffer.writeln('👉 *$suggestedReplacement* pack kar dein?');
    buffer.writeln('');
    buffer.writeln('Kripya *YES* ya apna alternate item yahan reply karke confirm karein taaki hum turant order dispatch kar sakein! ⚡');

    final encodedMsg = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      debugPrint('WhatsApp substitution launcher error: $e');
    }
    return false;
  }
}
