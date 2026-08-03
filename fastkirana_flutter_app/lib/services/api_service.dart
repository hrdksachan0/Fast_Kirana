import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart';
import '../models/order.dart';
import '../models/address.dart';
import '../models/coupon.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:8000/api';

  // Use your computer's local IP for physical device testing
  // static const String _baseUrl = 'http://192.168.1.100:8000/api';

  static String get baseUrl => _baseUrl;

  // ── Products ──
  static Future<List<Product>> fetchProducts({String? category, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;
      queryParams['limit'] = '50';

      final uri = Uri.parse('$_baseUrl/products').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.map((p) => Product.fromJson(p)).toList();
        if (data is Map && data['results'] != null) return (data['results'] as List).map((p) => Product.fromJson(p)).toList();
        if (data is Map && data['data'] != null) return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
      }
      return _getMockProducts();
    } catch (e) {
      return _getMockProducts();
    }
  }

  static Future<Product?> fetchProduct(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/products/$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return Product.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Product>> fetchFlashDeals() async {
    try {
      final uri = Uri.parse('$_baseUrl/products?is_flash_deal=true&limit=20');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((p) => Product.fromJson(p)).toList();
      }
      return _getMockProducts().where((p) => p.isFlashDeal).toList();
    } catch (e) {
      return _getMockProducts().where((p) => p.isFlashDeal).toList();
    }
  }

  static Future<List<Product>> fetchBestSellers() async {
    try {
      final uri = Uri.parse('$_baseUrl/products?is_best_seller=true&limit=20');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((p) => Product.fromJson(p)).toList();
      }
      return _getMockProducts().where((p) => p.isBestSeller).toList();
    } catch (e) {
      return _getMockProducts().where((p) => p.isBestSeller).toList();
    }
  }

  // ── Categories ──
  static Future<List<Category>> fetchCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/categories');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((c) => Category.fromJson(c)).toList();
      }
      return _getMockCategories();
    } catch (e) {
      return _getMockCategories();
    }
  }

  static Future<List<Product>> fetchCategoryProducts(String categorySlug) async {
    try {
      final uri = Uri.parse('$_baseUrl/products?category=$categorySlug&limit=50');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((p) => Product.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Banners ──
  static Future<List<Banner>> fetchBanners() async {
    try {
      final uri = Uri.parse('$_baseUrl/banners?active=true');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((b) => Banner.fromJson(b)).toList();
      }
      return _getMockBanners();
    } catch (e) {
      return _getMockBanners();
    }
  }

  // ── Orders ──
  static Future<List<Order>> fetchOrders(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/orders?user_id=$userId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((o) => Order.fromJson(o)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Order?> placeOrder(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$_baseUrl/orders');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Order.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Order?> fetchOrder(String orderId) async {
    try {
      final uri = Uri.parse('$_baseUrl/orders/$orderId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return Order.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Addresses ──
  static Future<List<Address>> fetchAddresses(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/addresses?user_id=$userId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((a) => Address.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Coupons ──
  static Future<Coupon?> validateCoupon(String code, double subtotal) async {
    try {
      final uri = Uri.parse('$_baseUrl/coupons/validate');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'subtotal': subtotal}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Coupon(
          code: data['code'] ?? code,
          description: data['description'] ?? '',
          discountAmount: (data['discount_amount'] ?? 0).toDouble(),
          minOrderValue: data['min_order_value']?.toDouble(),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Search ──
  static Future<List<Product>> searchProducts(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/products?search=$query&limit=20');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
        return (list as List).map((p) => Product.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Store Status ──
  static Future<Map<String, dynamic>> fetchStoreStatus() async {
    try {
      final uri = Uri.parse('$_baseUrl/store/status');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return _getMockStoreStatus();
    } catch (e) {
      return _getMockStoreStatus();
    }
  }

  // ── Mock Data (for development / offline fallback) ──
  static List<Product> _getMockProducts() {
    return [
      Product(
        id: '1', name: 'Amul Taaza Toned Milk', category: 'Dairy & Breakfast',
        categorySlug: 'dairy-breakfast', price: 27, originalPrice: 30, unit: '500 ml',
        imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300',
        isBestSeller: true, discount: 10, stock: 50, isAvailable: true,
      ),
      Product(
        id: '2', name: 'Fresh Farm Eggs', category: 'Dairy & Breakfast',
        categorySlug: 'dairy-breakfast', price: 48, originalPrice: 55, unit: '6 pcs',
        imageUrl: 'https://images.unsplash.com/photo-1516448620398-c5f44bf9f441?w=300',
        isBestSeller: true, discount: 13, stock: 30, isAvailable: true,
      ),
      Product(
        id: '3', name: 'Fresh Tomatoes', category: 'Fruits & Vegetables',
        categorySlug: 'fruits-vegetables', price: 30, originalPrice: 40, unit: '500g',
        imageUrl: 'https://images.unsplash.com/photo-1546470427-0d4db154ceb8?w=300',
        isFlashDeal: true, discount: 25, stock: 100, isAvailable: true,
      ),
      Product(
        id: '4', name: 'Britannia Bread', category: 'Bakery & Biscuits',
        categorySlug: 'bakery-biscuits', price: 35, originalPrice: 40, unit: '400g',
        imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300',
        discount: 12, stock: 25, isAvailable: true,
      ),
      Product(
        id: '5', name: 'Maggi Masala Noodles', category: 'Snacks & Munchies',
        categorySlug: 'snacks-munchies', price: 14, originalPrice: 15, unit: '70g',
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-515a7cb661cf?w=300',
        isBestSeller: true, discount: 7, stock: 200, isAvailable: true,
      ),
      Product(
        id: '6', name: 'Tata Salt', category: 'Atta, Rice & Dal',
        categorySlug: 'atta-rice-dal', price: 22, originalPrice: 25, unit: '1kg',
        imageUrl: 'https://images.unsplash.com/photo-1628102491629-778571d893a3?w=300',
        isTopPick: true, stock: 80, isAvailable: true,
      ),
      Product(
        id: '7', name: 'Dove Shampoo', category: 'Personal Care',
        categorySlug: 'personal-care', price: 180, originalPrice: 220, unit: '340ml',
        imageUrl: 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=300',
        discount: 18, stock: 15, isAvailable: true,
      ),
      Product(
        id: '8', name: 'Surf Excel Detergent', category: 'Household',
        categorySlug: 'household', price: 95, originalPrice: 110, unit: '1kg',
        imageUrl: 'https://images.unsplash.com/photo-1615634260167-c8cdede054de?w=300',
        discount: 14, stock: 40, isAvailable: true,
      ),
      Product(
        id: '9', name: 'Coca-Cola', category: 'Beverages',
        categorySlug: 'beverages', price: 40, originalPrice: 45, unit: '750ml',
        imageUrl: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=300',
        isFlashDeal: true, discount: 11, stock: 60, isAvailable: true,
      ),
      Product(
        id: '10', name: 'Amul Butter', category: 'Dairy & Breakfast',
        categorySlug: 'dairy-breakfast', price: 52, originalPrice: 55, unit: '100g',
        imageUrl: 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300',
        isBestSeller: true, stock: 35, isAvailable: true,
      ),
      Product(
        id: '11', name: 'Fresh Onions', category: 'Fruits & Vegetables',
        categorySlug: 'fruits-vegetables', price: 25, originalPrice: 35, unit: '1kg',
        imageUrl: 'https://images.unsplash.com/photo-1620574383145-65b4f1b9102e?w=300',
        discount: 29, stock: 150, isAvailable: true, isFlashDeal: true,
      ),
      Product(
        id: '12', name: 'Parle-G Biscuits', category: 'Bakery & Biscuits',
        categorySlug: 'bakery-biscuits', price: 10, originalPrice: 10, unit: '100g',
        imageUrl: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=300',
        isBestSeller: true, stock: 300, isAvailable: true,
      ),
    ];
  }

  static List<Category> _getMockCategories() {
    return [
      Category(id: '1', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', sortOrder: 1),
      Category(id: '2', name: 'Dairy & Breakfast', slug: 'dairy-breakfast', sortOrder: 2),
      Category(id: '3', name: 'Snacks & Munchies', slug: 'snacks-munchies', sortOrder: 3),
      Category(id: '4', name: 'Beverages', slug: 'beverages', sortOrder: 4),
      Category(id: '5', name: 'Personal Care', slug: 'personal-care', sortOrder: 5),
      Category(id: '6', name: 'Household', slug: 'household', sortOrder: 6),
      Category(id: '7', name: 'Bakery & Biscuits', slug: 'bakery-biscuits', sortOrder: 7),
      Category(id: '8', name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', sortOrder: 8),
      Category(id: '9', name: 'Ice Cream', slug: 'ice-cream', sortOrder: 9),
    ];
  }

  static List<Banner> _getMockBanners() {
    return [
      Banner(
        id: '1',
        title: 'Fresh Vegetables',
        subtitle: 'Get 30% off on first order',
        imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
        link: '/category/fruits-vegetables',
      ),
      Banner(
        id: '2',
        title: 'Cafe Special',
        subtitle: 'Hot coffee & snacks delivered in 10 mins',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800',
        link: '/food',
      ),
    ];
  }

  static Map<String, dynamic> _getMockStoreStatus() {
    return {
      'grocery_open': true,
      'cafe_open': true,
      'delivery_radius': 5.0,
    };
  }
}
