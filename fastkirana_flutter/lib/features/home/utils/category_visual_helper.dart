import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/category.dart';

class CategoryVisualHelper {
  CategoryVisualHelper._();

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

  static Widget buildAvatarImage(BuildContext context, Category cat) {
    final imgUrl = cat.imageUrl ?? '';

    // 1. If real Cloudinary / HTTP URL from Supabase is present, use it directly!
    if (imgUrl.isNotEmpty && imgUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => buildFallback(context, cat),
      );
    }

    // 2. If relative URL from Supabase (e.g. /fruits_vegetables_category.png), load from live domain
    if (imgUrl.isNotEmpty && imgUrl.startsWith('/')) {
      return CachedNetworkImage(
        imageUrl: 'https://www.fastkirana.in$imgUrl',
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => buildFallback(context, cat),
      );
    }

    // 3. Match CDN banner image by slug or keyword
    final slug = cat.slug.toLowerCase().trim();
    final name = cat.name.toLowerCase().trim();

    String? webCdnUrl;
    String fallbackAsset = 'assets/categories/fruits_vegetables_category.webp';

    if (slug == 'fruits-vegetables' || slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('veg')) {
      webCdnUrl = 'https://www.fastkirana.in/fruits-vegetables.png';
      fallbackAsset = 'assets/categories/fruits_vegetables_category.webp';
    } else if (slug.contains('dry-fruit') || slug.contains('super') || name.contains('dry fruit') || name.contains('nuts')) {
      webCdnUrl = 'https://www.fastkirana.in/healthy-foods.png';
      fallbackAsset = 'assets/categories/fruits_vegetables_category.webp';
    } else if (slug == 'dairy-breakfast' || slug.contains('dairy') || slug.contains('milk') || name.contains('milk') || name.contains('dairy')) {
      webCdnUrl = 'https://www.fastkirana.in/dairy-bread-eggs.png';
      fallbackAsset = 'assets/categories/dairy_breakfast_category.webp';
    } else if (slug == 'snacks-munchies' || slug.contains('snack') || slug.contains('munch') || name.contains('snack') || name.contains('munch')) {
      webCdnUrl = 'https://www.fastkirana.in/snacks-munchies.png';
      fallbackAsset = 'assets/categories/snacks_munchies_category.webp';
    } else if (slug == 'beverages' || slug.contains('drink') || slug.contains('cold') || name.contains('beverage') || name.contains('drink')) {
      webCdnUrl = 'https://www.fastkirana.in/beverages.png';
      fallbackAsset = 'assets/categories/beverages_category.webp';
    } else if (slug == 'ice-cream' || slug.contains('ice') || slug.contains('dessert') || name.contains('ice cream')) {
      webCdnUrl = 'https://www.fastkirana.in/ice-cream.png';
      fallbackAsset = 'assets/categories/ice_cream_category.webp';
    } else if (slug == 'atta-rice-dal' || slug.contains('atta') || slug.contains('rice') || slug.contains('kitchen') || slug.contains('ration') || name.contains('kitchen') || name.contains('ration')) {
      webCdnUrl = 'https://www.fastkirana.in/kitchen-needs.png';
      fallbackAsset = 'assets/categories/atta_rice_dal_category.webp';
    } else if (slug.contains('packaged') || name.contains('packaged')) {
      webCdnUrl = 'https://www.fastkirana.in/packaged-foods.png';
      fallbackAsset = 'assets/categories/snacks_munchies_category.webp';
    } else if (slug == 'personal-care' || slug.contains('care') || slug.contains('hygiene') || name.contains('personal care')) {
      webCdnUrl = 'https://www.fastkirana.in/personal-care.png';
      fallbackAsset = 'assets/categories/personal_care_category.webp';
    } else if (slug == 'home-needs-and-cleaning' || slug == 'household' || slug.contains('clean') || slug.contains('home') || name.contains('cleaning') || name.contains('home needs')) {
      webCdnUrl = 'https://www.fastkirana.in/home-cleaning.png';
      fallbackAsset = 'assets/categories/household_category.webp';
    } else if (slug == 'bakery' || slug.contains('biscuit') || name.contains('bakery')) {
      webCdnUrl = 'https://www.fastkirana.in/bakery.png';
      fallbackAsset = 'assets/categories/bakery_biscuits_category.webp';
    } else if (slug == 'restaurant-food' || slug.contains('cafe') || slug.contains('food')) {
      webCdnUrl = 'https://www.fastkirana.in/restaurant-food.png';
      fallbackAsset = 'assets/categories/cafe_category.webp';
    }

    if (webCdnUrl != null) {
      return CachedNetworkImage(
        imageUrl: webCdnUrl,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (_, __) => Image.asset(fallbackAsset, fit: BoxFit.cover),
        errorWidget: (_, __, ___) => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildFallback(context, cat),
        ),
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
