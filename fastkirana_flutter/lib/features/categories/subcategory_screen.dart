import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/category.dart';
import '../../providers/category_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.category.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final allCats = categoriesAsync.valueOrNull ?? [];
    final dbSubcats = allCats.where((c) =>
      c.parentId != null && c.parentId!.isNotEmpty &&
      (c.parentId == widget.category.id || c.parentId == widget.category.slug)
    ).toList();

    final List<String> subcategories = [
      'All Items',
      ...dbSubcats.map((c) => c.name),
    ];

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
          // Subcategory Filter Pills (only if DB child subcategories exist)
          if (subcategories.length > 1)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: subcategories.length,
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
                        subcategories[index],
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
                var list = products;
                if (_selectedSubIdx > 0 && _selectedSubIdx < subcategories.length && dbSubcats.isNotEmpty) {
                  final target = dbSubcats[_selectedSubIdx - 1];
                  list = list.where((p) =>
                    p.categoryId == target.id ||
                    p.category?.id == target.id ||
                    p.category?.parentId == target.id ||
                    p.category?.name.toLowerCase() == target.name.toLowerCase()
                  ).toList();
                }
                if (list.isEmpty) {
                  return Center(
                    child: Text('No items in this subcategory', style: GoogleFonts.inter(color: AppDesignSystem.textSecondary)),
                  );
                }
                return GridView.builder(
                  padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5),
                    childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
                    crossAxisSpacing: Responsive.horizontalPadding(context) * 0.5,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) => ProductCard(product: list[index]),
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
