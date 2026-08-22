import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Manage Inventory', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppDesignSystem.primary),
            onPressed: () => ref.refresh(productsProvider(null)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.textMuted),
                  hintText: 'Search 190+ live products...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                var list = products;
                if (_searchQuery.isNotEmpty) {
                  list = list.where((p) =>
                    p.name.toLowerCase().contains(_searchQuery) ||
                    (p.category?.name ?? '').toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Text('No products found', style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textMuted)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    final isLowStock = p.stock <= (p.minStock > 0 ? p.minStock : 5);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isLowStock ? AppDesignSystem.warning.withOpacity(0.5) : AppDesignSystem.borderLight),
                        boxShadow: AppDesignSystem.shadowSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppDesignSystem.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: (p.imageUrl != null && p.imageUrl!.startsWith('http'))
                                  ? CachedNetworkImage(
                                      imageUrl: p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.shopping_bag_outlined, size: 24)),
                                    )
                                  : const Center(child: Icon(Icons.shopping_bag_outlined, size: 24)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('₹${p.price.toInt()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                                    if (p.mrp > p.price) ...[
                                      const SizedBox(width: 6),
                                      Text('₹${p.mrp.toInt()}', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textMuted, decoration: TextDecoration.lineThrough)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLowStock ? AppDesignSystem.warning.withOpacity(0.12) : AppDesignSystem.success.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Stock: ${p.stock} (${p.unit})',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isLowStock ? AppDesignSystem.warning : AppDesignSystem.success,
                                        ),
                                      ),
                                    ),
                                    if (p.category != null) ...[
                                      const SizedBox(width: 6),
                                      Text('· ${p.category!.name}', style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.textMuted)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: p.isAvailable && p.stock > 0,
                            activeColor: AppDesignSystem.success,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
              error: (err, _) => Center(child: Text('Error loading products: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppDesignSystem.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Product', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}