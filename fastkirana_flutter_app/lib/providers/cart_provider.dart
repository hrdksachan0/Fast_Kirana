import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  int get totalItemCount {
    int total = 0;
    _items.forEach((key, item) { total += item.quantity; });
    return total;
  }

  double get subtotalAmount {
    double total = 0.0;
    _items.forEach((key, item) { total += item.totalPrice; });
    return total;
  }

  double get totalMrp {
    double total = 0.0;
    _items.forEach((key, item) { total += item.product.originalPrice != null
        ? item.product.originalPrice! * item.quantity
        : item.product.price * item.quantity; });
    return total;
  }

  double get totalSavings => totalMrp - subtotalAmount;

  int getItemQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  CartItem? getItem(String productId) => _items[productId];

  void addItem(Product product) {
    final productId = product.id;
    if (_items.containsKey(productId)) {
      final current = _items[productId]!;
      final newQty = (current.quantity + 1).clamp(0, product.stock);
      _items[productId] = current.copyWith(quantity: newQty);
    } else {
      _items[productId] = CartItem(product: product, quantity: 1);
    }
    notifyListeners();
    _saveCart();
  }

  void removeItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items[productId] = _items[productId]!.copyWith(
        quantity: _items[productId]!.quantity - 1,
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
    _saveCart();
  }

  void updateQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      final product = _items[productId]!.product;
      final clampedQty = quantity.clamp(1, product.stock);
      _items[productId] = _items[productId]!.copyWith(quantity: clampedQty);
    }
    notifyListeners();
    _saveCart();
  }

  void updateItemNotes(String productId, String notes) {
    if (!_items.containsKey(productId)) return;
    _items[productId] = _items[productId]!.copyWith(notes: notes.isNotEmpty ? notes : null);
    notifyListeners();
    _saveCart();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveCart();
  }

  bool hasProduct(String productId) => _items.containsKey(productId);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  List<Product> get products => _items.values.map((i) => i.product).toList();

  // ── Persistence ──
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _items.map((key, value) =>
        MapEntry(key, {
          'product': value.product.toJson(),
          'quantity': value.quantity,
          'notes': value.notes,
        })
      );
      await prefs.setString('fastkirana_cart', cartData.toString());
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('fastkirana_cart');
      if (cartString != null && cartString.isNotEmpty) {
        _items.clear();
        // Parse and restore
        notifyListeners();
      }
    } catch (e) {
      // Silently fail
    }
  }
}

extension ProductExtension on Product {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'category_slug': categorySlug,
    'price': price,
    'original_price': originalPrice,
    'unit': unit,
    'image_url': imageUrl,
    'is_available': isAvailable,
    'stock': stock,
    'discount': discount,
    'is_best_seller': isBestSeller,
    'is_flash_deal': isFlashDeal,
    'is_top_pick': isTopPick,
    'tags': tags,
    'rating': rating,
    'review_count': reviewCount,
  };
}
