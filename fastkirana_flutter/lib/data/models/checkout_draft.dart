import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'address.dart';

class CheckoutDraft {
  final String? hubId;
  final String deliveryMethod; // 'DELIVERY' | 'PICKUP'
  final Address? selectedAddress;
  final int selectedAddressIndex;
  final String? customReceiverName;
  final String? customReceiverPhone;
  final Set<String> selectedDeliveryInstructions; // e.g. {'dont_ring_bell', 'leave_at_door'}
  final String? cookingInstruction;
  final String? customDeliveryNotes;
  final String? couponCode;
  final double discountAmount;
  final double tipAmount;
  final String selectedPackaging; // 'NORMAL' | 'PREMIUM'
  final String selectedPayment; // 'cod' | 'online'
  final bool isFrozenForPayment;
  final String? activePaymentSessionId;
  final List<Map<String, dynamic>> items;
  final double grandTotal;
  final String? cfOrderId;

  const CheckoutDraft({
    this.hubId,
    this.deliveryMethod = 'DELIVERY',
    this.selectedAddress,
    this.selectedAddressIndex = 0,
    this.customReceiverName,
    this.customReceiverPhone,
    this.selectedDeliveryInstructions = const {'ring_bell'},
    this.cookingInstruction,
    this.customDeliveryNotes,
    this.couponCode,
    this.discountAmount = 0.0,
    this.tipAmount = 0.0,
    this.selectedPackaging = 'NORMAL',
    this.selectedPayment = 'cod',
    this.isFrozenForPayment = false,
    this.activePaymentSessionId,
    this.items = const [],
    this.grandTotal = 0.0,
    this.cfOrderId,
  });

  CheckoutDraft copyWith({
    String? hubId,
    String? deliveryMethod,
    Address? selectedAddress,
    bool clearAddress = false,
    int? selectedAddressIndex,
    String? customReceiverName,
    String? customReceiverPhone,
    bool clearReceiver = false,
    Set<String>? selectedDeliveryInstructions,
    String? cookingInstruction,
    String? customDeliveryNotes,
    String? couponCode,
    bool clearCoupon = false,
    double? discountAmount,
    double? tipAmount,
    String? selectedPackaging,
    String? selectedPayment,
    bool? isFrozenForPayment,
    String? activePaymentSessionId,
    bool clearPaymentSession = false,
    List<Map<String, dynamic>>? items,
    double? grandTotal,
    String? cfOrderId,
    bool clearCfOrderId = false,
  }) {
    return CheckoutDraft(
      hubId: hubId ?? this.hubId,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      selectedAddress: clearAddress ? null : (selectedAddress ?? this.selectedAddress),
      selectedAddressIndex: selectedAddressIndex ?? this.selectedAddressIndex,
      customReceiverName: clearReceiver ? null : (customReceiverName ?? this.customReceiverName),
      customReceiverPhone: clearReceiver ? null : (customReceiverPhone ?? this.customReceiverPhone),
      selectedDeliveryInstructions: selectedDeliveryInstructions ?? this.selectedDeliveryInstructions,
      cookingInstruction: cookingInstruction ?? this.cookingInstruction,
      customDeliveryNotes: customDeliveryNotes ?? this.customDeliveryNotes,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      discountAmount: clearCoupon ? 0.0 : (discountAmount ?? this.discountAmount),
      tipAmount: tipAmount ?? this.tipAmount,
      selectedPackaging: selectedPackaging ?? this.selectedPackaging,
      selectedPayment: selectedPayment ?? this.selectedPayment,
      isFrozenForPayment: isFrozenForPayment ?? this.isFrozenForPayment,
      activePaymentSessionId: clearPaymentSession ? null : (activePaymentSessionId ?? this.activePaymentSessionId),
      items: items ?? this.items,
      grandTotal: grandTotal ?? this.grandTotal,
      cfOrderId: clearCfOrderId ? null : (cfOrderId ?? this.cfOrderId),
    );
  }

  Map<String, dynamic> toJson() => {
    'hubId': hubId,
    'deliveryMethod': deliveryMethod,
    'selectedAddress': selectedAddress?.toJson(),
    'selectedAddressIndex': selectedAddressIndex,
    'customReceiverName': customReceiverName,
    'customReceiverPhone': customReceiverPhone,
    'selectedDeliveryInstructions': selectedDeliveryInstructions.toList(),
    'cookingInstruction': cookingInstruction,
    'customDeliveryNotes': customDeliveryNotes,
    'couponCode': couponCode,
    'discountAmount': discountAmount,
    'tipAmount': tipAmount,
    'selectedPackaging': selectedPackaging,
    'selectedPayment': selectedPayment,
    'isFrozenForPayment': isFrozenForPayment,
    'activePaymentSessionId': activePaymentSessionId,
    'items': items,
    'grandTotal': grandTotal,
    'cfOrderId': cfOrderId,
  };

  factory CheckoutDraft.fromJson(Map<String, dynamic> json) {
    return CheckoutDraft(
      hubId: json['hubId'] as String?,
      deliveryMethod: json['deliveryMethod'] as String? ?? 'DELIVERY',
      selectedAddress: json['selectedAddress'] != null
          ? Address.fromJson(json['selectedAddress'] as Map<String, dynamic>)
          : null,
      selectedAddressIndex: json['selectedAddressIndex'] as int? ?? 0,
      customReceiverName: json['customReceiverName'] as String?,
      customReceiverPhone: json['customReceiverPhone'] as String?,
      selectedDeliveryInstructions: (json['selectedDeliveryInstructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {'ring_bell'},
      cookingInstruction: json['cookingInstruction'] as String?,
      customDeliveryNotes: json['customDeliveryNotes'] as String?,
      couponCode: json['couponCode'] as String?,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (json['tipAmount'] as num?)?.toDouble() ?? 0.0,
      selectedPackaging: json['selectedPackaging'] as String? ?? 'NORMAL',
      selectedPayment: json['selectedPayment'] as String? ?? 'cod',
      isFrozenForPayment: json['isFrozenForPayment'] as bool? ?? false,
      activePaymentSessionId: json['activePaymentSessionId'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      cfOrderId: json['cfOrderId'] as String?,
    );
  }

  // ─── Scope-partitioned accepted draft persistence ───

  static Future<String> _getDraftKey() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? prefs.getString('user_id') ?? 'guest';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final owner = cleanPhone.isNotEmpty ? cleanPhone : 'guest';
    final hubId = prefs.getString('selected_hub_id') ?? 'default';
    return 'accepted_checkout_draft_${owner}_$hubId';
  }

  static Future<void> saveAcceptedDraft(CheckoutDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getDraftKey();
    await prefs.setString(key, jsonEncode(draft.toJson()));
  }

  static Future<CheckoutDraft?> loadAcceptedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getDraftKey();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CheckoutDraft.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearAcceptedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getDraftKey();
    await prefs.remove(key);
  }
}
