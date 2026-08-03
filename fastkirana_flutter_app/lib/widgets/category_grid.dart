import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final Function(String slug)? onCategoryTap;

  const CategoryGrid({
    super.key,
    required this.categories,
    this.onCategoryTap,
  });

  static const Map<String, IconData> categoryIcons = {
    'fruits-vegetables': Icons.eco_outlined,
    'dairy-breakfast': Icons.breakfast_dining_outlined,
    'snacks-munchies': Icons.ramen_dining_outlined,
    'beverages': Icons.local_cafe_outlined,
    'personal-care': Icons.spa_outlined,
    'household': Icons.cleaning_services_outlined,
    'bakery-biscuits': Icons.bakery_dining_outlined,
    'atta-rice-dal': Icons.grain_outlined,
    'ice-cream': Icons.icecream_outlined,
  };

  static const Map<String, Color> categoryColors = {
    'fruits-vegetables': Color(0xFF4ADE80),
    'dairy-breakfast': Color(0xFF60A5FA),
    'snacks-munchies': Color(0xFFFBBF24),
    'beverages': Color(0xFFF97316),
    'personal-care': Color(0xFFC084FC),
    'household': Color(0xFF94A3B8),
    'bakery-biscuits': Color(0xFFF59E0B),
    'atta-rice-dal': Color(0xFFA78BFA),
    'ice-cream': Color(0xFF22D3EE),
  };

  @override
  Widget build(BuildContext context) {
    final displayCategories = categories.length > 8 ? categories.sublist(0, 8) : categories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.78,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final category = displayCategories[index];
          final icon = categoryIcons[category.slug] ?? Icons.category_outlined;
          final color = categoryColors[category.slug] ?? AppTheme.primary;

          return _CategoryCard(
            category: category,
            icon: icon,
            color: color,
            onTap: onCategoryTap != null
                ? () => onCategoryTap!(category.slug)
                : null,
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.category,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.border.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
