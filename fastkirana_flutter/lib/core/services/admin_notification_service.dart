import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order.dart';

class AdminNotificationService {
  /// Format a comprehensive, clean receipt message for Admin & Kitchen/Darkstore
  static String formatOrderWhatsAppMessage(Order order) {
    final orderId = order.readableId ?? (order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id);
    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'FastKirana Customer';
    final custPhone = order.customerPhone?.isNotEmpty == true ? order.customerPhone! : '7054470303';
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
}
