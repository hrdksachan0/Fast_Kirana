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
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFF0FDF4);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFFFBEB);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || n.contains('dal')) {
      return const Color(0xFFFEF3C7);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch')) {
      return const Color(0xFFFFF7ED);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink')) {
      return const Color(0xFFEFF6FF);
    }
    if (s.contains('ice-cream') || n.contains('ice cream')) {
      return const Color(0xFFFDF2F8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet')) {
      return const Color(0xFFFAF5FF);
    }
    if (s.contains('bakery') || n.contains('bakery') || s.contains('biscuit')) {
      return const Color(0xFFFFFBEB);
    }
    return const Color(0xFFF8FAFC);
  }

  static Color getBorderColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFDCFCE7);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || n.contains('dal')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch')) {
      return const Color(0xFFFED7AA);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink')) {
      return const Color(0xFFBFDBFE);
    }
    if (s.contains('ice-cream') || n.contains('ice cream')) {
      return const Color(0xFFFBCFE8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet')) {
      return const Color(0xFFE9D5FF);
    }
    return const Color(0xFFE2E8F0);
  }

  static Widget buildAvatarImage(BuildContext context, Category cat, {BoxFit fit = BoxFit.contain}) {
    final imgUrl = cat.imageUrl ?? '';
    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();

    // ── 1. CURATED CDN IMAGE OVERRIDE (slug/name matching) ──
    // Always prefer curated images over raw backend URLs to prevent mismatched images.
    final curatedUrl = _getCuratedImageUrl(slug, name);
    if (curatedUrl != null) {
      return CachedNetworkImage(
        imageUrl: curatedUrl,
        fit: fit,
        memCacheWidth: 320,
        memCacheHeight: 320,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) {
          // If CDN fails, try backend URL as fallback
          if (imgUrl.isNotEmpty && imgUrl.startsWith('http')) {
            return CachedNetworkImage(
              imageUrl: imgUrl,
              fit: fit,
              memCacheWidth: 320,
              memCacheHeight: 320,
              errorWidget: (_, __, ___) => buildFallback(context, cat),
            );
          }
          return buildFallback(context, cat);
        },
      );
    }

    // ── 2. Backend HTTP URL (only for uncurated categories) ──
    if (imgUrl.isNotEmpty && imgUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: fit,
        memCacheWidth: 320,
        memCacheHeight: 320,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => buildFallback(context, cat),
      );
    }

    // ── 3. Relative URL from Supabase ──
    if (imgUrl.isNotEmpty && imgUrl.startsWith('/')) {
      return CachedNetworkImage(
        imageUrl: 'https://www.fastkirana.in$imgUrl',
        fit: fit,
        memCacheWidth: 320,
        memCacheHeight: 320,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => buildFallback(context, cat),
      );
    }

    return buildFallback(context, cat);
  }

  /// Returns a curated CDN image URL for known category slugs/names.
  /// Returns null if no curated image is available.
  static String? _getCuratedImageUrl(String slug, String name) {
    const cdn = 'https://www.fastkirana.in';

    // Fruits & Vegetables
    if (slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('veg') || name.contains('sabzi')) {
      return '$cdn/fruits_vegetables_category.webp';
    }
    // Dairy, Bread & Eggs
    if (slug.contains('dairy') || slug.contains('milk') || slug.contains('egg') || name.contains('dairy') || name.contains('milk') || name.contains('paneer') || name.contains('curd')) {
      return '$cdn/dairy_breakfast_category.webp';
    }
    // Atta, Rice & Dals
    if (slug.contains('atta') || slug.contains('rice') || slug.contains('dal') || slug.contains('ration') || slug.contains('flour') || slug.contains('grain') || name.contains('atta') || name.contains('ration')) {
      return '$cdn/atta_rice_dal_category.webp';
    }
    // Oils & Ghee — use atta_rice_dal as closest match (cooking essentials)
    if (slug.contains('oil') || slug.contains('ghee') || name.contains('oil') || name.contains('ghee')) {
      return '$cdn/atta_rice_dal_category.webp';
    }
    // Masala & Spices — use atta_rice_dal (kitchen staples)
    if (slug.contains('masala') || slug.contains('spice') || name.contains('masala') || name.contains('spice')) {
      return '$cdn/atta_rice_dal_category.webp';
    }
    // Dry Fruits & Nuts
    if (slug.contains('dry-fruit') || slug.contains('dry fruit') || slug.contains('nuts') || slug.contains('super') || name.contains('dry fruit') || name.contains('nuts')) {
      return '$cdn/fruits_vegetables_category.webp';
    }
    // Sauces & Spreads — use snacks_munchies as closest
    if (slug.contains('sauce') || slug.contains('spread') || slug.contains('ketchup') || slug.contains('jam') || name.contains('sauce') || name.contains('spread')) {
      return '$cdn/snacks_munchies_category.webp';
    }
    // Packaged Food
    if (slug.contains('packaged') || slug.contains('instant') || slug.contains('maggi') || slug.contains('noodle') || name.contains('packaged') || name.contains('instant')) {
      return '$cdn/snacks_munchies_category.webp';
    }
    // Breakfast Cereals
    if (slug.contains('breakfast') || slug.contains('cereal') || slug.contains('oats') || name.contains('breakfast') || name.contains('cereal')) {
      return '$cdn/dairy_breakfast_category.webp';
    }
    // Cold Drinks & Juices
    if (slug.contains('beverage') || slug.contains('drink') || slug.contains('cold') || slug.contains('juice') || slug.contains('soda') || name.contains('beverage') || name.contains('drink') || name.contains('juice')) {
      return '$cdn/beverages_category.webp';
    }
    // Ice Creams & Desserts
    if (slug.contains('ice') || slug.contains('dessert') || slug.contains('frozen') || name.contains('ice cream') || name.contains('dessert')) {
      return '$cdn/ice_cream_category.webp';
    }
    // Tea, Coffee
    if (slug.contains('tea') || slug.contains('coffee') || slug.contains('chai') || name.contains('tea') || name.contains('coffee')) {
      return '$cdn/beverages_category.webp';
    }
    // Chocolates & Sweets
    if (slug.contains('choco') || slug.contains('sweet') || slug.contains('candy') || slug.contains('toffee') || slug.contains('cake') || name.contains('choco') || name.contains('sweet') || name.contains('mithai')) {
      return '$cdn/bakery_biscuits_category.webp';
    }
    // Snacks, Munchies, Namkeen, Chips
    if (slug.contains('snack') || slug.contains('munch') || slug.contains('namkeen') || slug.contains('chips') || name.contains('snack') || name.contains('munch') || name.contains('namkeen') || name.contains('chips')) {
      return '$cdn/snacks_munchies_category.webp';
    }
    // Biscuits & Cookies, Bakery
    if (slug.contains('bakery') || slug.contains('biscuit') || slug.contains('cookie') || slug.contains('rusk') || name.contains('bakery') || name.contains('biscuit') || name.contains('cookie')) {
      return '$cdn/bakery_biscuits_category.webp';
    }
    // Personal Care, Skin, Body
    if (slug.contains('personal') || slug.contains('skin') || slug.contains('body') || slug.contains('face') || name.contains('personal care') || name.contains('skin')) {
      return '$cdn/personal_care_category.webp';
    }
    // Hair Care & Cosmetics
    if (slug.contains('hair') || slug.contains('shampoo') || slug.contains('cosmetic') || name.contains('hair') || name.contains('cosmetic')) {
      return '$cdn/personal_care_category.webp';
    }
    // Oral Care & Hygiene
    if (slug.contains('oral') || slug.contains('dental') || slug.contains('tooth') || name.contains('oral') || name.contains('dental') || name.contains('tooth')) {
      return '$cdn/personal_care_category.webp';
    }
    // Household, Cleaning, Home Needs
    if (slug.contains('household') || slug.contains('clean') || slug.contains('home') || slug.contains('mop') || slug.contains('broom') || name.contains('cleaning') || name.contains('household') || name.contains('home need')) {
      return '$cdn/household_category.webp';
    }
    // Laundry
    if (slug.contains('laundry') || slug.contains('detergent') || slug.contains('fabric') || name.contains('laundry') || name.contains('detergent')) {
      return '$cdn/household_category.webp';
    }
    // Dishwashing
    if (slug.contains('dishwash') || slug.contains('dish') || slug.contains('utensil') || name.contains('dishwash')) {
      return '$cdn/household_category.webp';
    }
    // Pest Control
    if (slug.contains('pest') || slug.contains('repellent') || slug.contains('freshener') || name.contains('pest') || name.contains('repellent')) {
      return '$cdn/household_category.webp';
    }
    // Baby Care
    if (slug.contains('baby') || slug.contains('diaper') || slug.contains('infant') || name.contains('baby') || name.contains('diaper')) {
      return '$cdn/personal_care_category.webp';
    }
    // Hygiene, Sanitary
    if (slug.contains('hygiene') || slug.contains('sanitary') || slug.contains('feminine') || name.contains('hygiene') || name.contains('sanitary')) {
      return '$cdn/personal_care_category.webp';
    }
    // Pooja
    if (slug.contains('pooja') || slug.contains('puja') || slug.contains('agarbatti') || name.contains('pooja') || name.contains('puja')) {
      return '$cdn/household_category.webp';
    }
    // Restaurant / Cafe
    if (slug.contains('restaurant') || slug.contains('cafe') || slug.contains('food')) {
      return '$cdn/cafe_category.webp';
    }
    return null;
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
