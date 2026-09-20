import 'package:flutter/material.dart';

/// Centralized Card Color Palette — single source of truth for every color
/// used by CategoryOfferCard across Hero, Bento Grid, Editorial, and Standard
/// variants. Eliminates scattered hardcoded hex values.
///
/// Each palette defines one **accent family** while sharing identical surface,
/// text, and structural colors so cards always feel cohesive side-by-side.
class CardColorPalette {
  /// Primary accent — glow, eyebrow dot, CTA default, radial halo
  final Color accent;

  /// Lighter tint of accent — offer capsule border, highlight rings
  final Color accentLight;

  /// Darker shade of accent — pressed states, deep shadow tint
  final Color accentDark;

  /// Card background base color
  final Color surface;

  /// 3-stop background gradient (top-left → bottom-right)
  final List<Color> gradient;

  /// Title text color
  final Color textPrimary;

  /// Subtitle / description text color
  final Color textSecondary;

  /// Disclaimer / muted text color
  final Color textMuted;

  /// Category tag pill background
  final Color pillBg;

  /// Category tag pill border
  final Color pillBorder;

  const CardColorPalette({
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    this.surface = const Color(0xFFFFFFFF),
    this.gradient = const [
      Color(0xFFFFFBF5),
      Color(0xFFFFF3E8),
      Color(0xFFFEEDE0),
    ],
    this.textPrimary = const Color(0xFF0F172A), // Slate 900
    this.textSecondary = const Color(0xFF64748B), // Slate 500
    this.textMuted = const Color(0xFF94A3B8), // Slate 400
    this.pillBg = const Color(0xFFF1F5F9), // Slate 100
    this.pillBorder = const Color(0xFFE2E8F0), // Slate 200
  });

  // ─── Derived convenience colors (computed from accent) ─────────────

  /// Eyebrow pill background (accent @ 10% opacity)
  Color get eyebrowBg => accent.withOpacity(0.10);

  /// Eyebrow pill border (accent @ 25% opacity)
  Color get eyebrowBorder => accent.withOpacity(0.25);

  /// Radial ambient glow center (accent @ 18% opacity - soft and warm, not harsh)
  Color get glowCenter => accent.withOpacity(0.18);

  /// Radial ambient glow mid (accent @ 06% opacity)
  Color get glowMid => accent.withOpacity(0.06);

  /// Outer bezel gradient highlight (accent @ 18% opacity)
  Color get bezelHighlight => accent.withOpacity(0.18);

  /// Shadow aura color (soft ambient warm shadow)
  Color get shadowAura => accent.withOpacity(0.12);

  /// CTA button glow shadow
  Color get ctaShadow => accent.withOpacity(0.35);

  /// Offer capsule border tint
  Color get capsuleBorder => accentLight.withOpacity(0.40);

  /// Offer capsule icon background
  Color get capsuleIconBg => accentLight.withOpacity(0.18);

  // ═══════════════════════════════════════════════════════════════════════
  // STANDARD PALETTES (Option A: Appetizing Warm & Fresh Light Themes)
  // ═══════════════════════════════════════════════════════════════════════

  // ─── Grocery Mode ──────────────────────────────────────────────────

