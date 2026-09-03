import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';

class SubcategoryScreen extends ConsumerStatefulWidget {
  final Category category;
  const SubcategoryScreen({super.key, required this.category});

  @override
  ConsumerState<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends ConsumerState<SubcategoryScreen> {
  int _selectedSubIdx = 0;

  final List<String> _subcategories = const [
    'All Items',
    'Fresh Milk',
    'Curd & Paneer',
    'Butter & Cheese',
    'Bread & Eggs',
    'Lassi & Shakes',
  ];

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.category.id));

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          widget.category.name,
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Subcategory Filter Pills
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _subcategories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedSubIdx == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSubIdx = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppDesignSystem.primary : AppDesignSystem.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppDesignSystem.primary : AppDesignSystem.borderLight),
                      boxShadow: isSelected ? AppDesignSystem.shadowGlow : AppDesignSystem.shadowSm,
                    ),
                    child: Text(
                      _subcategories[index],
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppDesignSystem.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Text('No items in this subcategory', style: GoogleFonts.inter(color: AppDesignSystem.textSecondary)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => ProductCard(product: products[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger))),
            ),
          ),
        ],
      ),
    );
  }
}
