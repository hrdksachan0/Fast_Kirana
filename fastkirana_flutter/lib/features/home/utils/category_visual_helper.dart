import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/category.dart';

class CategoryVisualHelper {
  CategoryVisualHelper._();

  static List<Color> getGradientColors(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)];
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const [Color(0xFFFEFCE8), Color(0xFFFEF08A)];
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || s.contains('ration') || n.contains('dal') || n.contains('ration') || n.contains('kitchen')) {
      return const [Color(0xFFFFFBEB), Color(0xFFFDE68A)];
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch') || s.contains('namkeen') || n.contains('namkeen') || n.contains('cookie')) {
      return const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)];
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink') || s.contains('cold') || n.contains('drink')) {
      return const [Color(0xFFF0F9FF), Color(0xFFBAE6FD)];
    }
    if (s.contains('ice-cream') || n.contains('ice cream') || s.contains('dessert')) {
      return const [Color(0xFFFDF2F8), Color(0xFFFCE7F3)];
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet') || n.contains('cake')) {
      return const [Color(0xFFFAF5FF), Color(0xFFE9D5FF)];
    }
    if (s.contains('dry-fruit') || s.contains('super') || n.contains('dry fruit') || n.contains('nut')) {
      return const [Color(0xFFFAF5FF), Color(0xFFEDE9FE)];
    }
    if (s.contains('packaged') || n.contains('packaged')) {
      return const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)];
    }
    if (s.contains('bakery') || n.contains('bakery') || s.contains('biscuit')) {
      return const [Color(0xFFFEFCE8), Color(0xFFFEF08A)];
    }
    if (s.contains('care') || s.contains('personal') || n.contains('care')) {
      return const [Color(0xFFFDF4FF), Color(0xFFFAE8FF)];
    }
    if (s.contains('clean') || s.contains('home') || s.contains('household') || n.contains('clean')) {
      return const [Color(0xFFF0FDFA), Color(0xFFCCFBF1)];
    }
    return const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)];
  }

  static Color getAccentColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFF22C55E);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFEAB308);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || s.contains('ration') || n.contains('dal') || n.contains('ration') || n.contains('kitchen')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch') || s.contains('namkeen') || n.contains('namkeen') || n.contains('cookie')) {
      return const Color(0xFFF97316);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink') || s.contains('cold') || n.contains('drink')) {
      return const Color(0xFF0EA5E9);
    }
    if (s.contains('ice-cream') || n.contains('ice cream') || s.contains('dessert')) {
      return const Color(0xFFEC4899);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet') || n.contains('cake')) {
      return const Color(0xFFA855F7);
    }
    if (s.contains('dry-fruit') || s.contains('super') || n.contains('dry fruit') || n.contains('nut')) {
      return const Color(0xFF8B5CF6);
    }
    if (s.contains('packaged') || n.contains('packaged')) {
      return const Color(0xFFF43F5E);
    }
    if (s.contains('care') || s.contains('personal') || n.contains('care')) {
      return const Color(0xFFD946EF);
    }
    if (s.contains('clean') || s.contains('home') || s.contains('household') || n.contains('clean')) {
      return const Color(0xFF0D9488);
    }
    return const Color(0xFF64748B);
  }

  static Color getSoftColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('dry-fruit') || s.contains('super') || n.contains('dry fruit') || n.contains('nut')) {
      return const Color(0xFFFAF5FF);
    }
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFF0FDF4);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFFFBEB);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || s.contains('ration') || n.contains('dal') || n.contains('ration') || n.contains('kitchen')) {
      return const Color(0xFFFEF3C7);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch') || s.contains('namkeen') || n.contains('namkeen') || n.contains('cookie')) {
      return const Color(0xFFFFF7ED);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink') || s.contains('cold') || n.contains('drink')) {
      return const Color(0xFFEFF6FF);
    }
    if (s.contains('ice-cream') || n.contains('ice cream') || s.contains('dessert')) {
      return const Color(0xFFFDF2F8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet') || n.contains('cake')) {
      return const Color(0xFFFAF5FF);
    }
    if (s.contains('packaged') || n.contains('packaged') || n.contains('instant')) {
      return const Color(0xFFFFF1F2);
    }
    if (s.contains('bakery') || n.contains('bakery') || s.contains('biscuit')) {
      return const Color(0xFFFEFCE8);
    }
    if (s.contains('care') || s.contains('personal') || n.contains('care') || n.contains('hygiene') || n.contains('oral') || n.contains('hair')) {
      return const Color(0xFFFDF4FF);
    }
    if (s.contains('clean') || s.contains('home') || s.contains('household') || n.contains('clean') || n.contains('laundry')) {
      return const Color(0xFFF0FDFA);
    }
    return const Color(0xFFF8FAFC);
  }

  static Color getBorderColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('dry-fruit') || s.contains('super') || n.contains('dry fruit') || n.contains('nut')) {
      return const Color(0xFFEDE9FE);
    }
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFDCFCE7);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || s.contains('ration') || n.contains('dal') || n.contains('ration') || n.contains('kitchen')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch') || s.contains('namkeen') || n.contains('namkeen') || n.contains('cookie')) {
      return const Color(0xFFFED7AA);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink') || s.contains('cold') || n.contains('drink')) {
      return const Color(0xFFBFDBFE);
    }
    if (s.contains('ice-cream') || n.contains('ice cream') || s.contains('dessert')) {
      return const Color(0xFFFBCFE8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet') || n.contains('cake')) {
      return const Color(0xFFE9D5FF);
    }
    if (s.contains('packaged') || n.contains('packaged') || n.contains('instant')) {
      return const Color(0xFFFFE4E6);
    }
    if (s.contains('care') || s.contains('personal') || n.contains('care') || n.contains('hygiene') || n.contains('oral') || n.contains('hair')) {
      return const Color(0xFFFAE8FF);
    }
    if (s.contains('clean') || s.contains('home') || s.contains('household') || n.contains('clean') || n.contains('laundry')) {
      return const Color(0xFFCCFBF1);
    }
    return const Color(0xFFE2E8F0);
  }

  /// Resolves authentic, high-definition photographic packshot images from Supabase
  /// storage and eliminates all cartoon / illustration placeholders.
  static String resolveRealisticImageUrl(Category cat) {
    final rawUrl = (cat.imageUrl ?? '').trim();

    // 1. If it's already an authentic Supabase storage photographic URL, use it directly!
    if (rawUrl.contains('supabase.co') && !rawUrl.endsWith('.svg')) {
      return rawUrl;
    }

    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();
    final id = cat.id.toUpperCase().trim();

    // 2. High-definition realistic transparent 512x512 quick-commerce packshots from Supabase
    // Fresh Produce (Fruits & Vegetables cluster)
    if (id == 'CAT-101' || slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('vegetable')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_fruits_vegetables.webp';
    }

    // Chilled Beverages & Cold Drinks (Coke, Real juice, Sprite cluster)
    if (id == 'CAT-108' || slug.contains('beverage') || slug.contains('drink') || name.contains('beverage') || name.contains('drink')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_beverages_drinks.webp';
    }

    // Ice Cream & Desserts (Cornetto cone, vanilla tub, kulfi stick)
    if (id == 'CAT-105' || slug.contains('ice-cream') || name.contains('ice cream') || name.contains('dessert')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_ice_cream_desserts.webp';
    }

    // Dairy Products (Milk pouch, butter, paneer, dahi)
    if (id == 'CAT-116' || slug.contains('dairy') || slug.contains('milk') || name.contains('dairy') || name.contains('milk')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_dairy_products.webp';
    }

    // Cooking Staples & Kitchen Ration
    if (id == 'CAT-113' || slug.contains('kitchen') || slug.contains('ration')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_kitchen_ration.webp';
    }

    // Dry Fruits & Superfoods
    if (id.contains('114') || slug.contains('dry-fruit') || name.contains('dry fruit') || name.contains('nut')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_dry_fruits_super_foods.webp';
    }

    // Biscuits, Cookies & Namkeen
    if (id == 'CAT-102' || slug.contains('cookie') || slug.contains('biscuit') || slug.contains('namkeen') || name.contains('cookie') || name.contains('namkeen')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_cookies_namkeen.webp';
    }

    // Chocolates & Cakes
    if (id == 'CAT-115' || slug.contains('choco') || name.contains('choco') || slug.contains('cake') || name.contains('cake')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_cakes_chocolates.webp';
    }

    // Sauces & Instant Foods / Packaged Items
    if (id == 'CAT-104' || slug.contains('package') || slug.contains('instant') || slug.contains('breakfast')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_packaged_items.webp';
    }

    // Household & Cleaning Essentials
    if (id == 'CAT-107' || slug.contains('house') || slug.contains('clean') || slug.contains('laundry') || slug.contains('dish')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_household_essentials.webp';
    }

    // Personal Care & Hygiene
    if (id == 'CAT-109' || slug.contains('care') || slug.contains('personal') || slug.contains('oral') || slug.contains('hair')) {
      return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/cat_personal_care_hygiene.webp';
    }

    // If already valid http URL and not cartoon
    if (rawUrl.startsWith('http') && !rawUrl.contains('_category.webp') && !rawUrl.contains('_category.png')) {
      return rawUrl;
    }

    // Default fallback
    return 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789047720250-xu6kpy.webp';
  }

  /// Dynamically computes a crisp, appetizing subtitle/tagline for any category.
  static String getDynamicTagline(Category cat) {
    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();
    final id = cat.id.toUpperCase().trim();

    if (id == 'CAT-101' || slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('veg')) {
      return '100% Farm-Fresh Daily';
    }
    if (id == 'CAT-116' || slug.contains('dairy') || slug.contains('milk') || name.contains('dairy') || name.contains('milk')) {
      return 'Milk, Bread, Paneer & Butter';
    }
    if (id == 'SUB-113-01' || slug.contains('atta') || slug.contains('rice')) {
      return 'Fresh Atta, Rice & Grains';
    }
    if (id == 'SUB-113-02' || slug.contains('oil') || slug.contains('ghee')) {
      return 'Fortune Oil & Pure Desi Ghee';
    }
    if (id == 'SUB-113-03' || slug.contains('dal') || slug.contains('pulse')) {
      return 'Unpolished Dals & Pulses';
    }
    if (id == 'SUB-113-04' || slug.contains('spice') || slug.contains('masala')) {
      return 'Catch, MDH & Pure Spices';
    }
    if (id == 'SUB-113-05' || slug.contains('tea') || slug.contains('coffee')) {
      return 'Tata Tea Gold, Chai & Salt';
    }
    if (id == 'CAT-113' || slug.contains('kitchen') || slug.contains('ration')) {
      return 'Fortune Oil, Atta & Dal';
    }
    if (id.contains('114') || slug.contains('dry-fruit')) {
      return 'Almonds, Cashews & Walnuts';
    }
    if (id == 'CAT-108' || slug.contains('beverage') || slug.contains('drink')) {
      return 'Cold Drinks & Real Juices';
    }
    if (id == 'CAT-105' || slug.contains('ice-cream')) {
      return 'Cool Tubs, Cones & Treats';
    }
    if (slug.contains('choco') || id == 'CAT-115' || slug.contains('sweet')) {
      return 'Cadbury Silk & Chocolates';
    }
    if (slug.contains('cookie') || slug.contains('biscuit') || slug.contains('namkeen')) {
      return 'Crispy Rusks, Biscuits & Bhujia';
    }
    if (id == 'CAT-104' || slug.contains('package') || slug.contains('instant')) {
      return 'Instant Maggi & Spreads';
    }
    if (slug.contains('laundry') || slug.contains('dish')) {
      return 'Surf Excel, Vim & Detergents';
    }
    if (id == 'CAT-107' || slug.contains('house') || slug.contains('clean')) {
      return 'Detergents & Home Cleaners';
    }
    if (id == 'CAT-109' || slug.contains('care') || slug.contains('personal')) {
      return 'Soaps, Shampoos & Care';
    }

    final count = cat.productCount;
    if (count != null && count > 0) {
      return '$count+ Items in Stock';
    }
    return '100% Quality Checked';
  }

  /// Dynamically computes theme brand color for category cards and action buttons.
  static Color getDynamicButtonColor(Category cat) {
    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();

    if (slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('veg')) {
      return AppDesignSystem.emerald600;
    }
    if (slug.contains('dairy') || slug.contains('milk') || name.contains('dairy') || name.contains('milk')) {
      return const Color(0xFFD97706); // Warm Amber
    }
    if (slug.contains('atta') || slug.contains('rice') || slug.contains('ration') || slug.contains('kitchen')) {
      return AppDesignSystem.emerald600;
    }
    if (slug.contains('beverage') || slug.contains('drink')) {
      return AppDesignSystem.cyan600;
    }
    if (slug.contains('ice-cream') || name.contains('ice cream')) {
      return const Color(0xFFE11D48); // Rose
    }
    if (slug.contains('choco') || slug.contains('cake') || slug.contains('sweet')) {
      return AppDesignSystem.violet600;
    }
    if (slug.contains('care') || slug.contains('oral') || slug.contains('hair')) {
      return AppDesignSystem.teal600;
    }
    if (slug.contains('clean') || slug.contains('laundry') || slug.contains('dish')) {
      return const Color(0xFF2563EB); // Royal Blue
    }
    if (slug.contains('snack') || slug.contains('namkeen') || slug.contains('cookie')) {
      return AppDesignSystem.orange600;
    }
    return AppDesignSystem.primary;
  }

  static Widget buildAvatarImage(BuildContext context, Category cat, {BoxFit fit = BoxFit.contain}) {
    final imgUrl = resolveRealisticImageUrl(cat);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imgUrl,
        fit: fit,
        memCacheWidth: 400,
        memCacheHeight: 400,
        maxWidthDiskCache: 600,
        maxHeightDiskCache: 600,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => buildFallback(context, cat),
      ),
    );
  }

  static Widget buildFallback(BuildContext context, Category cat) {
    return Container(
      color: AppDesignSystem.surfaceMuted,
      child: Center(
        child: Text(
          cat.name.isNotEmpty ? cat.name.characters.first.toUpperCase() : '🛍️',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 22),
            fontWeight: FontWeight.w900,
            color: AppDesignSystem.primary,
          ),
        ),
      ),
    );
  }
}
