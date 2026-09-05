import '../../data/models/product.dart';

const String outletAsRestaurantId = 'REST-101';
const String outletWedsonId = 'REST-102';
const String outletBalUdyanId = 'REST-103';
const String outletPariMilkId = 'REST-104';

// Legacy CUIDs for backward compatibility
const String legacyAsRestaurantId = 'cms2p1lap0000n0id8alldboy';
const String legacyWedsonId = 'cms2p1lyx0001n0idod904lfu';
const String legacyBalUdyanId = 'cmsbhxb6a000304if8kf1cwji';
const String legacyPariMilkId = 'cmtn66nhy000004k0fu84b7ke';

const Map<String, String> outletNamesMap = {
  outletAsRestaurantId: 'A.S. Restaurant',
  outletWedsonId: 'Wedson Restaurant',
  outletBalUdyanId: 'Bal Udyan Restaurant',
  outletPariMilkId: 'Pari Milk Dairy & Sweets',
  legacyAsRestaurantId: 'A.S. Restaurant',
  legacyWedsonId: 'Wedson Restaurant',
  legacyBalUdyanId: 'Bal Udyan Restaurant',
  legacyPariMilkId: 'Pari Milk Dairy & Sweets',
  'wedson': 'Wedson Restaurant',
  'wedson-restaurant': 'Wedson Restaurant',
  'as-restaurant': 'A.S. Restaurant',
  'as-cafe': 'A.S. Restaurant',
  'bal-udyan-restaurant': 'Bal Udyan Restaurant',
  'bal-udyan': 'Bal Udyan Restaurant',
  'baludyan': 'Bal Udyan Restaurant',
  'pari-milk-dairy-sweets': 'Pari Milk Dairy & Sweets',
  'pari-milk': 'Pari Milk Dairy & Sweets',
  'pari': 'Pari Milk Dairy & Sweets',
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
  final categorySlug = (product.category?.slug ?? product.categoryId ?? '').toLowerCase();
  if (categorySlug == 'restaurant' ||
      categorySlug == 'restaurant-food' ||
      categorySlug == 'fast-food-kitchen' ||
      categorySlug == 'cat-112' ||
      categorySlug.contains('cat-112') ||
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

/// Model representing an exact physical outlet/store location in Ghatampur
class OutletLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final bool isRestaurant;

  const OutletLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.isRestaurant,
  });
}

// ─── Exact Physical GPS Coordinates for Ghatampur Outlets ────────────────────
const OutletLocation darkstoreLocation = OutletLocation(
  id: 'darkstore-ghatampur',
  name: 'FastKirana Dark Store',
  lat: 26.1534185,
  lng: 80.1714024,
  address: 'Ghatampur Market, Kanpur Nagar, UP 209206',
  isRestaurant: false,
);

const OutletLocation wedsonLocation = OutletLocation(
  id: outletWedsonId,
  name: 'Wedson Restaurant',
  lat: 26.147862,
  lng: 80.172482,
  address: 'Hamirpur Road, Ghatampur, UP 209206',
  isRestaurant: true,
);

const OutletLocation asRestaurantLocation = OutletLocation(
  id: outletAsRestaurantId,
  name: 'A.S. Restaurant',
  lat: 26.1494833,
  lng: 80.1672394,
  address: 'Nagar Palika, Ghatampur, UP 209206',
  isRestaurant: true,
);

const OutletLocation balUdyanLocation = OutletLocation(
  id: outletBalUdyanId,
  name: 'Bal Udyan Restaurant',
  lat: 26.1468042,
  lng: 80.1773979,
  address: 'Near Tehsil / Railway Fatak, Birshibpur, Ghatampur, UP 209206',
  isRestaurant: true,
);

const OutletLocation pariMilkLocation = OutletLocation(
  id: outletPariMilkId,
  name: 'Pari Milk Dairy & Sweets',
  lat: 26.1520,
  lng: 80.1700,
  address: 'Near CityKart, Ghatampur, UP 209206',
  isRestaurant: true,
);

