import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastminute_flutter/core/utils/app_connectivity.dart';
import 'package:fastminute_flutter/core/utils/category_transition_helper.dart';
import 'package:fastminute_flutter/core/widgets/contextual_brand_transition_screen.dart';
import 'package:fastminute_flutter/data/models/cart.dart';
import 'package:fastminute_flutter/data/models/category.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/data/models/store_hub.dart';
import 'package:fastminute_flutter/data/models/store_settings.dart';
import 'package:fastminute_flutter/data/repositories/product_repository.dart';
import 'package:fastminute_flutter/data/repositories/wishlist_repository.dart';
import 'package:fastminute_flutter/providers/wishlist_provider.dart';
import 'package:fastminute_flutter/features/categories/category_products_screen.dart';
import 'package:fastminute_flutter/providers/cart_provider.dart';
import 'package:fastminute_flutter/providers/product_provider.dart';
import 'package:fastminute_flutter/providers/store_hub_provider.dart';
import 'package:fastminute_flutter/providers/store_settings_provider.dart';
import 'package:fastminute_flutter/widgets/product_card.dart';
import 'offline_experience_test.dart'
    show TestConnection, TestCartRepository, TestCartNotifier;

const category =
    Category(id: 'CAT-101', name: 'Fresh groceries', slug: 'fruits-vegetables');
const vegetables = Category(
    id: 'SUB-101-02',
    name: 'Vegetables',
    slug: 'fresh-vegetables',
    parentId: 'CAT-101');
const fruits = Category(
    id: 'SUB-101-01',
    name: 'Fruits',
    slug: 'fresh-fruits',
    parentId: 'CAT-101');
const hub = StoreHub(
    id: 'hub-test-ui', name: 'Test store', latitude: 26.15, longitude: 80.17);

List<Product> makeProducts([int count = 40]) => List.generate(
    count,
    (i) => Product.fromJson({
          'id': 'p$i',
          'name': 'Fresh item $i',
          'price': i + 10,
          'mrp': i + 20,
          'stock': 100,
          'categoryId': i.isEven ? vegetables.id : fruits.id,
          'category': {
            'id': i.isEven ? vegetables.id : fruits.id,
            'name': i.isEven ? 'Vegetables' : 'Fruits',
            'slug': i.isEven ? 'fresh-vegetables' : 'fresh-fruits',
            'parentId': category.id
          },
        }));

class EmptyWishlist extends WishlistRepository {
  EmptyWishlist() : super(Dio());
  @override
  Future<List<Product>> getWishlist() async => [];
}

class CatalogRepository extends ProductRepository {
  List<Product> products = makeProducts();
  List<Product>? previewProducts;
  List<Category> categories = [category, vegetables, fruits];
  Completer<List<Product>>? pending;
  final categoryRefreshes = <bool>[];
  CatalogRepository() : super(Dio());
  @override
  List<Product>? peekCachedProducts(
          {String? categoryKey, required String storeId}) =>
      previewProducts;
  @override
  Future<List<Product>> getCachedProducts(
          {String? categoryKey, required String storeId}) async =>
      previewProducts ?? [];
  @override
  Future<List<Category>> getCategories(
          {String? storeId,
          bool forceRefresh = false,
          bool pruneEmpty = false}) async =>
      categories;
  @override
  Future<List<Product>> getProducts(
      {String? categoryId,
      String? category,
      String? search,
      String? restaurantId,
      String? storeId,
      int limit = 1000,
      bool forceRefresh = false,
      bool? includeRestaurants,
      bool admin = false,
      bool includeUnavailable = false}) async {
    if (categoryId != null || category != null) {
      categoryRefreshes.add(forceRefresh);
      return pending?.future ?? Future.value(products);
    }
    return products;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final entry in {
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-Variable.ttf',
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
    for (final family in ['PlusJakartaSans', 'Inter']) {
      for (final weight in ['regular', '500', '600', '700', '800', '900']) {
        await (FontLoader('${family}_$weight')
              ..addFont(rootBundle.load('assets/fonts/$family-Variable.ttf')))
            .load();
      }
    }
  });

