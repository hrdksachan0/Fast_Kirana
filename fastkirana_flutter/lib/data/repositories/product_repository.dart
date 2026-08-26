import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../../core/network/api_client.dart';

class ProductRepository {
  final Dio dio;
  List<Product>? _cachedProducts;
  DateTime? _lastFetchTime;

  ProductRepository(this.dio);

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    String? restaurantId,
    int limit = 1000,
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();
      // Cache products in memory for 2 minutes to keep app super fast
      if (!forceRefresh &&
          _cachedProducts != null &&
          _lastFetchTime != null &&
          now.difference(_lastFetchTime!).inMinutes < 2) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }

      final response = await dio.get(
        '/api/products',
        queryParameters: {
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          if (restaurantId != null && restaurantId.isNotEmpty) 'restaurantId': restaurantId,
        },
      );

      final data = response.data;
      List productsJson = [];
      if (data is List) {
        productsJson = data;
      } else if (data is Map && data['products'] is List) {
        productsJson = data['products'];
      }

      final liveProducts = productsJson
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      _cachedProducts = liveProducts;
      _lastFetchTime = now;

      return _filterProducts(liveProducts, category: category, search: search, restaurantId: restaurantId);
    } catch (e) {
      if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }
      return _filterProducts(_getStaticFallbackProducts(), category: category, search: search, restaurantId: restaurantId);
    }
  }

  List<Product> _getStaticFallbackProducts() {
    final list = [
      {
        'id': 'prod_potato',
        'name': 'Fresh Potato (Aloo)',
        'slug': 'fresh-potato-aloo',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 28.0,
        'mrp': 35.0,
        'imageUrl': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500&q=80',
        'unit': '1 kg',
        'tags': ['potato', 'aloo', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_onion',
        'name': 'Fresh Red Onion (Pyaz)',
        'slug': 'fresh-red-onion-pyaz',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 38.0,
        'mrp': 45.0,
        'imageUrl': 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=500&q=80',
        'unit': '1 kg',
        'tags': ['onion', 'pyaz', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_tomato',
        'name': 'Hybrid Tomato (Tamatar)',
        'slug': 'hybrid-tomato-tamatar',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 32.0,
        'mrp': 40.0,
        'imageUrl': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500&q=80',
        'unit': '1 kg',
        'tags': ['tomato', 'tamatar', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_banana',
        'name': 'Robusta Banana (Kela)',
        'slug': 'robusta-banana-kela',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 45.0,
        'mrp': 60.0,
        'imageUrl': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&q=80',
        'unit': '1 Dozen (12 pcs)',
        'tags': ['banana', 'kela', 'fruits', 'fresh'],
      },
      {
        'id': 'prod_apple',
        'name': 'Shimla Royal Apple (Seb)',
        'slug': 'shimla-royal-apple-seb',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 140.0,
        'mrp': 180.0,
        'imageUrl': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&q=80',
        'unit': '1 kg (4-5 pcs)',
        'tags': ['apple', 'seb', 'fruits', 'fresh'],
      },
      {
        'id': 'prod_atta',
        'name': 'Aashirvaad Shudh Chakki Atta',
        'slug': 'aashirvaad-shudh-chakki-atta',
        'categoryId': 'cmsfuzs73000404l7q139nk61',
        'category': {'id': 'cmsfuzs73000404l7q139nk61', 'name': 'Atta, Rice & Dal', 'slug': 'atta-rice-dal'},
        'price': 245.0,
        'mrp': 275.0,
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&q=80',
        'unit': '5 kg',
        'tags': ['atta', 'aashirvaad', 'flour', 'grocery'],
      },
      {
        'id': 'prod_milk',
        'name': 'Amul Taaza Homogenised Toned Milk',
        'slug': 'amul-taaza-toned-milk',
        'categoryId': 'cmsfuzs73000404l7q139nk61',
        'category': {'id': 'cmsfuzs73000404l7q139nk61', 'name': 'Dairy & Breakfast', 'slug': 'dairy'},
        'price': 27.0,
        'mrp': 28.0,
        'imageUrl': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
        'unit': '500 ml',
        'tags': ['milk', 'amul', 'doodh', 'dairy'],
      },
      {
        'id': 'prod_lays',
        'name': 'Lay\'s India\'s Magic Masala Chips',
        'slug': 'lays-magical-masala',
        'categoryId': 'cmqh1hb920002zcidoywpi240',
        'category': {'id': 'cmqh1hb920002zcidoywpi240', 'name': 'Snacks & Munchies', 'slug': 'snacks-munchies'},
        'price': 20.0,
        'mrp': 20.0,
        'imageUrl': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&q=80',
        'unit': '50 g',
        'tags': ['lays', 'chips', 'snacks', 'munchies'],
      },
      {
        'id': 'prod_coke',
        'name': 'Coca-Cola Original Taste',
        'slug': 'coca-cola-can',
        'categoryId': 'cmqgzqfz20008vkidoycqg5u2',
        'category': {'id': 'cmqgzqfz20008vkidoycqg5u2', 'name': 'Cold Drinks & Juices', 'slug': 'beverages'},
        'price': 40.0,
        'mrp': 40.0,
        'imageUrl': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&q=80',
        'unit': '300 ml (Can)',
        'tags': ['coke', 'coca-cola', 'drinks', 'cold drinks', 'beverages'],
      },
    ];

    return list.map((j) => Product.fromJson(j)).toList();
  }

  static const Map<String, List<String>> _categoryAliases = {
    'cmqh1haw30000zcid4vj7i1yj': ['fruits-vegetables', 'fruits & vegetables', 'fruits', 'vegetables', 'fresh', 'farm'],
    'cmt76olwr000104l18kcelx0i': ['healthy-foods', 'healthy foods', 'healthy', 'diet', 'dry-fruits', 'oats'],
    'cmsfuzs73000404l7q139nk61': ['kitchen-needs', 'kitchen needs', 'atta-rice-dal', 'atta', 'rice', 'dal', 'oil', 'grocery', 'spices'],
    'cmqh1hb920002zcidoywpi240': ['snacks-munchies', 'snacks & munchies', 'snacks', 'munchies', 'chips', 'namkeen', 'biscuits'],
    'cmqgzqfz20008vkidoycqg5u2': ['beverages', 'beverages & drinks', 'drinks', 'cold drinks', 'juices', 'soda', 'tea', 'coffee'],
    'cmqgzqfv70007vkider7h6e4j': ['ice-cream', 'ice cream & desserts', 'ice cream', 'desserts', 'kulfi', 'cones'],
    'cmseowmy7000004i562szts34': ['chocolates', 'chocolates & sweets', 'sweets', 'chocolate', 'silk', 'cadbury'],
    'cmqh1hbyc0005zcidr45bj1ac': ['bakery', 'bakery & biscuits', 'biscuits', 'cookies', 'bread', 'rusk'],
    'cmt74ypjp000004laoi3athcy': ['packaged-foods', 'packaged foods', 'instant', 'noodles', 'maggie', 'pasta'],
    'cmqh1hblj0003zcidm9gq5net': ['personal-care', 'personal care & hygiene', 'personal care', 'soap', 'shampoo', 'creams'],
    'cmrv2psby000004ldl25xjrlt': ['home-needs-and-cleaning', 'home needs & cleaning', 'cleaning', 'household', 'detergent', 'cleaner'],
    'cmt59fuss0000tgidoc35458x': ['restaurant-food', 'fast food & restaurant kitchen', 'cafe', 'food', 'restaurant'],
  };

  List<Product> _filterProducts(
    List<Product> products, {
    String? category,
    String? search,
    String? restaurantId,
  }) {
    var result = products;

    // 1. Restaurant vs Grocery Isolation
    if (restaurantId != null && restaurantId.isNotEmpty) {
      result = result.where((p) => p.restaurantId == restaurantId).toList();
    } else if (category != null && (category.contains('restaurant') || category.contains('cafe'))) {
      result = result.where((p) => p.restaurantId != null && p.restaurantId!.isNotEmpty).toList();
    } else {
      // Default: Grocery only (No restaurant meals like Roti/Naan in grocery sections)
      result = result.where((p) => p.restaurantId == null || p.restaurantId!.isEmpty).toList();
    }

    // 2. Category matching
    if (category != null && category.isNotEmpty && category != 'all') {
      final catLower = category.toLowerCase().trim();
      final catSlugNormalized = catLower.replaceAll(' ', '-').replaceAll('&', 'and').replaceAll('---', '-');
      result = result.where((p) {
        final prodCatSlug = (p.category?.slug ?? '').toLowerCase();
        final prodCatId = (p.category?.id ?? p.categoryId).toLowerCase();
        final prodCatName = (p.category?.name ?? '').toLowerCase();

        // Direct ID match
        if (prodCatId == catLower || p.categoryId.toLowerCase() == catLower) return true;

        // Direct Slug match
        if (prodCatSlug.isNotEmpty && (prodCatSlug == catLower || prodCatSlug == catSlugNormalized)) return true;

        // Direct Category Name match
        if (prodCatName.isNotEmpty && (prodCatName == catLower || prodCatName == catSlugNormalized)) return true;

        // Alias lookup by ID
        final aliasesForProd = _categoryAliases[p.categoryId] ?? _categoryAliases[prodCatId] ?? [];
        if (aliasesForProd.contains(catLower) || aliasesForProd.contains(catSlugNormalized)) return true;

        // Alias lookup by query key
        for (final entry in _categoryAliases.entries) {
          if (entry.value.contains(catLower) || entry.value.contains(catSlugNormalized)) {
            if (entry.key.toLowerCase() == p.categoryId.toLowerCase() || entry.key.toLowerCase() == prodCatId) {
              return true;
            }
          }
        }

        return false;
      }).toList();
    }

    // 3. Search query filter
    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase().trim();
      result = result.where((p) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = (p.description ?? '').toLowerCase().contains(query);
        final matchesTag = p.tags.any((t) => t.toLowerCase().contains(query));
        final matchesCat = (p.category?.name ?? '').toLowerCase().contains(query);
        return matchesName || matchesDesc || matchesTag || matchesCat;
      }).toList();
    }

    return result;
  }

  Future<Product> getProduct(String id) async {
    try {
      final response = await dio.get('/api/products/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Product.fromJson(data);
      }
      throw ApiException('Product not found');
    } catch (_) {
      if (_cachedProducts != null) {
        return _cachedProducts!.firstWhere(
          (p) => p.id == id,
          orElse: () => throw ApiException('Product not found'),
        );
      }
      rethrow;
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final response = await dio.get('/api/categories');
      final data = response.data;
      if (data is List) {
        return data.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    try {
      final allProducts = await getProducts(limit: 500);
      final Map<String, Category> uniqueCategories = {};

      for (final p in allProducts) {
        if (p.category != null && p.category!.slug.isNotEmpty) {
          final cat = p.category!;
          final slug = cat.slug.toLowerCase().trim();
          if (!uniqueCategories.containsKey(slug) && slug != 'restaurant') {
            uniqueCategories[slug] = Category(
              id: cat.id.isNotEmpty ? cat.id : 'cat_$slug',
              name: cat.name.isNotEmpty ? cat.name : slug.replaceAll('-', ' ').toUpperCase(),
              slug: slug,
              imageUrl: cat.imageUrl,
              sortOrder: uniqueCategories.length + 1,
            );
          }
        }
      }

      if (uniqueCategories.isNotEmpty) {
        return uniqueCategories.values.toList();
      }
    } catch (_) {}

    return [
      Category(id: 'cmqh1haw30000zcid4vj7i1yj', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', imageUrl: '/fruits_vegetables_category.png', sortOrder: 0),
      Category(id: 'cmsfuzs73000404l7q139nk61', name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', imageUrl: '/atta_rice_dal_category.png', sortOrder: 1),
      Category(id: 'cmqgzqfz20008vkidoycqg5u2', name: 'Cold Drinks & Juices', slug: 'beverages', imageUrl: '/beverages_category.png', sortOrder: 2),
      Category(id: 'cmqh1hb920002zcidoywpi240', name: 'Snacks & Munchies', slug: 'snacks-munchies', imageUrl: '/snacks_munchies_category.png', sortOrder: 3),
      Category(id: 'cmqgzqfv70007vkider7h6e4j', name: 'Ice Creams & More', slug: 'ice-cream', imageUrl: '/ice_cream_category.png', sortOrder: 4),
      Category(id: 'cmseowmy7000004i562szts34', name: 'Chocolates & Sweets', slug: 'chocolates', imageUrl: '/chocolates_category.png', sortOrder: 5),
      Category(id: 'cmqh1hbyc0005zcidr45bj1ac', name: 'Bakery & Biscuits', slug: 'bakery', imageUrl: '/bakery_biscuits_category.png', sortOrder: 6),
      Category(id: 'cmqh1hblj0003zcidm9gq5net', name: 'Personal Care', slug: 'personal-care', imageUrl: '/personal_care_category.png', sortOrder: 7),
      Category(id: 'cmrv2psby000004ldl25xjrlt', name: 'Home & Cleaning', slug: 'home-needs-and-cleaning', imageUrl: '/household_category.png', sortOrder: 8),
      Category(id: 'cmt59fuss0000tgidoc35458x', name: 'Cafe & Fast Food', slug: 'restaurant-food', imageUrl: '/cafe_category.png', sortOrder: 9),
    ];
  }
}