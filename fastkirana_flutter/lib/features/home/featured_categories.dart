import 'dart:convert';
import '../../data/models/category.dart';

const featuredCategoriesKey = 'featured_categories';
const featuredBadges = ['', 'Featured', 'Seasonal', 'Everyday'];
const featuredTints = [
  'auto',
  'mint',
  'cream',
  'peach',
  'sky',
  'rose',
  'lilac'
];

bool isFeaturedCategory(Category category) {
  final slug = category.slug.toLowerCase(), name = category.name.toLowerCase();
  return category.parentId == null &&
      category.productCount != 0 &&
      !RegExp(r'restaurant|cafe|fastfood|fast-food-kitchen').hasMatch(slug) &&
      !RegExp(r'restaurant|cafe|^fast food').hasMatch(name);
}

class FeaturedCategoryItem {
  final String categoryId, label, imageFit, badge, tint;
  final String? image;
  final bool enabled;
  const FeaturedCategoryItem(
      {required this.categoryId,
      this.label = '',
      this.image,
      this.imageFit = 'cover',
      this.badge = '',
      this.tint = 'auto',
      this.enabled = true});
}

class FeaturedCategorySelection {
  final Category category;
  final FeaturedCategoryItem item;
  const FeaturedCategorySelection(this.category, this.item);
  String get label => item.label.isEmpty ? category.name : item.label;
}

class FeaturedCategoriesConfig {
  final bool enabled;
  final String title;
  final List<FeaturedCategoryItem> items;
  const FeaturedCategoriesConfig(
      {this.enabled = true,
      this.title = 'Featured categories',
      required this.items});

  static FeaturedCategoriesConfig defaults(List<Category> categories) {
    final eligible = categories.where(isFeaturedCategory).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        final name = a.name.compareTo(b.name);
        return name == 0 ? a.id.compareTo(b.id) : name;
      });
    return FeaturedCategoriesConfig(
        items: eligible
            .take(6)
            .map((category) => FeaturedCategoryItem(categoryId: category.id))
            .toList());
  }

  List<FeaturedCategorySelection> select(List<Category> categories) {
    if (!enabled) return [];
    final byId = {
      for (final category in categories.where(isFeaturedCategory))
        category.id: category
    };
    return [
      for (final item in items)
        if (item.enabled && byId.containsKey(item.categoryId))
          FeaturedCategorySelection(byId[item.categoryId]!, item)
    ];
  }

  static FeaturedCategoriesConfig? parse(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is! Map ||
          value.keys.any((key) =>
              !['version', 'enabled', 'title', 'items'].contains(key)) ||
          value['version'] != 1) {
        return null;
      }
      final enabled = value['enabled'] ?? true,
          title = value['title'] ?? 'Featured categories',
          sources = value['items'];
      if (enabled is! bool ||
          title is! String ||
          title.trim().isEmpty ||
          title.trim().length > 80 ||
          sources is! List ||
          sources.length > 6) {
        return null;
      }
      final items = <FeaturedCategoryItem>[], ids = <String>{};
      for (final source in sources) {
        if (source is! Map ||
            source.keys.any((key) => ![
                  'categoryId',
                  'label',
                  'image',
                  'imageFit',
                  'badge',
                  'tint',
                  'enabled'
                ].contains(key))) {
          return null;
        }
        final id = source['categoryId'],
            label = source['label'] ?? '',
            image = source['image'];
        final fit = source['imageFit'] ?? 'cover',
            badge = source['badge'] ?? '',
            tint = source['tint'] ?? 'auto',
            visible = source['enabled'] ?? true;
        if (id is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
            !ids.add(id) ||
            label is! String ||
            label.trim().length > 60 ||
            !['cover', 'contain'].contains(fit) ||
            !featuredBadges.contains(badge) ||
            !featuredTints.contains(tint) ||
            visible is! bool ||
            (image != null && (image is! String || !_safeImage(image)))) {
          return null;
        }
        items.add(FeaturedCategoryItem(
            categoryId: id,
            label: label.trim(),
            image: image as String?,
            imageFit: fit as String,
            badge: badge as String,
            tint: tint as String,
            enabled: visible));
      }
      return FeaturedCategoriesConfig(
          enabled: enabled, title: title.trim(), items: items);
    } catch (_) {
      return null;
    }
  }
}

bool _safeImage(String value) {
  if (value.length > 2048 || RegExp(r'[\x00-\x1f\\]').hasMatch(value)) {
    return false;
  }
  try {
    final decoded = Uri.decodeComponent(value);
    if (decoded.contains('\\') ||
        decoded.split('/').any((part) => part == '..' || part == '.')) {
      return false;
    }
    if (value.startsWith('/') && !value.startsWith('//')) {
      return !value.contains('..') &&
          RegExp(r'^/[\w/%.@-]+\.(svg|png|jpe?g|webp|avif)$',
                  caseSensitive: false)
              .hasMatch(value);
    }
    final uri = Uri.parse(value);
    return uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
  } catch (_) {
    return false;
  }
}
