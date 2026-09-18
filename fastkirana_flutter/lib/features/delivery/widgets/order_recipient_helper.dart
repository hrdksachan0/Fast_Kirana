import 'package:flutter/foundation.dart';

/// Helper to parse and extract recipient information for orders,
/// especially when "Order for someone else" is placed with recipient details in notes.
@immutable
class OrderRecipientDetails {
  final bool isOrderForSomeone;
  final String recipientName;
  final String? recipientPhone;
  final String? buyerName;
  final String? buyerPhone;
  final String? deliveryInstructions;
  final String fullRecipientLabel;

  const OrderRecipientDetails({
    required this.isOrderForSomeone,
    required this.recipientName,
    this.recipientPhone,
    this.buyerName,
    this.buyerPhone,
    this.deliveryInstructions,
    required this.fullRecipientLabel,
  });

  factory OrderRecipientDetails.fromOrder(Map<String, dynamic>? order) {
    if (order == null) {
      return const OrderRecipientDetails(
        isOrderForSomeone: false,
        recipientName: 'Customer',
        recipientPhone: null,
        buyerName: null,
        buyerPhone: null,
        deliveryInstructions: null,
        fullRecipientLabel: 'Customer',
      );
    }

    final dynamic rawCustomer = order['user'];
    final Map<String, dynamic>? customer = rawCustomer is Map<String, dynamic>
        ? rawCustomer
        : (rawCustomer is Map ? Map<String, dynamic>.from(rawCustomer) : null);

    final dynamic rawAddress = order['address'];
    final Map<String, dynamic>? address = rawAddress is Map<String, dynamic>
        ? rawAddress
        : (rawAddress is Map ? Map<String, dynamic>.from(rawAddress) : null);

    final String? buyerName = (customer?['name']?.toString().trim().isNotEmpty == true)
        ? customer!['name'].toString().trim()
        : (order['userName']?.toString().trim().isNotEmpty == true
            ? order['userName'].toString().trim()
            : null);

    final String? buyerPhone = (customer?['phone']?.toString().trim().isNotEmpty == true)
        ? customer!['phone'].toString().trim()
        : null;

    final String defaultPhone = (address?['phone']?.toString().trim().isNotEmpty == true)
        ? address!['phone'].toString().trim()
        : (buyerPhone ?? (order['shopPhone']?.toString().trim() ?? ''));

    final String notes = (order['notes'] ?? '').toString().trim();

    // 1. Direct fields if provided
    final String? directReceiverName = order['receiverName']?.toString().trim();
    final String? directReceiverPhone = order['receiverPhone']?.toString().trim();

    if (directReceiverName != null && directReceiverName.isNotEmpty) {
      final phone = (directReceiverPhone != null && directReceiverPhone.isNotEmpty)
          ? directReceiverPhone
          : (defaultPhone.isNotEmpty ? defaultPhone : null);
      return OrderRecipientDetails(
        isOrderForSomeone: true,
        recipientName: directReceiverName,
        recipientPhone: phone,
        buyerName: buyerName,
        buyerPhone: buyerPhone,
        deliveryInstructions: notes.isNotEmpty ? notes : null,
        fullRecipientLabel: phone != null ? ' ()' : directReceiverName,
      );
    }

    // 2. Parse from notes: e.g. "🎁 Order for: Rahul (9876543210) | Ring the bell"
    if (notes.isNotEmpty && notes.contains('Order for:')) {
      final parts = notes.split('|');
      final firstPart = parts[0].trim();

      // Clean off emoji and "Order for:"
      String recipientPart = firstPart.replaceAll('🎁', '').trim();
      final orderForIdx = recipientPart.toLowerCase().indexOf('order for:');
      if (orderForIdx != -1) {
        recipientPart = recipientPart.substring(orderForIdx + 'order for:'.length).trim();
      }

      String parsedName = recipientPart;
      String? parsedPhone;

      // Extract Name and Phone from "Name (Phone)"
      final match = RegExp(r'^(.*?)(?:\s*\(([\d\+\s\-]{7,15})\))?$').firstMatch(recipientPart);
      if (match != null) {
        final g1 = match.group(1)?.trim();
        final g2 = match.group(2)?.trim();
        if (g1 != null && g1.isNotEmpty) {
          parsedName = g1;
        }
        if (g2 != null && g2.isNotEmpty) {
          parsedPhone = g2;
        }
      }

      final instructions = parts.length > 1 ? parts.sublist(1).join(' | ').trim() : null;

      if (parsedName.isNotEmpty) {
        final effectivePhone = parsedPhone ?? (defaultPhone.isNotEmpty ? defaultPhone : null);
        return OrderRecipientDetails(
          isOrderForSomeone: true,
          recipientName: parsedName,
          recipientPhone: effectivePhone,
          buyerName: buyerName,
          buyerPhone: buyerPhone,
          deliveryInstructions: (instructions != null && instructions.isNotEmpty) ? instructions : null,
          fullRecipientLabel: recipientPart,
        );
      }
    }

    // Standard order (not for someone else)
    final fallbackName = (address?['name']?.toString().trim().isNotEmpty == true)
        ? address!['name'].toString().trim()
        : (buyerName ?? 'Customer');

    return OrderRecipientDetails(
      isOrderForSomeone: false,
      recipientName: fallbackName,
      recipientPhone: defaultPhone.isNotEmpty ? defaultPhone : null,
      buyerName: null,
      buyerPhone: buyerPhone,
      deliveryInstructions: notes.isNotEmpty ? notes : null,
      fullRecipientLabel: fallbackName,
    );
  }
}
