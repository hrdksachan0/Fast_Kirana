import 'package:flutter/material.dart';
import '../../data/models/product.dart';

enum CampaignCardType {
  freshMarket,
  dailyRestock,
  valuePicks,
  giftingBoutique,
  movieNight,
  breakfastClub,
  seasonalSwitchUp,
  custom,
}

class CampaignBentoTabConfig {
  final String id;
  final String label;
  final String? icon;

  const CampaignBentoTabConfig({
    required this.id,
    required this.label,
    this.icon,
  });

  factory CampaignBentoTabConfig.fromJson(Map<String, dynamic> json) {
    return CampaignBentoTabConfig(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (icon != null) 'icon': icon,
      };

  CampaignBentoTabConfig copyWith({
    String? id,
    String? label,
    String? icon,
  }) {
    return CampaignBentoTabConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
    );
  }
}

class CampaignBentoItemConfig {
  final String id;
  final String? productId;
  final Product? realProduct;
  final String name;
  final String weight;
  final double price;
  final double? originalPrice;
  final String? discountTag;
  final String image;
  final String? tabId;
  final String? unitPriceComparison;
  final bool checkedByDefault;

  const CampaignBentoItemConfig({
    required this.id,
    this.productId,
    this.realProduct,
    required this.name,
    required this.weight,
    required this.price,
    this.originalPrice,
    this.discountTag,
    required this.image,
    this.tabId,
    this.unitPriceComparison,
    this.checkedByDefault = true,
  });

  /// Returns the linked real product photo when available, falling back to configured artwork.
  String get effectiveImage {
    final realImg = realProduct?.imageUrl?.trim() ?? '';
    return realImg.isNotEmpty ? realImg : image;
  }

  /// True when a linked real product is unavailable or out of stock at the active hub.
  bool get isOutOfStock {
    if (realProduct == null) return false;
    return !realProduct!.isAvailable || realProduct!.stock <= 0;
  }

  int get availableStock => realProduct?.stock ?? 99;

