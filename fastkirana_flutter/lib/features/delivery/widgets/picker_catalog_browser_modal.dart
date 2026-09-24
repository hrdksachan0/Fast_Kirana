import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import 'edit_picker_product_modal.dart';

class PickerCatalogBrowserModal extends ConsumerStatefulWidget {
  final VoidCallback onProductUpdated;

  const PickerCatalogBrowserModal({
    super.key,
    required this.onProductUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onProductUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PickerCatalogBrowserModal(
        onProductUpdated: onProductUpdated,
      ),
    );
  }

  @override
  ConsumerState<PickerCatalogBrowserModal> createState() => _PickerCatalogBrowserModalState();
}

class _PickerCatalogBrowserModalState extends ConsumerState<PickerCatalogBrowserModal> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  static const Color brandOrange = Color(0xFFEA580C);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fetchProducts('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts(String query) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/api/picker/products',
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
          if (AppConfig.darkstoreId.isNotEmpty) 'storeId': AppConfig.darkstoreId,
          'limit': 60,
        },
        options: Options(
          headers: {'x-user-role': 'PICKER'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List raw = response.data['products'] ?? [];
        if (mounted) {
          setState(() {
            _products = raw.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('[PickerCatalogBrowser] fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditModal(Map<String, dynamic> product) {
    EditPickerProductModal.show(
      context: context,
      product: product,
      onProductUpdated: () {
        _fetchProducts(_searchController.text);
        widget.onProductUpdated();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catalog & Pricing',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                        ),
                      ),
                      Text(
                        'Search dark store items to edit prices & stock',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: slateMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: slateMuted, size: 22),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _fetchProducts(v),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Search product name, barcode, shelf...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: slateMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: slateMuted),
                        onPressed: () {
                          _searchController.clear();
                          _fetchProducts('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: slateBorder),
                ),
              ),
            ),
          ),

          const Divider(height: 12, color: slateBorder),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: brandOrange),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'No grocery products found',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final prod = _products[index];
                          final name = (prod['name'] ?? 'Product').toString();
                          final imgUrl = (prod['imageUrl'] ?? '').toString();
                          final num price = (prod['price'] is num) ? (prod['price'] as num) : 0;
                          final num mrp = (prod['mrp'] is num) ? (prod['mrp'] as num) : price;
                          final int stock = (prod['stock'] is num) ? (prod['stock'] as num).toInt() : 0;
                          final discount = (mrp > price && mrp > 0) ? (((mrp - price) / mrp) * 100).round() : 0;

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: slateBorder),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: slateBorder),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: imgUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imgUrl,
                                            fit: BoxFit.contain,
                                            errorWidget: (_, __, ___) => const Center(
                                              child: Text('📦', style: TextStyle(fontSize: 20)),
                                            ),
                                          )
                                        : const Center(
                                            child: Text('📦', style: TextStyle(fontSize: 20)),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Title & Stock
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12.5),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${price.toInt()}',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 13),
                                              fontWeight: FontWeight.w900,
                                              color: brandOrange,
                                            ),
                                          ),
                                          if (mrp > price) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '₹${mrp.toInt()}',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                                color: slateMuted,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                          if (discount > 0) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$discount% OFF',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF047857),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            'Stock: $stock',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              color: slateMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Edit Button
                                Bounceable(
                                  onTap: () => _openEditModal(prod),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFED7AA)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit_note_rounded, size: 15, color: brandOrange),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Edit',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: brandOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
