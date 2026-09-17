import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../categories/category_products_screen.dart';

class HomeHeroBanner extends ConsumerWidget {
  const HomeHeroBanner({super.key});

  static const Map<String, dynamic> heroPromoBanner = {
    'type': 'fast-delivery',
    'tag': '⚡ FAST DELIVERY',
    'title': 'Ghatampur Darkstore',
    'subtitle': 'Farm-Fresh Veggies, Milk, Snacks & Daily Staples',
    'cta': 'Order Now →',
    'bgColor': Color(0xFFFFF7ED),
    'textColor': AppDesignSystem.primary,
    'imageAsset': 'assets/categories/fruits_vegetables_category.webp',
    'webFallback': 'https://www.fastkirana.in/grocery_bag_banner.png',
    'categorySlug': 'fruits-vegetables',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const slide = heroPromoBanner;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final slug = slide['categorySlug'] as String;
            final categoriesAsync = ref.read(categoriesProvider);
            final cat = categoriesAsync.valueOrNull?.firstWhere(
              (c) => c.slug == slug || c.id == slug,
              orElse: () => Category.fromJson({'id': slug, 'name': 'Vegetables & Fruits', 'slug': slug}),
            );
            if (cat != null) {
              Navigator.push(
                context,
                FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1F2), Color(0xFFFFFBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE20A22).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    // Left Content Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ⚡ Fast Delivery Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE20A22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFFDE047)),
                                const SizedBox(width: 3),
                                Text(
                                  'FAST DELIVERY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Ghatampur Darkstore',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: context.isCompact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Farm-Fresh Veggies, Milk, Snacks & Daily Staples',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // CTA Pill Button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE20A22), Color(0xFFBE123C)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ORDER NOW',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Visual Showcase
                    SizedBox(
                      width: context.isCompact ? 78 : 96,
                      height: context.isCompact ? 78 : 96,
                      child: CachedNetworkImage(
                        imageUrl: slide['webFallback'] as String,
                        fit: BoxFit.contain,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        placeholder: (_, __) => Image.asset(
                          slide['imageAsset'] as String,
                          fit: BoxFit.contain,
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          slide['imageAsset'] as String,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
