enum DiscountType { flat, percent, bogo, freeDelivery }

class Coupon {
  final String id;
  final String code;
  final DiscountType discountType;
  final double value;
  final double minOrder;
  final double maxDiscount;
  final String? categoryId;
  final String? restaurantId;
  final String? bogoType;
  final String? triggerVariant;
  final String? rewardVariant;
  final String? badgeText;
  final bool autoApply;
  final bool isActive;
  final DateTime expiresAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    this.value = 0.0,
    this.minOrder = 0.0,
    this.maxDiscount = 0.0,
    this.categoryId,
    this.restaurantId,
    this.bogoType,
    this.triggerVariant,
    this.rewardVariant,
    this.badgeText,
    this.autoApply = false,
    this.isActive = true,
    required this.expiresAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    DiscountType parseDiscountType(dynamic val) {
      if (val == null) return DiscountType.flat;
      final str = val.toString().toLowerCase();
      if (str.contains('bogo')) return DiscountType.bogo;
      if (str.contains('free') && str.contains('delivery')) return DiscountType.freeDelivery;
      if (str.contains('percent') || str.contains('%')) return DiscountType.percent;
      return DiscountType.flat;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now().add(const Duration(days: 365));
      final parsed = DateTime.tryParse(val.toString());
      return parsed ?? DateTime.now().add(const Duration(days: 365));
    }

    return Coupon(
      id: json['id']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').toUpperCase(),
      discountType: parseDiscountType(json['discountType']),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      minOrder: (json['minOrder'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (json['maxDiscount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId']?.toString(),
      restaurantId: json['restaurantId']?.toString(),
      bogoType: json['bogoType']?.toString(),
      triggerVariant: json['triggerVariant']?.toString(),
      rewardVariant: json['rewardVariant']?.toString(),
      badgeText: json['badgeText']?.toString(),
      autoApply: json['autoApply'] == true || json['autoApply'] == 1 || json['autoApply'] == 'true',
      isActive: json['isActive'] == true || json['isActive'] == 1 || json['isActive'] == 'true',
      expiresAt: parseDate(json['expiresAt']),
    );
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && expiresAt.isAfter(now);
  }

  bool get isBogo => discountType == DiscountType.bogo;
}