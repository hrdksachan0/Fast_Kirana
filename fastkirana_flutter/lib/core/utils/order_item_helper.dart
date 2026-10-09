import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import 'restaurant_utils.dart';

class OrderItemHelper {
  /// Extracts the weight, pack size, unit, or variant from an order item map or object.
  /// Checks explicit variant fields, product unit fields, portion/size, and falls back to regex matching from the title.
  static String resolveWeightOrVariant(dynamic item, [String? fallbackName]) {
    String? explicit;
    String name = fallbackName ?? '';

    if (item is Map) {
      if (name.isEmpty) {
        name = (item['name'] ?? item['title'] ?? '').toString();
      }

      final val = item['selectedVariant'] ??
          item['selected_variant'] ??
          item['variant'] ??
          item['variant_name'] ??
          item['size'] ??
          item['portion'] ??
          item['unit'] ??
          item['weight'] ??
          item['pack_size'] ??
          item['quantity_unit'];

      if (val != null &&
          val.toString().trim().isNotEmpty &&
          val.toString().trim().toLowerCase() != 'null' &&
          val.toString().trim().toLowerCase() != 'standard') {
        explicit = val.toString().trim();
      } else if (item['product'] is Map) {
        final p = item['product'];
        final pVal = p['selectedVariant'] ??
            p['selected_variant'] ??
            p['variant'] ??
            p['variant_name'] ??
            p['size'] ??
            p['portion'] ??
            p['unit'] ??
            p['weight'] ??
            p['pack_size'];
        if (pVal != null &&
            pVal.toString().trim().isNotEmpty &&
            pVal.toString().trim().toLowerCase() != 'null' &&
            pVal.toString().trim().toLowerCase() != 'standard') {
          explicit = pVal.toString().trim();
        }
      }
    } else if (item != null) {
      try {
        final dyn = item as dynamic;
        final val = dyn.selectedVariant ??
            dyn.variant ??
            dyn.size ??
            dyn.portion ??
            dyn.unit ??
            dyn.weight;
        if (val != null &&
            val.toString().trim().isNotEmpty &&
            val.toString().trim().toLowerCase() != 'null' &&
            val.toString().trim().toLowerCase() != 'standard') {
          explicit = val.toString().trim();
        }
        if (name.isEmpty) {
          name = dyn.name?.toString() ?? dyn.title?.toString() ?? '';
        }
      } catch (_) {}
    }

    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    if (name.isNotEmpty) {
      // Fallback 1: Extract variant inside brackets/parentheses in title (e.g. "Chole Bhature (2Pc)", "Paneer Tikka (Half)", "Aloo Paratha (2 Pc)", "Chili Potato (Gravy)")
      final generalBracketMatch = RegExp(
        r'[\(\[]\s*([^()\[\]]{1,25})\s*[\)\]]',
        caseSensitive: false,
      ).firstMatch(name);
      if (generalBracketMatch != null) {
        final rawContent = generalBracketMatch.group(1)!.trim();
        final lower = rawContent.toLowerCase();
        // Ignore pure veg/non-veg tags
        if (lower != 'veg' && lower != 'pure veg' && lower != 'non-veg' && lower != 'egg') {
          final cleaned = rawContent.replaceAllMapped(
            RegExp(r'(\d+)\s*(pc|pcs|gm|g|kg|ml|l)\b', caseSensitive: false),
            (m) {
              final numPart = m[1];
              final unitPart = m[2]!.toLowerCase();
              if (unitPart.startsWith('pc')) return '$numPart Pc';
              if (unitPart == 'gm' || unitPart == 'g') return '$numPart gm';
              if (unitPart == 'kg') return '$numPart kg';
              if (unitPart == 'ml') return '$numPart ml';
              if (unitPart == 'l') return '$numPart L';
              return '${m[0]}';
            },
          );
          if (cleaned.isNotEmpty) {
            return cleaned[0].toUpperCase() + (cleaned.length > 1 ? cleaned.substring(1) : '');
          }
        }
      }

      // Fallback 2: Size with leading hyphen (e.g. "Veg Chowmein - Half")
      final sizeDashMatch = RegExp(
        r'-\s*(half|full|quarter|small|medium|large|regular|single|double)\b',
        caseSensitive: false,
      ).firstMatch(name);
      if (sizeDashMatch != null) {
        final s = sizeDashMatch.group(1)!.trim();
        return s[0].toUpperCase() + s.substring(1).toLowerCase();
      }

      // Fallback 3: Extract weight/unit from product title (e.g. "Sugar 500 gm", "Tata Salt 1 kg", "Fortune Oil 5 L")
      final match = RegExp(
        r'(\d+(?:\.\d+)?\s*(?:kg|kgs|gm|gms|g|ltr|ltrs|lt|l|ml|pc|pcs|pack|katta|dozen|plate|piece|serving))\b',
        caseSensitive: false,
      ).firstMatch(name);
      if (match != null) {
        return match.group(1)!.trim();
      }

      // Fallback 4: standalone size word
      final standaloneSize = RegExp(
        r'\b(half|full|quarter|small|medium|large|regular)\b',
        caseSensitive: false,
      ).firstMatch(name);
      if (standaloneSize != null) {
        final s = standaloneSize.group(1)!.trim();
        return s[0].toUpperCase() + s.substring(1).toLowerCase();
      }

      // Fallback 5: Context-aware defaults for cooked restaurant food items
      if (RestaurantRegistry.isFoodDishName(name)) {
        final lower = name.toLowerCase();
        if (lower.contains('burger') ||
            lower.contains('sandwich') ||
            lower.contains('roll') ||
            lower.contains('patty') ||
            lower.contains('roti') ||
            lower.contains('naan') ||
            lower.contains('paratha')) {
          return '1 Pc';
        }
        if (lower.contains('shake') ||
            lower.contains('coffee') ||
            lower.contains('tea') ||
            lower.contains('chai') ||
            lower.contains('juice') ||
            lower.contains('lassi')) {
          return '1 Glass';
        }
        if (lower.contains('pizza')) {
          return 'Regular';
        }
        return '1 Portion';
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

  /// Builds a prominent, high-visibility weight/pack-size/portion badge.
  static Widget buildWeightBadge(
    BuildContext context,
    String weightVariant, {
    bool isPicked = false,
  }) {
    if (weightVariant.isEmpty) return const SizedBox.shrink();

    final isPortion = RegExp(
      r'^(half|full|regular|small|medium|large|quarter|single|double|plate|piece|serving)',
      caseSensitive: false,
    ).hasMatch(weightVariant.trim());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPicked
            ? const Color(0xFFD1FAE5)
            : (isPortion ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPicked
              ? const Color(0xFFA7F3D0)
              : (isPortion ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPortion ? Icons.restaurant_menu_rounded : Icons.scale_outlined,
            size: 11,
            color: isPicked
                ? const Color(0xFF047857)
                : (isPortion ? const Color(0xFFB45309) : const Color(0xFF475569)),
          ),
          const SizedBox(width: 3.5),
          Text(
            weightVariant,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w800,
              color: isPicked
                  ? const Color(0xFF047857)
                  : (isPortion ? const Color(0xFF92400E) : const Color(0xFF0F172A)),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