  Future<ProviderContainer> render(
      WidgetTester tester, CatalogRepository repo, TestConnection connection,
      {bool launch = false, double width = 390, GlobalKey? previewKey}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cartRepo = TestCartRepository([]);
    final container = ProviderContainer(overrides: [
      wishlistRepositoryProvider.overrideWithValue(EmptyWishlist()),
      connectivityProvider.overrideWith((ref) => connection),
      currentStoreHubProvider.overrideWithValue(hub),
      productRepositoryProvider.overrideWithValue(repo),
      cartProvider
          .overrideWith((ref) => TestCartNotifier(cartRepo, Cart.empty())),
      storeSettingsProvider.overrideWith((ref) async => const StoreSettings()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
            key: previewKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'Inter',
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: const Color(0xFFE20A22))
                          .copyWith(surface: Colors.white)),
              home: Consumer(builder: (context, ref, _) {
                ref.watch(catalogRecoveryProvider);
                return launch
                    ? Scaffold(
                        body: Center(
                            child: TextButton(
                                onPressed: () => CategoryTransitionHelper
                                    .pushCategoryWithTransition(
                                        context, ref, category),
                                child: const Text('Open category'))))
                    : const CategoryProductsScreen(category: category);
              }),
            ))));
    await tester.pump();
    return container;
  }

  testWidgets('Cached category opens directly with no forced interstitial',
      (tester) async {
    final repo = CatalogRepository()
      ..previewProducts = makeProducts()
      ..pending = Completer();
    await render(tester, repo, TestConnection()..online = true, launch: true);
    await tester.tap(find.text('Open category'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CategoryProductsScreen), findsOneWidget);
    expect(find.byType(ProductCard), findsWidgets);
    expect(find.byType(ContextualBrandTransitionScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.pending!.complete(repo.products);
  });

  testWidgets(
      'Cold loader appears after delay and disappears as soon as data is ready',
      (tester) async {
    final repo = CatalogRepository()..pending = Completer();
    await render(tester, repo, TestConnection()..online = true, launch: true);
    await tester.tap(find.text('Open category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 179));
    expect(find.byType(ContextualBrandTransitionScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byType(ContextualBrandTransitionScreen), findsOneWidget);
    repo.pending!.complete(repo.products);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ContextualBrandTransitionScreen), findsNothing);
    expect(find.byType(ProductCard), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Back during loading never navigates again when data arrives',
      (tester) async {
    final repo = CatalogRepository()..pending = Completer();
    await render(tester, repo, TestConnection()..online = true, launch: true);
    await tester.tap(find.text('Open category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final context =
        tester.element(find.byType(ContextualBrandTransitionScreen));
    Navigator.of(context).pop();
    await tester.pump(const Duration(milliseconds: 400));
    repo.pending!.complete(repo.products);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Open category'), findsOneWidget);
    expect(find.byType(CategoryProductsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Slow request falls back to a skeleton with the final grid geometry',
      (tester) async {
    final repo = CatalogRepository()..pending = Completer();
    await render(tester, repo, TestConnection()..online = true,
        launch: true, width: 500);
    await tester.tap(find.text('Open category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byType(ContextualBrandTransitionScreen), findsNothing);
    final loadingGrid = tester.widget<GridView>(find.byType(GridView));
    final loadingGeometry =
        loadingGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    repo.pending!.complete(repo.products);
    await tester.pump();
    await tester.pump();
    final loadedGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final loadedGeometry =
        loadedGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(loadingGeometry.crossAxisCount, loadedGeometry.crossAxisCount);
    expect(loadingGeometry.childAspectRatio, loadedGeometry.childAspectRatio);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Recovery preserves category state, subcategory, cart and scroll while fetching fresh data',
      (tester) async {
    final repo = CatalogRepository();
    final connection = TestConnection()..online = true;
    final key = GlobalKey();
    final container = await render(tester, repo, connection, previewKey: key);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetables'));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final previousState = tester.state(find.byType(CategoryProductsScreen));
    final before = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .offset;
    final previousCart = container.read(cartProvider);
    connection.online = false;
    connection.notifyListeners();
    await tester.pump();
    repo.pending = Completer();
    repo.categories = [category, fruits, vegetables];
    connection.reconnect();
    await tester.pump();
    expect(find.byType(ProductCard), findsWidgets);
    expect(find.byType(ProductCardSkeleton), findsNothing);
    expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        before);
    expect(repo.categoryRefreshes.last, isTrue);
    repo.pending!.complete(repo.products);
    await tester.pumpAndSettle();
    expect(
        tester.state(find.byType(CategoryProductsScreen)), same(previousState));
    expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        before);
    expect(container.read(cartProvider), same(previousCart));
    for (final card
        in tester.widgetList<ProductCard>(find.byType(ProductCard))) {
      expect(card.product.categoryId, vegetables.id);
    }
    expect(container.read(catalogRecoveryEpochProvider), 1);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/offline-previews')
        ..createSync(recursive: true);
      File('${dir.path}/category-recovered.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  test('Disk category preview stays isolated to its hub and category',
      () async {
    final products = makeProducts(4);
    SharedPreferences.setMockInitialValues({
      'cached_products_cache-test_v7':
          jsonEncode(products.map((p) => p.toJson()).toList())
    });
    final repo = ProductRepository(Dio());
    final saved = await repo.getCachedProducts(
        categoryKey: vegetables.id, storeId: 'cache-test');
    expect(saved, hasLength(2));
    expect(saved.every((p) => p.categoryId == vegetables.id), isTrue);
    expect(
        repo.peekCachedProducts(
            categoryKey: vegetables.id, storeId: 'another-store'),
        isNull);
    final offlineDio = Dio();
    offlineDio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.reject(DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
          error: 'Simulated offline'));
    }));
    final fallback = await ProductRepository(offlineDio).getProducts(
        categoryId: vegetables.id, storeId: 'cache-test', forceRefresh: true);
    expect(fallback, hasLength(2));
    expect(fallback.every((product) => product.categoryId == vegetables.id),
        isTrue);
  });
}
