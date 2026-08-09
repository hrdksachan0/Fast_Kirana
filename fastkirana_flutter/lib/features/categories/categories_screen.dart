import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const List<Map<String, String>> fallbackCategories = [
    {'id': 'cat_veg', 'name': 'Vegetables & Fruits', 'slug': 'fruits-vegetables', 'icon': '🥬'},
    {'id': 'cat_dairy', 'name': 'Dairy & Breakfast', 'slug': 'dairy-breakfast', 'icon': '🥛'},
    {'id': 'cat_instant', 'name': 'Instant Food & Noodles', 'slug': 'instant-food', 'icon': '🍜'},
    {'id': 'cat_bev', 'name': 'Beverages & Drinks', 'slug': 'beverages', 'icon': '🥤'},
    {'id': 'cat_snacks', 'name': 'Snacks & Munchies', 'slug': 'snacks-munchies', 'icon': '🍿'},
    {'id': 'cat_bakery', 'name': 'Bakery & Biscuits', 'slug': 'bakery-biscuits', 'icon': '🍞'},
    {'id': 'cat_atta', 'name': 'Atta, Rice & Dal', 'slug': 'atta-rice-dal', 'icon': '🌾'},
    {'id': 'cat_personal', 'name': 'Personal Care', 'slug': 'personal-care', 'icon': '🧴'},
    {'id': 'cat_house', 'name': 'Household Needs', 'slug': 'household', 'icon': '🧹'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB50017),
        elevation: 0,
        title: Text(
          'Categories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => _buildCategoriesGrid(context, categories),
        loading: () => _buildFallbackGrid(context),
        error: (_, __) => _buildFallbackGrid(context),
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, List<Category> categories) {
    if (categories.isEmpty) {
      return _buildFallbackGrid(context);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryProductsScreen(category: category),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF4E7E8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('🛒', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C0D0F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore Items →',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFB50017),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: fallbackCategories.length,
      itemBuilder: (context, index) {
        final cat = fallbackCategories[index];
        final mockCat = Category(
          id: cat['id']!,
          name: cat['name']!,
          slug: cat['slug']!,
          imageUrl: '',
          sortOrder: index,
          createdAt: DateTime.now(),
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryProductsScreen(category: mockCat),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF4E7E8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(cat['icon']!, style: const TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cat['name']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C0D0F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore Items →',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFB50017),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}