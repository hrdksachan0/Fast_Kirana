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
    {'id': 'cat_veg', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables', 'icon': '🥬'},
    {'id': 'cat_dairy', 'name': 'Dairy & Breakfast', 'slug': 'dairy-breakfast', 'icon': '🥛'},
    {'id': 'cat_instant', 'name': 'Instant Foods', 'slug': 'instant-food', 'icon': '🍜'},
    {'id': 'cat_bev', 'name': 'Beverages', 'slug': 'beverages', 'icon': '🥤'},
    {'id': 'cat_snacks', 'name': 'Snacks & Munchies', 'slug': 'snacks-munchies', 'icon': '🍿'},
    {'id': 'cat_bakery', 'name': 'Bakery & Biscuits', 'slug': 'bakery-biscuits', 'icon': '🍞'},
    {'id': 'cat_dryfruits', 'name': 'Dry Fruits & Nuts', 'slug': 'dry-fruits', 'icon': '🥜'},
    {'id': 'cat_grocery', 'name': 'Grocery Essentials', 'slug': 'grocery-essentials', 'icon': '🫒'},
    {'id': 'cat_chocos', 'name': 'Chocolates', 'slug': 'chocolates', 'icon': '🍫'},
    {'id': 'cat_personal', 'name': 'Personal Care', 'slug': 'personal-care', 'icon': '🧴'},
    {'id': 'cat_house', 'name': 'Home & Cleaning', 'slug': 'household', 'icon': '🧹'},
    {'id': 'cat_kitchen', 'name': 'Kitchen Needs', 'slug': 'kitchen', 'icon': '🧂'},
  ];

  static const List<Color> categoryColors = [
    Color(0xFFDCFCE7),
    Color(0xFFFFF7ED),
    Color(0xFFFFE4E6),
    Color(0xFFE0F2FE),
    Color(0xFFFFF0F0),
    Color(0xFFFFF7ED),
    Color(0xFFFEF3C7),
    Color(0xFFF0FDF4),
    Color(0xFFFFF0F0),
    Color(0xFFE0F2FE),
    Color(0xFFF0FDF4),
    Color(0xFFFFF7ED),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
        title: Text(
          'Explore Categories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final cats = categories.isEmpty ? _buildFallbackCategories() : categories;
          return _buildCategoriesGrid(context, cats);
        },
        loading: () => _buildFallbackGrid(context),
        error: (_, __) => _buildFallbackGrid(context),
      ),
    );
  }

  List<Category> _buildFallbackCategories() {
    return fallbackCategories.map<Category>((cat) => Category(
      id: cat['id']!,
      name: cat['name']!,
      slug: cat['slug']!,
      imageUrl: '',
      sortOrder: fallbackCategories.indexOf(cat),
    )).toList();
  }

  Widget _buildCategoriesGrid(BuildContext context, List<Category> categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final catIndex = index % fallbackCategories.length;
        final bgColor = categoryColors[catIndex];
        final icon = fallbackCategories[catIndex]['icon'] ?? '🛒';

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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
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
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse →',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppDesignSystem.primary,
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
    final fallback = _buildFallbackCategories();
    return _buildCategoriesGrid(context, fallback);
  }
}
