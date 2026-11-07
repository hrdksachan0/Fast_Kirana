import 'package:flutter/material.dart';

class BakeryTabModel {
  final String id;
  final String label;
  final String title;
  final String subtitle;
  final String emoji;
  final String iconUrl;
  final List<String> filterTags;
  final String categorySlug;
  final bool isActive;
  final int sortOrder;

  const BakeryTabModel({
    required this.id,
    required this.label,
    required this.title,
    this.subtitle = '',
    this.emoji = '🥐',
    this.iconUrl = '',
    this.filterTags = const [],
    this.categorySlug = 'bakery',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory BakeryTabModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['filterTags'] ?? json['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((e) => e.toString().toLowerCase().trim()).toList()
        : <String>[];

    return BakeryTabModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🥐',
      iconUrl: json['iconUrl']?.toString() ?? '',
      filterTags: tagsList,
      categorySlug: json['categorySlug']?.toString() ?? 'bakery',
      isActive: json['isActive'] ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'title': title,
        'subtitle': subtitle,
        'emoji': emoji,
        'iconUrl': iconUrl,
        'filterTags': filterTags,
        'categorySlug': categorySlug,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}

class BakeryStoreConfigModel {
  final bool enabled;
  final String bannerBadge;
  final String bannerTitle;
  final String bannerSubtitle;
  final String bannerImageUrl;
  final String backgroundColorHex;
  final List<BakeryTabModel> tabs;

  const BakeryStoreConfigModel({
    this.enabled = true,
    this.bannerBadge = '⚡ FRESH BATCH 5:00 AM',
    this.bannerTitle = 'Baked fresh every morning',
    this.bannerSubtitle = 'Warm crusts, soft pav & tea-time rusks',
    this.bannerImageUrl = 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80',
    this.backgroundColorHex = '#FAF8F3',
    this.tabs = const [],
  });

  Color get backgroundColor => _hexToColor(backgroundColorHex, const Color(0xFFFAF8F3));

  static Color _hexToColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  factory BakeryStoreConfigModel.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'];
    final tabList = rawTabs is List
        ? rawTabs
            .whereType<Map<String, dynamic>>()
            .map((e) => BakeryTabModel.fromJson(e))
            .toList()
        : <BakeryTabModel>[];

    tabList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return BakeryStoreConfigModel(
      enabled: json['enabled'] ?? true,
      bannerBadge: json['bannerBadge']?.toString() ?? '⚡ FRESH BATCH 5:00 AM',
      bannerTitle: json['bannerTitle']?.toString() ?? 'Baked fresh every morning',
      bannerSubtitle: json['bannerSubtitle']?.toString() ?? 'Warm crusts, soft pav & tea-time rusks',
      bannerImageUrl: json['bannerImageUrl']?.toString() ??
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80',
      backgroundColorHex: json['backgroundColor']?.toString() ?? '#FAF8F3',
      tabs: tabList.isNotEmpty ? tabList : defaultTabs,
    );
  }

  static const List<BakeryTabModel> defaultTabs = [
    BakeryTabModel(
      id: 'tab_pav',
      label: 'Pav, Buns\n& Bases',
      title: 'Pav, Buns & Pizza Bases',
      subtitle: 'Fresh batch from dark store • Baked 5:00 AM',
      emoji: '🍔',
      iconUrl: '',
      filterTags: ['pav', 'bun', 'burger bun', 'pizza base', 'kulcha', 'ladi pav'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 1,
    ),
    BakeryTabModel(
      id: 'tab_breads',
      label: 'Daily\nBreads',
      title: 'Daily Fresh Breads',
      subtitle: '100% Whole Wheat, Multigrain & Milk Loaves',
      emoji: '🍞',
      iconUrl: '',
      filterTags: ['bread', 'atta bread', 'brown bread', 'multigrain', 'milk bread', 'white bread'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 2,
    ),
    BakeryTabModel(
      id: 'tab_rusks',
      label: 'Toast &\nRusks',
      title: 'Crispy Rusks & Tea-Time Toasts',
      subtitle: 'Suji, Saunf & Milk Toasts for your morning chai',
      emoji: '🍪',
      iconUrl: '',
      filterTags: ['rusk', 'toast', 'suji rusk', 'tea toast', 'biscuit'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 3,
    ),
    BakeryTabModel(
      id: 'tab_puffs',
      label: 'Puffs &\nPatties',
      title: 'Flaky Puffs & Savory Patties',
      subtitle: 'Baked crispy golden • Hot snack ready',
      emoji: '🥐',
      iconUrl: '',
      filterTags: ['puff', 'patties', 'patis', 'roll', 'croissant', 'savory'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 4,
    ),
    BakeryTabModel(
      id: 'tab_khari',
      label: 'Khari &\nCookies',
      title: 'Butter Khari & Fresh Cookies',
      subtitle: 'Melt-in-mouth bakery biscuits and flaky khari',
      emoji: '🥨',
      iconUrl: '',
      filterTags: ['khari', 'cookie', 'nankhatai', 'jeera biscuit', 'butter biscuit'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 5,
    ),
  ];
}