/// Resolves the exact physical store/restaurant location dynamically
OutletLocation getOutletLocation({
  String? restaurantId,
  String? shopName,
  String? orderType,
  List<dynamic>? items,
  dynamic rawOrder,
}) {
  // 1. If order has sub-orders, check for restaurant suborder
  if (rawOrder is Map && rawOrder['subOrders'] is List) {
    final subOrders = rawOrder['subOrders'] as List;
    dynamic restSub;
    for (final s in subOrders) {
      if (s is Map &&
          (s['type'] == 'RESTAURANT' ||
              s['restaurantId'] != null ||
              (s['readableId']?.toString().toUpperCase().endsWith('-R') ?? false))) {
        restSub = s;
        break;
      }
    }
    if (restSub != null && restSub is Map) {
      final subRestId = restSub['restaurantId']?.toString();
      final subShopName = (restSub['shopName'] ?? restSub['restaurantName'])?.toString();
      final subItems = restSub['items'] as List<dynamic>?;
      return getOutletLocation(restaurantId: subRestId, shopName: subShopName, items: subItems);
    }
  }

  // 2. Extract from rawOrder if passed
  if (rawOrder is Map) {
    restaurantId ??= rawOrder['restaurantId']?.toString();
    shopName ??= (rawOrder['restaurantName'] ?? rawOrder['shopName'])?.toString();
    orderType ??= rawOrder['orderType']?.toString();
    if (items == null && rawOrder['items'] is List) {
      items = rawOrder['items'] as List<dynamic>;
    }
  }

  final rId = (restaurantId ?? '').toLowerCase().trim();
  final sName = (shopName ?? '').toLowerCase().trim();

  // 3. Direct Bal Udyan Restaurant Checks
  if (rId == outletBalUdyanId ||
      rId == 'bal-udyan-restaurant' ||
      rId == 'bal-udyan' ||
      rId == 'baludyan' ||
      sName.contains('bal udyan') ||
      sName.contains('baludyan') ||
      sName.contains('bal udayan') ||
      sName.contains('birshibpur')) {
    return balUdyanLocation;
  }

  // 4. Direct A.S. Restaurant Checks
  if (rId == outletAsRestaurantId ||
      rId == 'as-restaurant' ||
      rId == 'as-cafe' ||
      rId == 'as' ||
      sName.contains('a.s.') ||
      sName.contains('a.s') ||
      sName.contains('as restaurant') ||
      sName.contains('as cafe') ||
      sName.contains('nagar palika')) {
    return asRestaurantLocation;
  }

  // 5. Direct Wedson Restaurant Checks
  if (rId == outletWedsonId ||
      rId == 'wedson' ||
      rId == 'wedson-restaurant' ||
      sName.contains('wedson') ||
      sName.contains('hamirpur road')) {
    return wedsonLocation;
  }

  // 6. Direct Pari Milk Dairy & Sweets Checks
  if (rId == outletPariMilkId ||
      rId == 'pari-milk-dairy-sweets' ||
      rId == 'pari-milk' ||
      rId.contains('pari') ||
      sName.contains('pari') ||
      sName.contains('citykart')) {
    return pariMilkLocation;
  }

  // 6. Inspect Item Names / Product Tags if available
  if (items != null && items.isNotEmpty) {
    for (final it in items) {
      final itemName = (it is Map ? it['name'] : (it.name ?? '')).toString().toLowerCase();
      final itemRestId = (it is Map ? it['restaurantId'] : null)?.toString().toLowerCase().trim();

      if (itemRestId == outletBalUdyanId || itemName.contains('bal udyan')) {
        return balUdyanLocation;
      }
      if (itemRestId == outletWedsonId || itemName.contains('wedson')) {
        return wedsonLocation;
      }
      if (itemRestId == outletAsRestaurantId ||
          itemName.contains('a.s') ||
          itemName.contains('pizza') ||
          itemName.contains('dal fry') ||
          itemName.contains('naan') ||
          itemName.contains('tandoori') ||
          itemName.contains('burger') ||
          itemName.contains('chowmein') ||
          itemName.contains('paneer')) {
        return asRestaurantLocation;
      }
    }
  }

  // 7. Check if order explicitly mentions restaurant
  if (sName.contains('restaurant') ||
      sName.contains('cafe') ||
      sName.contains('kitchen') ||
      (orderType != null && orderType.toUpperCase() == 'RESTAURANT')) {
    return asRestaurantLocation;
  }

  // 8. Default to FastKirana Darkstore for Grocery orders
  return darkstoreLocation;
}

/// Extension on Product for clean outlet & restaurant queries
extension ProductRestaurantExtension on Product {
  bool get isRestaurantProduct => isCafeProduct(this);
  String get outletName => getOutletName(this);
}
