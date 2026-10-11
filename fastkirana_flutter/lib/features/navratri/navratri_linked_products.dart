import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/models/product.dart';
import 'navratri_data.dart';

/// A scoped, stable key keeps late results from another store out of a campaign.
class NavratriLinkedProductQuery {
  final String storeId;
  final List<String> productIds;
  NavratriLinkedProductQuery(
      {required this.storeId, required Iterable<String> productIds})
      : productIds = List.unmodifiable(
            productIds.where((id) => id.isNotEmpty).toSet().toList()..sort());

  @override
  bool operator ==(Object other) =>
      other is NavratriLinkedProductQuery &&
      other.storeId == storeId &&
      const ListEquality<String>().equals(other.productIds, productIds);
  @override
  int get hashCode =>
      Object.hash(storeId, const ListEquality<String>().hash(productIds));
}

/// Campaign links resolve independently of the bounded home product feed.
/// Direct requests deliberately avoid ProductRepository's cross-hub fallback.
final navratriLinkedProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, NavratriLinkedProductQuery>((ref, query) async {
  if (query.storeId.isEmpty || query.productIds.isEmpty) return [];
  final dio = ref.watch(dioProvider);
  final cancellation = CancelToken();
  ref.onDispose(() => cancellation.cancel('Campaign scope changed'));
  final products = await Future.wait(query.productIds.map((id) async {
    try {
      final response = await dio.get('/api/products/${Uri.encodeComponent(id)}',
          queryParameters: {'storeId': query.storeId},
          cancelToken: cancellation);
      if (response.data is! Map) return null;
      final product =
          Product.fromJson(Map<String, dynamic>.from(response.data as Map));
      if (product.id != id ||
          product.restaurantId?.isNotEmpty == true ||
          !product.isAvailable ||
          product.stock <= 0 ||
          !product.price.isFinite ||
          product.price < 0) {
        return null;
      }
      return product;
    } catch (_) {
      // Missing, unavailable and failed links remain absent; never use cached
      // stock/prices from a different hub or manually entered demo prices.
      return null;
    }
  }));
  return products.whereType<Product>().toList(growable: false);
});

List<String> missingNavratriProductIds(
    NavratriData data, List<Product> catalog) {
  final existing = catalog.map((product) => product.id).toSet();
  final allConfiguredIds = <String>{
    ...data.products.map((product) => product.productId).whereType<String>(),
    ...data.tabs.expand((tab) => tab.productIds),
  };
  return allConfiguredIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty && !existing.contains(id))
      .toSet()
      .toList(growable: false);
}

List<Product> mergeNavratriLinkedProducts(
    List<Product> catalog, List<Product> linked) {
  final merged = {for (final product in catalog) product.id: product};
  for (final product in linked) {
    merged.putIfAbsent(product.id, () => product);
  }
  return merged.values.toList(growable: false);
}
