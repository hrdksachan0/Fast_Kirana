import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/category.dart';
import '../../../widgets/shimmer_box.dart';

/// Modular Category Bento Grid & Horizontal Icon Strip for FastKirana Home
class CategoryBentoGrid extends StatelessWidget {
  final List<Category> categories;
  final bool isCafeMode;
  final Function(Category category) onCategoryTap;
  final Map<String, String> categoryAssetMap;

  const CategoryBentoGrid({
    super.key,
    required this.categories,
    required this.isCafeMode,
    required this.onCategoryTap,
    required this.categoryAssetMap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCafeMode ? 'Explore Cafe Cuisines' : 'Explore Categories',
                  style: AppDesignSystem.h3.copyWith(
                    color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${categories.length} items',
                  style: AppDesignSystem.caption.copyWith(
                    color: AppDesignSystem.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 4-Column Bento Category Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final localAsset = categoryAssetMap[cat.slug] ?? categoryAssetMap[cat.name.toLowerCase().replaceAll(' ', '-')];

              return Bounceable(
                onTap: () => onCategoryTap(cat),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 68,
                      width: 68,
                      decoration: BoxDecoration(
                        color: isDark ? AppDesignSystem.darkSurfaceMuted : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate100,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: localAsset != null
                          ? Image.asset(
                              localAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildNetworkFallback(cat.imageUrl),
                            )
                          : _buildNetworkFallback(cat.imageUrl),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.captionBold.copyWith(
                        color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate800,
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkFallback(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const ShimmerBox(width: 40, height: 40),
        errorWidget: (_, __, ___) => const Icon(
          Icons.fastfood_rounded,
          color: AppDesignSystem.slate400,
          size: 28,
        ),
      );
    }
    return const Icon(
      Icons.shopping_basket_rounded,
      color: AppDesignSystem.primaryLight,
      size: 28,
    );
  }
}
