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
