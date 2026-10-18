import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fastminute_flutter/core/config/app_config.dart';
import 'package:fastminute_flutter/core/network/api_client.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/data/repositories/product_repository.dart';
import 'package:fastminute_flutter/features/navratri/navratri_data.dart';
import 'package:fastminute_flutter/features/navratri/navratri_linked_products.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProductAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];
  _ProductAdapter(this.handler);
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(dynamic body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );

Map<String, dynamic> _product(String id,
        {double price = 125,
        int stock = 5,
        bool available = true,
        String? restaurantId}) =>
    {
      'id': id,
      'name': 'Actual $id',
      'imageUrl': '/uploads/$id.jpg',
      'price': price,
      'mrp': price + 25,
      'stock': stock,
      'isAvailable': available,
      'restaurantId': restaurantId,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> manifest;
  setUpAll(() async {
    manifest =
        jsonDecode(await rootBundle.loadString('assets/navratri/navratri.json'))
            as Map<String, dynamic>;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor(_ProductAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final container =
        ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
    return container;
  }

  Future<List<Product>> readLinked(
      ProviderContainer container, NavratriLinkedProductQuery query) {
    final provider = navratriLinkedProductsProvider(query);
    // Model Home's active subscription so autoDispose does not cancel a request
    // before the Dio adapter starts it.
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    return container.read(provider.future);
  }

  test('linked query keys isolate stores and deduplicate stable IDs', () {
    final first = NavratriLinkedProductQuery(
        storeId: 'a', productIds: ['two', 'one', 'one']);
    final equal =
        NavratriLinkedProductQuery(storeId: 'a', productIds: ['one', 'two']);
    expect(first, equal);
    expect(first.hashCode, equal.hashCode);
    expect(
        first,
        isNot(NavratriLinkedProductQuery(
            storeId: 'b', productIds: ['one', 'two'])));
  });

  test('selected SKU outside the 1000 item home feed resolves by scoped ID',
      () async {
    final source = jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
    source['demo'] = false;
    source['products'] = [
      {
        ...(source['products'] as List).first as Map<String, dynamic>,
        'productId': 'outside-feed'
      }
    ];
    final campaign = NavratriData.fromJson(source);
    final home = List.generate(
        1000, (index) => Product.fromJson(_product('home-$index')));
    final missing = missingNavratriProductIds(campaign, home);
    expect(missing, ['outside-feed']);
    final adapter =
        _ProductAdapter((_) async => _response(_product('outside-feed')));
    final container = containerFor(adapter);
    final resolved = await readLinked(container,
        NavratriLinkedProductQuery(storeId: 'store-a', productIds: missing));
    expect(adapter.requests.single.path, '/api/products/outside-feed');
    expect(adapter.requests.single.queryParameters, {'storeId': 'store-a'});
    final merged = mergeNavratriLinkedProducts(home, resolved);
    expect(merged.length, 1001);
    final promotion =
        NavratriPromotion.resolve(campaign.products.single, merged);
    expect(promotion.available, isTrue);
    expect(promotion.price, 125);
    expect(promotion.demo, isFalse);
  });

  test(
      'store changes and refreshed inventory cannot reuse available old-store stock',
      () async {
    var availableA = true;
    final adapter = _ProductAdapter((request) async {
      final available =
          request.queryParameters['storeId'] == 'store-a' && availableA;
      return _response(_product('selected',
          price: 77, stock: available ? 5 : 0, available: available));
    });
    final container = containerFor(adapter);
    final a = navratriLinkedProductsProvider(NavratriLinkedProductQuery(
        storeId: 'store-a', productIds: ['selected']));
    final b = navratriLinkedProductsProvider(NavratriLinkedProductQuery(
        storeId: 'store-b', productIds: ['selected']));
    final aSubscription = container.listen(a, (_, __) {});
    final bSubscription = container.listen(b, (_, __) {});
    addTearDown(aSubscription.close);
    addTearDown(bSubscription.close);
    expect((await container.read(a.future)).single.price, 77);
    expect(await container.read(b.future), isEmpty);
    availableA = false;
    container.invalidate(a);
    expect(await container.read(a.future), isEmpty);
    expect(
        adapter.requests.map((request) => request.queryParameters['storeId']),
        ['store-a', 'store-b', 'store-a']);
  });

  test(
      'unavailable, wrong-ID, restaurant and invalid-price detail results are discarded',
      () async {
    final adapter = _ProductAdapter((request) async {
      final id = request.path.split('/').last;
      return _response(switch (id) {
        'wrong-id' => _product('different'),
        'restaurant' => _product(id, restaurantId: 'outlet'),
        'unavailable' => _product(id, available: false),
        'out-of-stock' => _product(id, stock: 0),
        'negative-price' => _product(id, price: -1),
        _ => _product(id),
      });
    });
    final container = containerFor(adapter);
    final resolved = await readLinked(
        container,
        NavratriLinkedProductQuery(storeId: 'store-a', productIds: [
          'valid',
          'wrong-id',
          'restaurant',
          'unavailable',
          'out-of-stock',
          'negative-price',
        ]));
    expect(resolved.map((product) => product.id), ['valid']);
  });

  test(
      '404 and failed requests never fall back to an available product cached for another hub',
      () async {
    await ProductRepository.invalidateAllCache();
    final adapter = _ProductAdapter((request) async {
      if (request.path == '/api/products') {
        return _response({
          'products': [_product('selected', price: 999)]
        });
      }
      if (request.queryParameters['storeId'] == 'missing-store') {
        return _response({'error': 'Not found'}, status: 404);
      }
      throw DioException(
          requestOptions: request, type: DioExceptionType.connectionError);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    await ProductRepository(dio).getProducts(
        storeId: AppConfig.darkstoreId,
        limit: 1000,
        forceRefresh: true,
        includeRestaurants: false);
    expect(ProductRepository.preloadedProducts.single.price, 999);
    final container = containerFor(adapter);
    for (final storeId in ['missing-store', 'offline-store']) {
      final resolved = await readLinked(
          container,
          NavratriLinkedProductQuery(
              storeId: storeId, productIds: ['selected']));
      expect(resolved, isEmpty);
    }
    expect(
        adapter.requests
            .where((request) => request.path == '/api/products/selected')
            .map((request) => request.queryParameters['storeId']),
        ['missing-store', 'offline-store']);
    dio.close(force: true);
    await ProductRepository.invalidateAllCache();
  });

  test('merging linked results preserves current home product authority', () {
    final home = Product.fromJson(_product('same', price: 100));
    final older = Product.fromJson(_product('same', price: 50));
    final linked = Product.fromJson(_product('linked', price: 75));
    final merged = mergeNavratriLinkedProducts([home], [older, linked]);
    expect(merged.map((product) => product.id), ['same', 'linked']);
    expect(merged.first, same(home));
  });
}
