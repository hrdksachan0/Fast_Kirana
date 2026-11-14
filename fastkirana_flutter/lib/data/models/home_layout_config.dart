class HomeSectionModel {
  final String id;
  final String label;
  final String description;
  final bool enabled;
  final int sortOrder;

  const HomeSectionModel({
    required this.id,
    required this.label,
    this.description = '',
    this.enabled = true,
    this.sortOrder = 0,
  });

  factory HomeSectionModel.fromJson(Map<String, dynamic> json) {
    return HomeSectionModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'enabled': enabled,
        'sortOrder': sortOrder,
      };
}

class HomeLayoutConfigModel {
  final List<HomeSectionModel> sections;

  const HomeLayoutConfigModel({
    this.sections = defaultSections,
  });

  factory HomeLayoutConfigModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final list = rawSections is List
        ? rawSections
            .whereType<Map<String, dynamic>>()
            .map((e) => HomeSectionModel.fromJson(e))
            .toList()
        : <HomeSectionModel>[];

    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return HomeLayoutConfigModel(
      sections: list.isNotEmpty ? list : defaultSections,
    );
  }

  static const List<HomeSectionModel> defaultSections = [
    HomeSectionModel(
      id: 'diwali_campaign',
      label: '🪔 Diwali / Festive Campaign Section',
      description: 'Diwali Mahotsav specials, clay diyas & sweets',
      enabled: true,
      sortOrder: 1,
    ),
    HomeSectionModel(
      id: 'hero_banners',
      label: '🖼️ Hero Promo Banners Carousel',
      description: 'Rotating discount billboards & promo banners',
      enabled: true,
      sortOrder: 2,
    ),
    HomeSectionModel(
      id: 'top_categories',
      label: '📦 Top Category Icons Grid',
      description: 'Dairy, fresh veggies, snacks & pantry essentials',
      enabled: true,
      sortOrder: 3,
    ),
    HomeSectionModel(
      id: 'bento_gifting',
      label: '🎁 Bento: Gifting Boutique & Hampers',
      description: 'Curated gift hampers, celebratory boxes & luxury gifting card',
      enabled: true,
      sortOrder: 4,
    ),
    HomeSectionModel(
      id: 'bento_fresh_market',
      label: '🥬 Bento: Fresh Market (Bloom)',
      description: 'Farm-fresh hydroponics, daily vegetables & fruits',
      enabled: true,
      sortOrder: 5,
    ),
    HomeSectionModel(
      id: 'bento_seasonal',
      label: '🧴 Bento: Seasonal Switch-Up',
      description: 'Winter skin care, cold creams, body lotions & wellness',
      enabled: true,
      sortOrder: 6,
    ),
    HomeSectionModel(
      id: 'bento_daily_restock',
      label: '🛒 Bento: Daily Restock',
      description: 'Morning essentials, bread, milk & kitchen pantry restock',
      enabled: true,
      sortOrder: 7,
    ),
    HomeSectionModel(
      id: 'bento_value_picks',
      label: '🏷️ Bento: Value Picks',
      description: 'Budget-friendly combos, mega savings & clearance steals',
      enabled: true,
      sortOrder: 8,
    ),
    HomeSectionModel(
      id: 'product_sections',
      label: '🥛 Product Feed (Dairy, Snacks & Daily Staples)',
      description: 'Horizontal carousels & vertical infinite feed',
      enabled: true,
      sortOrder: 9,
    ),
  ];
}