  factory CampaignBentoItemConfig.fromJson(Map<String, dynamic> json) {
    return CampaignBentoItemConfig(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String?,
      name: json['name'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      discountTag: json['discountTag'] as String?,
      image: json['image'] as String? ?? '',
      tabId: json['tabId'] as String?,
      unitPriceComparison: json['unitPriceComparison'] as String?,
      checkedByDefault: json['checkedByDefault'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (productId != null) 'productId': productId,
        'name': name,
        'weight': weight,
        'price': price,
        if (originalPrice != null) 'originalPrice': originalPrice,
        if (discountTag != null) 'discountTag': discountTag,
        'image': image,
        if (tabId != null) 'tabId': tabId,
        if (unitPriceComparison != null) 'unitPriceComparison': unitPriceComparison,
        'checkedByDefault': checkedByDefault,
      };

  CampaignBentoItemConfig copyWith({
    String? id,
    String? productId,
    Product? realProduct,
    String? name,
    String? weight,
    double? price,
    double? originalPrice,
    String? discountTag,
    String? image,
    String? tabId,
    String? unitPriceComparison,
    bool? checkedByDefault,
  }) {
    return CampaignBentoItemConfig(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      realProduct: realProduct ?? this.realProduct,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountTag: discountTag ?? this.discountTag,
      image: image ?? this.image,
      tabId: tabId ?? this.tabId,
      unitPriceComparison: unitPriceComparison ?? this.unitPriceComparison,
      checkedByDefault: checkedByDefault ?? this.checkedByDefault,
    );
  }
}

class CampaignBentoCardConfig {
  final String id;
  final CampaignCardType type;
  final String badge;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;
  final Color textColor;
  final String? heroImage;
  final List<CampaignBentoTabConfig> tabs;
  final List<CampaignBentoItemConfig> items;
  final String? comboButtonLabel;
  final double? comboButtonPrice;
  final String? specialRibbon;
  final String? destinationRoute;
  final bool enabled;
  final int sortOrder;
  final int minInStockItems;
  final bool scheduleEnabled;
  final String? startDate;
  final String? endDate;
  final String? timeSlot;
  final List<String> targetHubs;

  const CampaignBentoCardConfig({
    required this.id,
    required this.type,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
    required this.textColor,
    this.heroImage,
    this.tabs = const [],
    this.items = const [],
    this.comboButtonLabel,
    this.comboButtonPrice,
    this.specialRibbon,
    this.destinationRoute,
    this.enabled = true,
    this.sortOrder = 0,
    this.minInStockItems = 1,
    this.scheduleEnabled = false,
    this.startDate,
    this.endDate,
    this.timeSlot = 'ALL_DAY',
    this.targetHubs = const ['all'],
  });

  static Color _parseColor(dynamic val, Color fallback) {
    if (val is int) return Color(val);
    if (val is String && val.startsWith('#')) {
      final hex = val.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return fallback;
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  factory CampaignBentoCardConfig.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'custom';
    final cardType = CampaignCardType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => CampaignCardType.custom,
    );

    return CampaignBentoCardConfig(
      id: json['id'] as String? ?? UniqueKey().toString(),
      type: cardType,
      badge: json['badge'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      backgroundColor: _parseColor(json['backgroundColor'], const Color(0xFFF9FAFB)),
      borderColor: _parseColor(json['borderColor'], const Color(0xFFE5E7EB)),
      accentColor: _parseColor(json['accentColor'], const Color(0xFF10B981)),
      textColor: _parseColor(json['textColor'], const Color(0xFF1F2937)),
      heroImage: json['heroImage'] as String?,
      tabs: (json['tabs'] as List<dynamic>?)
              ?.map((e) => CampaignBentoTabConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CampaignBentoItemConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      comboButtonLabel: json['comboButtonLabel'] as String?,
      comboButtonPrice: (json['comboButtonPrice'] as num?)?.toDouble(),
      specialRibbon: json['specialRibbon'] as String?,
      destinationRoute: json['destinationRoute'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      minInStockItems: (json['minInStockItems'] as num?)?.toInt() ?? 1,
      scheduleEnabled: json['scheduleEnabled'] as bool? ?? false,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      timeSlot: json['timeSlot'] as String? ?? 'ALL_DAY',
      targetHubs: (json['targetHubs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['all'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'badge': badge,
        'title': title,
        'subtitle': subtitle,
        'backgroundColor': _colorToHex(backgroundColor),
        'borderColor': _colorToHex(borderColor),
        'accentColor': _colorToHex(accentColor),
        'textColor': _colorToHex(textColor),
        if (heroImage != null) 'heroImage': heroImage,
        'tabs': tabs.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
        if (comboButtonLabel != null) 'comboButtonLabel': comboButtonLabel,
        if (comboButtonPrice != null) 'comboButtonPrice': comboButtonPrice,
        if (specialRibbon != null) 'specialRibbon': specialRibbon,
        if (destinationRoute != null) 'destinationRoute': destinationRoute,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'minInStockItems': minInStockItems,
        'scheduleEnabled': scheduleEnabled,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (timeSlot != null) 'timeSlot': timeSlot,
        'targetHubs': targetHubs,
      };

  CampaignBentoCardConfig copyWith({
    String? id,
    CampaignCardType? type,
    String? badge,
    String? title,
    String? subtitle,
    Color? backgroundColor,
    Color? borderColor,
    Color? accentColor,
    Color? textColor,
    String? heroImage,
    List<CampaignBentoTabConfig>? tabs,
    List<CampaignBentoItemConfig>? items,
    String? comboButtonLabel,
    double? comboButtonPrice,
    String? specialRibbon,
    String? destinationRoute,
    bool? enabled,
    int? sortOrder,
    int? minInStockItems,
    bool? scheduleEnabled,
    String? startDate,
    String? endDate,
    String? timeSlot,
    List<String>? targetHubs,
  }) {
    return CampaignBentoCardConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      badge: badge ?? this.badge,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      heroImage: heroImage ?? this.heroImage,
      tabs: tabs ?? this.tabs,
      items: items ?? this.items,
      comboButtonLabel: comboButtonLabel ?? this.comboButtonLabel,
      comboButtonPrice: comboButtonPrice ?? this.comboButtonPrice,
      specialRibbon: specialRibbon ?? this.specialRibbon,
      destinationRoute: destinationRoute ?? this.destinationRoute,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      minInStockItems: minInStockItems ?? this.minInStockItems,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeSlot: timeSlot ?? this.timeSlot,
      targetHubs: targetHubs ?? this.targetHubs,
    );
  }

  /// Determines whether this card should currently be displayed for [hubId]
  /// considering admin toggle, hub targeting, minimum stock thresholds, and time windows.
  bool isVisibleForHub(String? hubId) {
    if (!enabled) return false;

    // 1. Hub Scoping check
    if (targetHubs.isNotEmpty && !targetHubs.contains('all')) {
      if (hubId != null && !targetHubs.contains(hubId)) return false;
    }

    // 2. Stock threshold check (only if real items are linked)
    if (minInStockItems > 0 && items.isNotEmpty) {
      final realItems = items.where((it) => it.realProduct != null);
      if (realItems.isNotEmpty) {
        final inStockCount = realItems.where((it) => !it.isOutOfStock).length;
        if (inStockCount < minInStockItems) return false;
      }
    }

    // 3. Automated schedule & dayparting check
    if (scheduleEnabled) {
      final now = DateTime.now();
      if (startDate != null && startDate!.isNotEmpty) {
        try {
          final start = DateTime.parse(startDate!);
          if (now.isBefore(start)) return false;
        } catch (_) {}
      }
      if (endDate != null && endDate!.isNotEmpty) {
        try {
          final end = DateTime.parse(endDate!);
          if (now.isAfter(end)) return false;
        } catch (_) {}
      }
      if (timeSlot != null && timeSlot != 'ALL_DAY') {
        final hour = now.hour + (now.minute / 60.0);
        switch (timeSlot) {
          case 'MORNING': // 06:00 to 11:30 AM
            if (hour < 6.0 || hour >= 11.5) return false;
            break;
          case 'AFTERNOON': // 11:30 AM to 05:00 PM
            if (hour < 11.5 || hour >= 17.0) return false;
            break;
          case 'EVENING': // 05:00 PM to 10:00 PM
            if (hour < 17.0 || hour >= 22.0) return false;
            break;
          case 'NIGHT': // 10:00 PM to 06:00 AM
            if (hour >= 6.0 && hour < 22.0) return false;
            break;
        }
      }
    }

    return true;
  }
}

class CampaignBentoConfig {
  final bool enabled;
  final String sectionTitle;
  final String sectionSubtitle;
  final List<CampaignBentoCardConfig> cards;

  const CampaignBentoConfig({
    this.enabled = true,
    this.sectionTitle = 'Featured Zones',
    this.sectionSubtitle = 'Curated daily baskets & instant savings',
    this.cards = const [],
  });

  factory CampaignBentoConfig.fromJson(Map<String, dynamic> json) {
    return CampaignBentoConfig(
      enabled: json['enabled'] as bool? ?? true,
      sectionTitle: json['sectionTitle'] as String? ?? 'Featured Zones',
      sectionSubtitle:
          json['sectionSubtitle'] as String? ?? 'Curated daily baskets & instant savings',
      cards: (json['cards'] as List<dynamic>?)
              ?.map((e) => CampaignBentoCardConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sectionTitle': sectionTitle,
        'sectionSubtitle': sectionSubtitle,
        'cards': cards.map((e) => e.toJson()).toList(),
      };

  CampaignBentoConfig copyWith({
    bool? enabled,
    String? sectionTitle,
    String? sectionSubtitle,
    List<CampaignBentoCardConfig>? cards,
  }) {
    return CampaignBentoConfig(
      enabled: enabled ?? this.enabled,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      sectionSubtitle: sectionSubtitle ?? this.sectionSubtitle,
      cards: cards ?? this.cards,
    );
  }

  /// Default production configurations matching the curated archetypes
  static CampaignBentoConfig defaultProductionConfig() {
    return const CampaignBentoConfig(
      enabled: true,
      sectionTitle: 'Featured Zones',
      sectionSubtitle: 'Curated daily baskets & instant savings',
      cards: [
        // 01. The Seasonal Switch-Up (Zepto Personal Care & Winter Archetype)
        CampaignBentoCardConfig(
          id: 'seasonal-switch-up',
          type: CampaignCardType.seasonalSwitchUp,
          badge: '01',
          title: 'The Seasonal Switch-Up',
          subtitle: 'POWERED BY Cetaphil DOT & KEY',
          backgroundColor: Color(0xFFD6EEFF),
          borderColor: Color(0xFFC0E2FD),
          accentColor: Color(0xFF0284C7),
          textColor: Color(0xFF1E3A8A),
          tabs: [
            CampaignBentoTabConfig(id: 'body-lotion', label: 'Body\nLotions', icon: 'body.png'),
            CampaignBentoTabConfig(id: 'face-moisturizer', label: 'Face\nMoisturizers', icon: 'face.png'),
            CampaignBentoTabConfig(id: 'lip-balm', label: 'Lip\nBalm', icon: 'lip.png'),
            CampaignBentoTabConfig(id: 'hair-care', label: 'Hair\nCare', icon: 'hair.png'),
            CampaignBentoTabConfig(id: 'lip-sleeping-mask', label: 'Lip\nMask', icon: 'lip.png'),
          ],
          items: [],
        ),

        // 02. bloom (Zepto Summer/Farm-Fresh Panoramic Fruits & Veggies Archetype)
        CampaignBentoCardConfig(
          id: 'fresh-market',
          type: CampaignCardType.freshMarket,
          badge: '02',
          title: 'bloom',
          subtitle: 'Farm-fresh essentials',
          backgroundColor: Color(0xFFE2EFFF),
          borderColor: Color(0xFFCFE4FD),
          accentColor: Color(0xFF15803D),
          textColor: Color(0xFF0F172A),
          heroImage: 'bloom-panoramic-header.svg',
          tabs: [],
          items: [
            CampaignBentoItemConfig(
              id: 'bloom-1',
              name: 'Bloom Coriander Leaves',
              weight: '100 g',
              price: 26,
              originalPrice: 48,
              discountTag: '₹22 OFF',
              image: 'fresh-coriander.svg',
            ),
            CampaignBentoItemConfig(
              id: 'bloom-2',
              name: 'Bloom Chilli Green',
              weight: '100 g',
              price: 19,
              originalPrice: 29,
              discountTag: '₹10 OFF',
              image: 'fresh-mint.svg',
            ),
            CampaignBentoItemConfig(
              id: 'bloom-3',
              name: 'Bloom Muskmelon',
              weight: '1 pc (550 - 650 g)',
              price: 111,
              originalPrice: 231,
              discountTag: '₹120 OFF',
              image: 'ref-fresh-cucumber.png',
            ),
          ],
        ),

        // 03. Value Picks
        CampaignBentoCardConfig(
          id: 'value-picks',
          type: CampaignCardType.valuePicks,
          badge: '03',
          title: 'Value Picks',
          subtitle: 'Save more on your daily essentials',
          backgroundColor: Color(0xFFFEFCE8),
          borderColor: Color(0xFFFEF08A),
          accentColor: Color(0xFF15803D),
          textColor: Color(0xFF78350F),
          specialRibbon: 'Better value',
          items: [
            CampaignBentoItemConfig(
              id: 'vp-1',
              name: 'Atta',
              weight: '1 kg',
              price: 60,
              unitPriceComparison: '₹60/kg',
              image: 'ref-atta-1kg.png',
            ),
            CampaignBentoItemConfig(
              id: 'vp-2',
              name: 'Atta',
              weight: '5 kg',
              price: 250,
              unitPriceComparison: '₹50/kg',
              discountTag: 'Better value',
              image: 'ref-atta-5kg.png',
            ),
          ],
        ),

        // 04. Gifting Boutique
        CampaignBentoCardConfig(
          id: 'gifting-boutique',
          type: CampaignCardType.giftingBoutique,
          badge: '04',
          title: 'Gifting Boutique',
          subtitle: 'Thoughtful gifts for special occasions',
          backgroundColor: Color(0xFFFDF2F4),
          borderColor: Color(0xFFFCE7F3),
          accentColor: Color(0xFF15803D),
          textColor: Color(0xFF831843),
          tabs: [
            CampaignBentoTabConfig(id: 'birthday', label: 'Birthday', icon: '🎂'),
            CampaignBentoTabConfig(id: 'anniversary', label: 'Anniversary', icon: '🤍'),
          ],
          items: [
            CampaignBentoItemConfig(
              id: 'gb-1',
              name: 'Rose bouquet',
              weight: '8 stems',
              price: 399,
              image: 'ref-rose-bouquet.png',
              tabId: 'anniversary',
            ),
            CampaignBentoItemConfig(
              id: 'gb-2',
              name: 'Chocolate cake',
              weight: '500 g',
              price: 499,
              image: 'ref-chocolate-cake.png',
              tabId: 'birthday',
            ),
          ],
        ),
      ],
    );
  }
}
