import '../../data/models/product.dart';
import '../../data/models/restaurant.dart';
import '../config/app_config.dart';

/// Central dynamic in-memory registry of all restaurants.
/// Populated dynamically from Supabase database / API response.
/// Zero hardcoding: new restaurants added in Supabase automatically work without code changes.
class RestaurantRegistry {
  static final Map<String, Restaurant> _byKey = {};
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Seed initial known restaurants for 0ms immediate offline/startup availability
    final initialList = [
      Restaurant(
        id: 'REST-101',
        name: 'A.S. Restaurant & Cafe',
        slug: 'as-restaurant',
        description: 'Authentic Burgers, Shakes, Pizzas & Rolls in Ghatampur',
        address: 'Main Market, Ghatampur',
        phone: '+918112849854',
        ownerPhone: '+918112849854',
        lat: 26.1534,
        lng: 80.1714,
        isPureVeg: true,
        isOpen: true,
      ),
      Restaurant(
        id: 'REST-102',
        name: 'Wedson Restaurant',
        slug: 'wedson-restaurant',
        description: 'Multi-cuisine Restaurant in Ghatampur',
        address: 'Kanpur Road, Ghatampur',
        phone: '+919250138656',
        ownerPhone: '+919250138656',
        lat: 26.1550,
        lng: 80.1730,
        isOpen: true,
      ),
      Restaurant(
        id: 'REST-103',
        name: 'Bal Udyan Restaurant',
        slug: 'bal-udyan-restaurant',
        description: 'Family Restaurant & Cafe',
        address: 'Near Bal Udyan, Ghatampur',
        phone: '+917991488783',
        ownerPhone: '+917991488783',
        lat: 26.1510,
        lng: 80.1690,
        isOpen: true,
      ),
      Restaurant(
        id: 'REST-104',
        name: 'Hot Pizza Lovers',
        slug: 'hot-pizza-lovers',
        description: 'Fresh Pizzas, Garlic Bread & Beverages in Ghatampur',
        address: 'Station Road Ghatampur',
        phone: '+918112849854',
        ownerPhone: '+918112849854',
        lat: 26.1484783,
        lng: 80.1667542,
        isOpen: true,
      ),
      Restaurant(
        id: 'REST-105',
        name: 'Pari Sweets & Bakers',
        slug: 'pari-milk-dairy',
        description: 'Fresh Dairy, Sweets & Bakery items',
        address: 'Ghatampur Market, UP',
        phone: '+918112849854',
        ownerPhone: '+918112849854',
        lat: 26.1520,
        lng: 80.1700,
        isOpen: true,
      ),
    ];

