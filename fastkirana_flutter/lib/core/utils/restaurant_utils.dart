import '../../data/models/product.dart';

const String outletWedsonId = 'cms2p1lyx0001n0idod904lfu';
const String outletAsRestaurantId = 'cms2p1lap0000n0id8alldboy';
const String outletBalUdyanId = 'cmsbhxb6a000304if8kf1cwji';

const Map<String, String> outletNamesMap = {
  outletWedsonId: 'Wedson Restaurant',
  outletAsRestaurantId: 'A.S. Restaurant',
  outletBalUdyanId: 'Bal Udyan Restaurant',
  'wedson': 'Wedson Restaurant',
  'wedson-restaurant': 'Wedson Restaurant',
  'as-restaurant': 'A.S. Restaurant',
  'as-cafe': 'A.S. Restaurant',
  'bal-udyan-restaurant': 'Bal Udyan Restaurant',
  'bal-udyan': 'Bal Udyan Restaurant',
  'baludyan': 'Bal Udyan Restaurant',
  'cafe': 'Restaurant',
  'restaurant-kitchen': 'Wedson Restaurant',
};

/// Check if a product is a food / restaurant dish (as opposed to grocery)
bool isRestaurantProduct(Product product) {
  // 1. Explicit restaurant assignment
  if ((product.restaurantId != null && product.restaurantId!.trim().isNotEmpty) ||
      product.restaurant != null) {
    return true;
  }

  // 2. Explicit restaurant category
  final categorySlug = (product.category?.slug ?? product.categoryId).toLowerCase();
  if (categorySlug == 'restaurant' ||
      categorySlug == 'restaurant-food' ||
      categorySlug == 'fast-food-kitchen' ||
      categorySlug == 'cafe' ||
      categorySlug.contains('restaurant') ||
      categorySlug.contains('cafe')) {
    return true;
  }

  // 3. Explicit restaurant tags ONLY (avoid generic food/snack terms)
  final tags = product.tags.map((t) => t.toLowerCase()).toList();
  if (tags.any((t) => [
        'restaurant',
        'wedson',
        'wedson-restaurant',
        'as-restaurant',
        'as-cafe',
        'a.s. restaurant',
        'bal-udyan',
        'bal-udyan-restaurant',
        'baludyan',
        'cafe',
        'cooked',
        'dish',
      ].contains(t))) {
    return true;
  }

  return false;
}

/// Backward compatible alias
bool isCafeProduct(Product product) => isRestaurantProduct(product);

/// Returns the normalized outlet name for a product (e.g. "Bal Udyan Restaurant", "A.S. Restaurant", "Wedson Restaurant")
String getOutletName(Product product) {
  // Direct name if provided in restaurant object
  final rName = product.restaurant?.name;
  if (rName != null && rName.trim().isNotEmpty) {
    return rName.trim();
  }

  final rId = (product.restaurantId ?? product.restaurant?.id ?? '').toLowerCase().trim();
  final rSlug = (product.restaurant?.slug ?? '').toLowerCase().trim();
  final tags = product.tags.map((t) => t.toLowerCase()).toList();
  final pName = product.name.toLowerCase();

  // 1. Explicit Bal Udyan Restaurant checks
  if (rId == outletBalUdyanId ||
      rId == 'bal-udyan-restaurant' ||
      rId == 'bal-udyan' ||
      rId == 'baludyan' ||
      rSlug.contains('bal') ||
      tags.any((t) => t.contains('bal udyan') || t.contains('baludyan') || t == 'bal-udyan-restaurant') ||
      pName.contains('bal udyan')) {
    return 'Bal Udyan Restaurant';
  }

  // 2. Explicit A.S. Restaurant checks
  if (rId == outletAsRestaurantId ||
      rId == 'as-restaurant' ||
      rId == 'as-cafe' ||
      rSlug == 'as-restaurant' ||
      rSlug == 'as-cafe' ||
      tags.any((t) => t == 'as-restaurant' || t == 'as-cafe' || t.contains('a.s.') || t.contains('a.s') || t == 'as_restaurant') ||
      pName.contains('a.s special') ||
      pName.contains('a.s. special')) {
    return 'A.S. Restaurant';
  }

  // 3. Explicit Wedson Restaurant checks
  if (rId == outletWedsonId ||
      rId == 'wedson' ||
      rId == 'wedson-restaurant' ||
      rSlug == 'wedson' ||
      rSlug == 'wedson-restaurant' ||
      rSlug == 'restaurant-kitchen' ||
      tags.any((t) => t == 'wedson' || t == 'wedson-restaurant' || t == 'wedson_restaurant') ||
      pName.contains('wedson')) {
    return 'Wedson Restaurant';
  }

  // 4. Known ID / Tag mappings
  if (outletNamesMap.containsKey(rId)) {
    return outletNamesMap[rId]!;
  }
  for (final tag in tags) {
    if (outletNamesMap.containsKey(tag)) {
      return outletNamesMap[tag]!;
    }
  }

  // 5. Fallback if product has restaurant ID
  if (rId.isNotEmpty) {
    return 'A.S. Restaurant';
  }

  return 'FastKirana Store';
}

/// Extension on Product for clean outlet & restaurant queries
extension ProductRestaurantExtension on Product {
  bool get isRestaurantProduct => isCafeProduct(this);
  String get outletName => getOutletName(this);
}
