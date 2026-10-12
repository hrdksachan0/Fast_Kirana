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
    String imgUrl = (cat.imageUrl ?? '').trim();
    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();

    // 1. Resolve relative URLs from FastKirana CDN
    if (imgUrl.isNotEmpty && imgUrl.startsWith('/')) {
      final cleanPath = imgUrl.replaceAll('.png', '.webp');
      imgUrl = 'https://www.fastkirana.in$cleanPath';
    }

    // 2. Curated high-res CDN visuals for top heroes if relative or missing
    if (slug.contains('ice') || slug.contains('dessert') || name.contains('ice cream')) {
      imgUrl = 'https://www.fastkirana.in/ice_cream_category.webp';
    } else if (slug == 'beverages' || slug == 'cold-drinks' || (slug.contains('beverage') && !imgUrl.startsWith('http'))) {
      imgUrl = 'https://www.fastkirana.in/beverages_category.webp';
    } else if ((slug == 'fruits-vegetables' || cat.id == 'CAT-101') && (imgUrl.isEmpty || !imgUrl.startsWith('http'))) {
      imgUrl = 'https://www.fastkirana.in/fruits_vegetables_category.webp';
    }

    // 3. Load from Network (real Supabase or CDN image)
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

    return buildFallback(context, cat);
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
