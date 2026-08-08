import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  final List<Map<String, String>> _categories = const [
    {'name': 'Vegetables', 'emoji': '🥬', 'count': '128', 'color': '#10B981'},
    {'name': 'Fruits', 'emoji': '🍎', 'count': '96', 'color': '#EF4444'},
    {'name': 'Dairy & Eggs', 'emoji': '🥛', 'count': '45', 'color': '#3B82F6'},
    {'name': 'Bakery', 'emoji': '🍞', 'count': '32', 'color': '#FBBC05'},
    {'name': 'Snacks', 'emoji': '🍿', 'count': '67', 'color': '#8B5CF6'},
    {'name': 'Cafe', 'emoji': '☕', 'count': '24', 'color': '#FC8019'},
    {'name': 'Atta & Rice', 'emoji': '🌾', 'count': '38', 'color': '#84CC16'},
    {'name': 'Oils & Ghee', 'emoji': '🫒', 'count': '21', 'color': '#06B6D4'},
    {'name': 'Personal Care', 'emoji': '🧴', 'count': '55', 'color': '#F97316'},
    {'name': 'Cleaning', 'emoji': '🧹', 'count': '28', 'color': '#6366F1'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Categories', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(categoryId: 'cat_$index', categoryName: cat['name']!),
              ));
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Color(int.parse(cat['color']!)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(child: Text(cat['emoji']!, style: const TextStyle(fontSize: 40))),
                  ),
                  const SizedBox(height: 12),
                  Text(cat['name']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${cat['count']} items', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}