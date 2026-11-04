import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import 'product_detail_screen.dart';
import '../search/search_screen.dart';

class ProductDetailLoaderScreen extends ConsumerStatefulWidget {
  final String slugOrId;

  const ProductDetailLoaderScreen({super.key, required this.slugOrId});

  @override
  ConsumerState<ProductDetailLoaderScreen> createState() => _ProductDetailLoaderScreenState();
}

class _ProductDetailLoaderScreenState extends ConsumerState<ProductDetailLoaderScreen> {
  bool _isLoading = true;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final repo = ProductRepository(ref.read(dioProvider));
      final p = await repo.getProduct(widget.slugOrId);
      if (mounted) {
        setState(() {
          _product = p;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_product != null) {
      return ProductDetailScreen(product: _product!);
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFE20A22),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading item...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final query = widget.slugOrId.replaceAll('-', ' ').trim();
    return SearchScreen(initialQuery: query);
  }
}
