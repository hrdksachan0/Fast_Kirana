import '../../data/models/product.dart';
import '../../data/models/restaurant.dart';
import '../config/app_config.dart';

/// Central dynamic in-memory registry of all restaurants.
/// Populated dynamically from Supabase database / API response.
/// Zero hardcoding: new restaurants added in Supabase automatically work without code changes.
class RestaurantRegistry {
  static final Map<String, Restaurant> _byKey = {};

  /// Register or update a list of restaurants fetched from DB/API
  static void registerAll(List<Restaurant> list) {
    for (final r in list) {
      register(r);
    }
  }

  /// Register an individual restaurant
  static void register(Restaurant r) {
    if (r.id.isNotEmpty) _byKey[r.id.toLowerCase().trim()] = r;
    if (r.slug.isNotEmpty) _byKey[r.slug.toLowerCase().trim()] = r;
    if (r.name.isNotEmpty) _byKey[r.name.toLowerCase().trim()] = r;
  }

  /// Find restaurant dynamically by ID, slug, or name
  static Restaurant? find(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final q = query.toLowerCase().trim();
    if (_byKey.containsKey(q)) return _byKey[q];

    for (final r in _byKey.values) {
      if (r.id.toLowerCase() == q ||
          r.slug.toLowerCase() == q ||
          r.name.toLowerCase() == q ||
          r.name.toLowerCase().contains(q) ||
          q.contains(r.name.toLowerCase())) {
        return r;
      }
    }
    return null;
  }

  /// Find restaurant by owner phone number (matches against database `ownerPhone` column)
  static Restaurant? findByPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return null;
    final last10 = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;

    for (final r in all) {
      final rPhone = (r.ownerPhone ?? r.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (rPhone.isNotEmpty && (rPhone.endsWith(last10) || last10.endsWith(rPhone))) {
        return r;
      }
    }
    return null;
  }

  /// Dynamically get restaurant name by ID or slug
  static String? getName(String? query) => find(query)?.name;

  /// Get list of all unique restaurants currently registered
  static List<Restaurant> get all {
    final unique = <String, Restaurant>{};
    for (final r in _byKey.values) {
      unique[r.id] = r;
    }
    return unique.values.toList();
  }
}

/// Check if a product is a food / restaurant dish dynamically
bool isRestaurantProduct(Product product) {
  // 1. Explicit restaurant assignment from database
  if ((product.restaurantId != null && product.restaurantId!.trim().isNotEmpty) ||
      product.restaurant != null) {
    return true;
  }

  // 2. Explicit restaurant category from database
  final categorySlug = (product.category?.slug ?? product.categoryId ?? '').toLowerCase();
  if (categorySlug.contains('restaurant') ||
      categorySlug.contains('cafe') ||
      categorySlug.contains('kitchen') ||
      categorySlug.contains('cat-112')) {
    return true;
  }

  // 3. Explicit tags
  final tags = product.tags.map((t) => t.toLowerCase()).toList();
  if (tags.any((t) => t == 'restaurant' || t == 'cafe' || t == 'cooked' || t == 'dish')) {
    return true;
  }

  return false;
}

/// Backward compatible alias
bool isCafeProduct(Product product) => isRestaurantProduct(product);

/// Returns the normalized outlet name dynamically without hardcoded branching
String getOutletName(Product product) {
  // 1. Direct name from product's restaurant relation if provided by API
  final rName = product.restaurant?.name;
  if (rName != null && rName.trim().isNotEmpty) {
    return rName.trim();
  }

  // 2. Dynamic lookup from RestaurantRegistry
  final rId = product.restaurantId ?? product.restaurant?.id;
  final registeredName = RestaurantRegistry.getName(rId);
  if (registeredName != null && registeredName.isNotEmpty) {
    return registeredName;
  }

  // 3. Default fallback
  if (rId != null && rId.trim().isNotEmpty) {
    return 'Restaurant';
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

// ─── Default Physical GPS Coordinates for Grocery Dark Store ─────────────────
const OutletLocation darkstoreLocation = OutletLocation(
  id: 'darkstore-ghatampur',
  name: 'FastKirana Dark Store',
  lat: 26.1534185,
  lng: 80.1714024,
  address: 'Ghatampur Market, Kanpur Nagar, UP 209206',
  isRestaurant: false,
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
    for (final s in subOrders) {
      if (s is Map &&
          (s['type'] == 'RESTAURANT' ||
              s['restaurantId'] != null ||
              (s['readableId']?.toString().toUpperCase().endsWith('-R') ?? false))) {
        final subRestId = s['restaurantId']?.toString();
        final subShopName = (s['shopName'] ?? s['restaurantName'])?.toString();
        final subItems = s['items'] as List<dynamic>?;
        return getOutletLocation(restaurantId: subRestId, shopName: subShopName, items: subItems);
      }
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

  // 3. Dynamic lookup from RestaurantRegistry (DB-driven GPS coordinates & address)
  final rest = RestaurantRegistry.find(restaurantId) ??
      RestaurantRegistry.find(shopName);

  if (rest != null) {
    return OutletLocation(
      id: rest.id,
      name: rest.name,
      lat: rest.lat ?? darkstoreLocation.lat,
      lng: rest.lng ?? darkstoreLocation.lng,
      address: rest.address ?? 'Ghatampur, UP',
      isRestaurant: true,
    );
  }

  // 4. Inspect item restaurant IDs if available
  if (items != null && items.isNotEmpty) {
    for (final it in items) {
      final itemRestId = (it is Map ? it['restaurantId'] : null)?.toString();
      final itemRest = RestaurantRegistry.find(itemRestId);
      if (itemRest != null) {
        return OutletLocation(
          id: itemRest.id,
          name: itemRest.name,
          lat: itemRest.lat ?? darkstoreLocation.lat,
          lng: itemRest.lng ?? darkstoreLocation.lng,
          address: itemRest.address ?? 'Ghatampur, UP',
          isRestaurant: true,
        );
      }
    }
  }

  // 5. Default to FastKirana Darkstore for Grocery orders
  return darkstoreLocation;
}

/// Extension on Product for clean outlet & restaurant queries
extension ProductRestaurantExtension on Product {
  bool get isRestaurantProduct => isCafeProduct(this);
  String get outletName => getOutletName(this);
}