  /// Fruits, Vegetables, Organic — Crisp Farm Green on fresh mint surface
  static const groceryFresh = CardColorPalette(
    accent: Color(0xFF059669), // Emerald 600
    accentLight: Color(0xFF34D399),
    accentDark: Color(0xFF047857),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFF6FDF9),
      Color(0xFFECFDF5),
      Color(0xFFD1FAE5),
    ],
  );

  /// Dairy, Bread, Eggs, Staples — Soft Fresh Sky / Blue on crisp surface
  static const groceryPantry = CardColorPalette(
    accent: Color(0xFF2563EB), // Blue 600
    accentLight: Color(0xFF60A5FA),
    accentDark: Color(0xFF1D4ED8),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFF8FAFC),
      Color(0xFFEFF6FF),
      Color(0xFFDBEAFE),
    ],
  );

  /// Snacks, Chocolates, Ice Cream — Berry Purple on soft lavender surface
  static const grocerySnacks = CardColorPalette(
    accent: Color(0xFF7C3AED), // Violet 600
    accentLight: Color(0xFFA78BFA),
    accentDark: Color(0xFF6D28D9),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFAF5FF),
      Color(0xFFF3E8FF),
      Color(0xFFE9D5FF),
    ],
  );

  /// BOGO, Flash Sales, Festive — Radiant Warm Honey Gold
  static const groceryDeals = CardColorPalette(
    accent: Color(0xFFD97706), // Amber 600
    accentLight: Color(0xFFFBBF24),
    accentDark: Color(0xFFB45309),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFFFBEB),
      Color(0xFFFEF3C7),
      Color(0xFFFDE68A),
    ],
  );

  // ─── Food / Cafe Mode ─────────────────────────────────────────────

  /// Burgers, Pizza, Hot Items — Warm Coral / Food Red on warm buttery porcelain
  static const foodHot = CardColorPalette(
    accent: Color(0xFFEA580C), // Delicious Warm Amber-Orange (Zomato/Swiggy Gold Standard)
    accentLight: Color(0xFFFB923C),
    accentDark: Color(0xFFC2410C),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFFFBF5),
      Color(0xFFFFF1E6),
      Color(0xFFFFE4D1),
    ],
  );

  /// Multi-cuisine, Biryani, Combos — Deep Saffron & Warm Amber
  static const foodCuisine = CardColorPalette(
    accent: Color(0xFFEA580C),
    accentLight: Color(0xFFF97316),
    accentDark: Color(0xFFC2410C),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFFF7ED),
      Color(0xFFFFEDD5),
      Color(0xFFFED7AA),
    ],
  );

  /// Royal, Feast, Thali, Premium — Rich Ruby & Warm Peach
  static const foodPremium = CardColorPalette(
    accent: Color(0xFFE11D48), // Rose 600
    accentLight: Color(0xFFFB7185),
    accentDark: Color(0xFFBE123C),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFFF1F2),
      Color(0xFFFFE4E6),
      Color(0xFFFECDD3),
    ],
  );

  /// Shakes, Coffee, Desserts — Warm Caramel & Cream
  static const foodCafe = CardColorPalette(
    accent: Color(0xFFF97316),
    accentLight: Color(0xFFFB923C),
    accentDark: Color(0xFFEA580C),
    surface: Color(0xFFFFFFFF),
    gradient: [
      Color(0xFFFFF8F0),
      Color(0xFFFFEBD6),
      Color(0xFFFFDFBA),
    ],
  );

  // ─── Neutral Fallback ─────────────────────────────────────────────

  /// Generic / unknown category
  static const neutral = CardColorPalette(
    accent: Color(0xFFF97316),
    accentLight: Color(0xFFFB923C),
    accentDark: Color(0xFFEA580C),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // PALETTE RESOLUTION — picks the right palette for a given card
  // ═══════════════════════════════════════════════════════════════════════

  /// Resolves a palette from an explicit accent color.
  /// Maps common hex values to their named palette; falls back to building
  /// a custom palette around the provided color.
  static CardColorPalette fromAccentColor(Color color) {
    final v = color.value;

    // Exact matches to standard palettes
    if (v == const Color(0xFF10B981).value || v == const Color(0xFF34D399).value) return groceryFresh;
    if (v == const Color(0xFF3B82F6).value || v == const Color(0xFF60A5FA).value) return groceryPantry;
    if (v == const Color(0xFF8B5CF6).value || v == const Color(0xFFA78BFA).value) return grocerySnacks;
    if (v == const Color(0xFF6366F1).value) return grocerySnacks; // Indigo → Violet family
    if (v == const Color(0xFFF59E0B).value || v == const Color(0xFFFBBF24).value) return groceryDeals;
    if (v == const Color(0xFFEF4444).value || v == const Color(0xFFF87171).value) return foodHot;
    if (v == const Color(0xFFEA580C).value) return foodCuisine;
    if (v == const Color(0xFFB91C1C).value || v == const Color(0xFFDC2626).value) return foodPremium;
    if (v == const Color(0xFFF97316).value || v == const Color(0xFFFB923C).value) return foodCafe;

    // Build a custom palette from the arbitrary color
    final hsl = HSLColor.fromColor(color);
    return CardColorPalette(
      accent: color,
      accentLight: hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor(),
      accentDark: hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Resolves a palette from card content keywords (title, category name).
  /// Used as fallback when no explicit ctaBgColor is provided.
  static CardColorPalette fromKeywords(String title, String? categoryName) {
    final text = '${title.toLowerCase()} ${(categoryName ?? '').toLowerCase()}';

    // Grocery signals
    if (_matchesAny(text, ['green', 'veg', 'organic', 'farm', 'fresh', 'fruit', 'harvest'])) {
      return groceryFresh;
    }
    if (_matchesAny(text, ['milk', 'dairy', 'egg', 'bread', 'atta', 'pantry', 'staple', 'essential'])) {
      return groceryPantry;
    }
    if (_matchesAny(text, ['snack', 'sweet', 'chocolate', 'dessert', 'ice cream', 'candy', 'munchie', 'lays', 'cadbury'])) {
      return grocerySnacks;
    }
    if (_matchesAny(text, ['bogo', 'buy 1', 'flash', 'festive', 'deal', 'sale', 'offer'])) {
      return groceryDeals;
    }

    // Food signals
    if (_matchesAny(text, ['burger', 'pizza', 'hot', 'fries', 'momo', 'roll'])) {
      return foodHot;
    }
    if (_matchesAny(text, ['cuisine', 'biryani', 'bites', 'combo', 'explore'])) {
      return foodCuisine;
    }
    if (_matchesAny(text, ['royal', 'feast', 'thali', 'premium', 'mughalai', 'shahi'])) {
      return foodPremium;
    }
    if (_matchesAny(text, ['shake', 'coffee', 'cafe', 'beverage', 'juice'])) {
      return foodCafe;
    }

    return neutral;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
