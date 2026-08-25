import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product.dart';
import '../data/models/category.dart';
import '../data/repositories/product_repository.dart';
import '../core/network/api_client.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.read(dioProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getCategories();
});

final trendingProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts(limit: 10);
});

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, categoryId) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts(category: categoryId, limit: 1000);
});
