import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';

class OrderItemHelper {
  /// Extracts the weight, pack size, unit, or variant from an order item map.
  /// Checks explicit variant fields, product unit fields, and falls back to regex matching from the title.
  static String resolveWeightOrVariant(dynamic item, [String? fallbackName]) {
    String? explicit;
    String name = fallbackName ?? '';

    if (item is Map) {
      if (name.isEmpty) {
        name = (item['name'] ?? item['title'] ?? '').toString();
      }

      final val = item['selectedVariant'] ??
          item['variant'] ??
          item['unit'] ??
          item['weight'] ??
          item['size'] ??
          item['pack_size'] ??
          item['quantity_unit'];

      if (val != null && val.toString().trim().isNotEmpty) {
        explicit = val.toString().trim();
      } else if (item['product'] is Map) {
        final p = item['product'];
        final pVal = p['unit'] ??
            p['selectedVariant'] ??
            p['variant'] ??
            p['weight'] ??
            p['size'] ??
            p['pack_size'];
        if (pVal != null && pVal.toString().trim().isNotEmpty) {
          explicit = pVal.toString().trim();
        }
      }
    }

    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    // Fallback: Extract weight/unit from product title (e.g. "Sugar 500 gm", "Tata Salt 1 kg", "Fortune Oil 5 L")
    if (name.isNotEmpty) {
      final match = RegExp(
        r'(\d+(?:\.\d+)?\s*(?:kg|kgs|gm|gms|g|ltr|ltrs|lt|l|ml|pc|pcs|pack|katta|dozen|plate|piece|serving))\b',
        caseSensitive: false,
      ).firstMatch(name);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    return '';
  }

  /// Robustly extracts and normalizes the product image URL from any item representation.
  /// Handles:
  /// - Map keys: imageUrl, image_url, image, productImage, product_image, photo, thumbnail
  /// - Nested item['product'] structures
  /// - OrderItem model instances
  /// - Supabase storage relative paths & fastkirana.in paths
  /// - Fallback to deterministic Supabase storage URL via productId
  static String resolveImageUrl(dynamic item) {
    if (item == null) return '';

    dynamic rawImg;
    String? productId;

    if (item is Map) {
      rawImg = item['imageUrl'] ??
          item['image_url'] ??
          item['image'] ??
          item['productImage'] ??
          item['product_image'] ??
          item['photo'] ??
          item['photoUrl'] ??
          item['thumbnail'];

      if (rawImg == null && item['product'] is Map) {
        final p = item['product'];
        rawImg = p['imageUrl'] ?? p['image_url'] ?? p['image'] ?? p['thumbnail'];
        productId ??= p['id']?.toString() ?? p['productId']?.toString();
      }

      productId ??= item['productId']?.toString() ?? item['product_id']?.toString();
    } else {
      // Might be an OrderItem instance or custom object
      try {
        rawImg = (item as dynamic).imageUrl;
      } catch (_) {}
      try {
        productId = (item as dynamic).productId?.toString();
      } catch (_) {}
    }

    String str = rawImg?.toString().trim() ?? '';

    // If no direct image URL is provided, fallback to Supabase product image storage via productId
    if (str.isEmpty && productId != null && productId.trim().isNotEmpty) {
      final cleanPid = productId.trim();
      // Supabase product images are named {productId}.webp
      str = 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/$cleanPid.webp';
    }

    if (str.isEmpty || str == 'null') return '';

    if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:image')) {
      return str;
    }

    if (str.startsWith('//')) {
      return 'https:$str';
    }

    if (str.startsWith('products/') || str.startsWith('/products/')) {
      final clean = str.startsWith('/') ? str.substring(1) : str;
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/$clean';
    }

    if (str.startsWith('/')) {
      return 'https://www.fastkirana.in$str';
    }

    return 'https://www.fastkirana.in/$str';
  }

  /// Returns a contextual emoji for an item name to provide a delightful, app-native fallback.
  static String resolveFallbackEmoji(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('sandwich')) return '🥪';
    if (lower.contains('roll') || lower.contains('wrap')) return '🌯';
    if (lower.contains('noodle') || lower.contains('chowmein') || lower.contains('maggi')) return '🍜';
    if (lower.contains('pasta')) return '🍝';
    if (lower.contains('dosa') || lower.contains('idli') || lower.contains('vada')) return '🥞';
    if (lower.contains('coffee') || lower.contains('cappuccino') || lower.contains('latte')) return '☕';
    if (lower.contains('tea') || lower.contains('chai')) return '🍵';
    if (lower.contains('shake') || lower.contains('smoothie') || lower.contains('coke') || lower.contains('pepsi') || lower.contains('drink') || lower.contains('juice')) return '🥤';
    if (lower.contains('ice cream') || lower.contains('kulfi') || lower.contains('dessert') || lower.contains('cake') || lower.contains('pastry')) return '🍦';
    if (lower.contains('biryani') || lower.contains('fried rice') || lower.contains('rice') || lower.contains('chawal')) return '🍚';
    if (lower.contains('paneer') || lower.contains('cheese')) return '🧀';
    if (lower.contains('milk') || lower.contains('dahi') || lower.contains('curd')) return '🥛';
    if (lower.contains('butter') || lower.contains('ghee')) return '🧈';
    if (lower.contains('bread') || lower.contains('pav') || lower.contains('bun')) return '🍞';
    if (lower.contains('egg') || lower.contains('anda') || lower.contains('omelette')) return '🥚';
    if (lower.contains('samosa') || lower.contains('fry') || lower.contains('fries') || lower.contains('pakoda')) return '🍟';
    if (lower.contains('momo')) return '🥟';
    if (lower.contains('roti') || lower.contains('naan') || lower.contains('paratha')) return '🫓';
    if (lower.contains('dal') || lower.contains('soup') || lower.contains('gravy') || lower.contains('curry')) return '🥣';
    if (lower.contains('chips') || lower.contains('kurkure') || lower.contains('namkeen') || lower.contains('biscuit')) return '🍪';
    if (lower.contains('apple') || lower.contains('banana') || lower.contains('fruit')) return '🍎';
    if (lower.contains('oil') || lower.contains('tel')) return '🛢️';
    if (lower.contains('atta') || lower.contains('flour') || lower.contains('sugar') || lower.contains('salt')) return '🌾';
    if (lower.contains('soap') || lower.contains('shampoo') || lower.contains('wash')) return '🧼';
    return '🍽️';
  }

  /// Builds a prominent, high-visibility weight/pack-size badge.
  static Widget buildWeightBadge(
    BuildContext context,
    String weightVariant, {
    bool isPicked = false,
  }) {
    if (weightVariant.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPicked ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPicked ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.scale_outlined,
            size: 11,
            color: isPicked ? const Color(0xFF047857) : const Color(0xFF475569),
          ),
          const SizedBox(width: 3.5),
          Text(
            weightVariant,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w800,
              color: isPicked ? const Color(0xFF047857) : const Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