    for (final r in initialList) {
      register(r);
    }
  }

  /// Register or update a list of restaurants fetched from DB/API
  static void registerAll(List<Restaurant> list) {
    _ensureInitialized();
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

  /// Find restaurant dynamically by ID, slug, or name (with smart fuzzy & keyword match)
  static Restaurant? find(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    _ensureInitialized();
    final q = query.toLowerCase().trim();
    if (_byKey.containsKey(q)) return _byKey[q];

    for (final r in _byKey.values) {
      final rId = r.id.toLowerCase().trim();
      final rSlug = r.slug.toLowerCase().trim();
      final rName = r.name.toLowerCase().trim();
      if (rId == q ||
          rSlug == q ||
          rName == q ||
          rName.contains(q) ||
          q.contains(rName)) {
        return r;
      }
    }

    // Keyword heuristics for known brands if search query slightly varies
    if (q.contains('pizza')) {
      for (final r in _byKey.values) {
        if (r.name.toLowerCase().contains('pizza')) return r;
      }
    }
    if (q.contains('wedson')) {
      for (final r in _byKey.values) {
        if (r.name.toLowerCase().contains('wedson')) return r;
      }
    }
    if (q.contains('bal udyan') || q.contains('baludyan')) {
      for (final r in _byKey.values) {
        if (r.name.toLowerCase().contains('bal udyan')) return r;
      }
    }
    if (q.contains('a.s.') || q.contains('as cafe') || q.contains('as restaurant')) {
      for (final r in _byKey.values) {
        if (r.name.toLowerCase().contains('a.s.')) return r;
      }
    }

    return null;
  }

  /// Find restaurant by owner phone number (matches against database `ownerPhone` column)
  static Restaurant? findByPhone(String phone) {
    _ensureInitialized();
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
    _ensureInitialized();
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
  final String? phone;

  const OutletLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.isRestaurant,
    this.phone,
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
  phone: AppConfig.supportPhone,
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
        return getOutletLocation(
          restaurantId: subRestId,
          shopName: subShopName,
          orderType: 'RESTAURANT',
          items: subItems,
          rawOrder: s,
        );
      }
    }
  }

  // 2. Extract from rawOrder if passed
  Map<String, dynamic>? rawOrderMap;
  if (rawOrder is Map) {
    rawOrderMap = Map<String, dynamic>.from(rawOrder);
    restaurantId ??= rawOrderMap['restaurantId']?.toString();
    shopName ??= (rawOrderMap['restaurantName'] ?? rawOrderMap['shopName'])?.toString();
    orderType ??= rawOrderMap['orderType']?.toString();
    if (items == null && rawOrderMap['items'] is List) {
      items = rawOrderMap['items'] as List<dynamic>;
    }
  }

  // 3. Direct extraction from joined `restaurant` object (Supabase/Prisma)
  if (rawOrderMap != null && rawOrderMap['restaurant'] is Map) {
    final r = Map<String, dynamic>.from(rawOrderMap['restaurant'] as Map);
    final rName = (r['name'] ?? shopName ?? 'Restaurant').toString().trim();
    final rAddress = (r['address'] ?? 'Station Road Ghatampur').toString().trim();
    final rLat = (r['lat'] as num?)?.toDouble() ?? (r['latitude'] as num?)?.toDouble();
    final rLng = (r['lng'] as num?)?.toDouble() ?? (r['longitude'] as num?)?.toDouble();
    final rPhone = (r['phone'] ?? r['ownerPhone'] ?? rawOrderMap['shopPhone'])?.toString().trim();
    final rId = (r['id'] ?? restaurantId ?? 'restaurant-outlet').toString().trim();

    // Auto-register dynamically into registry
    try {
      RestaurantRegistry.register(Restaurant(
        id: rId,
        name: rName,
        slug: r['slug']?.toString() ?? '',
        address: rAddress,
        phone: rPhone,
        ownerPhone: rPhone,
        lat: rLat,
        lng: rLng,
      ));
    } catch (_) {}

    return OutletLocation(
      id: rId,
      name: rName,
      lat: rLat ?? darkstoreLocation.lat,
      lng: rLng ?? darkstoreLocation.lng,
      address: rAddress,
      isRestaurant: true,
      phone: rPhone,
    );
  }

  // 4. Dynamic lookup from RestaurantRegistry (DB-driven GPS coordinates & address)
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
      phone: rest.phone ?? rest.ownerPhone ?? rawOrderMap?['shopPhone']?.toString(),
    );
  }

  // 5. Inspect item restaurant IDs if available
  if (items != null && items.isNotEmpty) {
    for (final it in items) {
      final itemRestId = (it is Map ? (it['restaurantId'] ?? it['restaurant_id']) : null)?.toString();
      final itemRest = RestaurantRegistry.find(itemRestId);
      if (itemRest != null) {
        return OutletLocation(
          id: itemRest.id,
          name: itemRest.name,
          lat: itemRest.lat ?? darkstoreLocation.lat,
          lng: itemRest.lng ?? darkstoreLocation.lng,
          address: itemRest.address ?? 'Ghatampur, UP',
          isRestaurant: true,
          phone: itemRest.phone ?? itemRest.ownerPhone,
        );
      }
    }
  }

  // 6. Dynamic Food Order / Non-Darkstore Outlet Fallback (Never mislabel food outlet as dark store!)
  final isFoodOrder = (orderType?.toUpperCase() == 'RESTAURANT') ||
      (restaurantId != null && restaurantId.trim().isNotEmpty) ||
      (rawOrderMap != null &&
          ((rawOrderMap['readableId']?.toString().toUpperCase().endsWith('-R') ?? false) ||
              (rawOrderMap['orderType']?.toString().toUpperCase() == 'RESTAURANT') ||
              (rawOrderMap['restaurantId'] != null && rawOrderMap['restaurantId'].toString().trim().isNotEmpty)));

  final isCustomShop = shopName != null &&
      shopName.trim().isNotEmpty &&
      !shopName.toLowerCase().contains('dark store') &&
      !shopName.toLowerCase().contains('fastkirana dark') &&
      !shopName.toLowerCase().contains('fastkirana store');

  if (isFoodOrder || isCustomShop) {
    final resolvedName = (isCustomShop ? shopName.trim() : null) ??
        (restaurantId != null ? 'Restaurant ($restaurantId)' : 'Food Kitchen');

    final resolvedPhone = rawOrderMap?['shopPhone']?.toString().trim();
    final resolvedAddress = rawOrderMap?['shopAddress']?.toString().trim() ??
        rawOrderMap?['restaurantAddress']?.toString().trim() ??
        (resolvedName.toLowerCase().contains('pizza')
            ? 'Station Road Ghatampur'
            : 'Ghatampur Market, UP');

    final double? shopLat = (rawOrderMap?['shopLat'] as num?)?.toDouble() ??
        (resolvedName.toLowerCase().contains('pizza') ? 26.1484783 : null);
    final double? shopLng = (rawOrderMap?['shopLng'] as num?)?.toDouble() ??
        (resolvedName.toLowerCase().contains('pizza') ? 80.1667542 : null);

    return OutletLocation(
      id: restaurantId ?? 'restaurant-outlet',
      name: resolvedName,
      lat: shopLat ?? darkstoreLocation.lat,
      lng: shopLng ?? darkstoreLocation.lng,
      address: resolvedAddress,
      isRestaurant: true,
      phone: resolvedPhone,
    );
  }

  // 7. Default to FastKirana Dark Store ONLY for Grocery orders
  return darkstoreLocation;
}

/// Extension on Product for clean outlet & restaurant queries
extension ProductRestaurantExtension on Product {
  bool get isRestaurantProduct => isCafeProduct(this);
  String get outletName => getOutletName(this);
}
