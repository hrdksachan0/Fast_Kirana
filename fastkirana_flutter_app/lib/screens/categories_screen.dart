import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Fruits & Vegetables', 'icon': '🥬', 'color': Color(0xFFECFDF5)},
      {'name': 'Dairy & Eggs', 'icon': '🥛', 'color': Color(0xFFFEF3C7)},
      {'name': 'Bakery', 'icon': '🍞', 'color': Color(0xFFFFF7ED)},
      {'name': 'Meat & Fish', 'icon': '🥩', 'color': Color(0xFFFEF2F2)},
      {'name': 'Snacks & Munchies', 'icon': '🍿', 'color': Color(0xFFFFF1F2)},
      {'name': 'Beverages', 'icon': '🥤', 'color': Color(0xFFF0F9FF)},
      {'name': 'Personal Care', 'icon': '🧴', 'color': Color(0xFFFDF2F8)},
      {'name': 'Household', 'icon': '🧹', 'color': Color(0xFFF5F3FF)},
      {'name': 'Baby Care', 'icon': '🍼', 'color': Color(0xFFECFEFF)},
      {'name': 'Pet Supplies', 'icon': '🐾', 'color': Color(0xFFFFFDE7)},
      {'name': 'Pharma & Wellness', 'icon': '💊', 'color': Color(0xFFF0FDF4)},
      {'name': 'Stationery', 'icon': '📝', 'color': Color(0xFFFFF8E1)},
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                      size: 22, color: AppTheme.textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search categories',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _CategoryItem(
                    name: cat['name'] as String,
                    emoji: cat['icon'] as String,
                    color: cat['color'] as Color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String name;
  final String emoji;
  final Color color;

  const _CategoryItem({
    required this.name,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
