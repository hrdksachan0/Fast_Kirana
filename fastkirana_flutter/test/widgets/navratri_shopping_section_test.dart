import 'dart:convert';

import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/store_hub.dart';
import 'package:fastkirana_flutter/core/network/api_client.dart';
import 'package:fastkirana_flutter/providers/store_hub_provider.dart';
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/features/navratri/navratri_data.dart';
import 'package:fastkirana_flutter/features/navratri/navratri_shopping_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class _CampaignDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NavratriData data;
  late Map<String, dynamic> manifest;

  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await Future.wait([inter.load(), poppins.load()]);
    final source = await rootBundle.loadString('assets/navratri/navratri.json');
    manifest = jsonDecode(source) as Map<String, dynamic>;
    data = NavratriData.fromJson(manifest);
  });

  Map<String, dynamic> configuration() =>
      jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;

  Future<NavratriData> published(Map<String, dynamic>? campaign,
      {bool fail = false}) async {
    final dio = _CampaignDio();
    final response = Response<dynamic>(
      data: {'campaign': campaign},
      requestOptions: RequestOptions(path: '/api/homepage-campaign'),
    );
    when(() => dio.get('/api/homepage-campaign',
            queryParameters: {'storeId': StoreHub.defaultGhatampur.id}))
        .thenAnswer((_) async {
      if (fail) throw StateError('Offline');
      return response;
    });
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      currentStoreHubProvider.overrideWithValue(StoreHub.defaultGhatampur),
    ]);
    try {
      return await container.read(navratriDataProvider.future);
    } finally {
      container.dispose();
    }
  }

  test('published loader scopes request and preserves disabled configuration',
      () async {
    final disabled = await published({'version': 1, 'enabled': false});
    expect(disabled.enabled, isFalse);
    final remote = configuration()..['searchPrefix'] = 'Find';
    expect((await published(remote)).searchPrefix, 'Find');
  });

  test(
      'missing, malformed and offline published configuration use bundled fallback',
      () async {
    expect((await published(null)).labels.specialsHeading, 'Navratri Specials');
    expect((await published({'version': 9})).version, 1);
    expect((await published(null, fail: true)).searchPrefix, 'Search for');
  });

  test(
      'generic optional labels, palette, autoplay and tab counts are supported',
      () {
    final custom = configuration()
      ..['autoplay'] = false
      ..['searchPrefix'] = 'Find'
      ..['labels'] = {
        'specialsHeading': 'Weekend Specials',
        'curvedTabLabel': 'Explore'
      }
      ..['appearance'] = {'background': '#123456', 'card': '#FAFAFA'}
      ..['decorationImage'] = null
      ..['navigation'] = [];
    final parsed = NavratriData.fromJson(custom);
    expect(parsed.autoplay, isFalse);
    expect(parsed.labels.specialsHeading, 'Weekend Specials');
    expect(parsed.appearance.background, const Color(0xFF123456));
    expect(parsed.decorationImage, isNull);
    custom['tabs'] = [(custom['tabs'] as List).first];
    expect(NavratriData.fromJson(custom).tabs.length, 1);
    custom['tabs'] = List.generate(
        8,
        (index) => {
              ...(manifest['tabs'] as List).first as Map<String, dynamic>,
              'id': 'tab-$index',
            });
    expect(NavratriData.fromJson(custom).tabs.length, 8);
    custom['tabs'] = [];
    expect(() => NavratriData.fromJson(custom), throwsFormatException);
  });

  test('live campaign cannot use demo prices without catalogue links', () {
    final live = configuration()..['demo'] = false;
    expect(() => NavratriData.fromJson(live), throwsFormatException);
    for (final item in live['products'] as List) {
      item['productId'] = item['id'];
    }
    expect(NavratriData.fromJson(live).demo, isFalse);
  });

  test('remote SVG and uploaded raster URLs resolve without bundled prefix',
      () {
    expect(navratriAsset('https://example.test/uploads/product.jpg'),
        'https://example.test/uploads/product.jpg');
    expect(navratriAsset('/uploads/product.png'),
        endsWith('/uploads/product.png'));
    expect(navratriImageIsSvg('https://example.test/art.svg?v=1'), isTrue);
    expect(navratriImageIsSvg('/uploads/photo.jpeg'), isFalse);
  });

  test('linked promotions use actual catalogue fields and availability', () {
    final item = NavratriProduct.fromJson({
      ...(manifest['products'] as List).first as Map<String, dynamic>,
      'productId': 'live-1',
    });
    final live = Product.fromJson({
      'id': 'live-1',
      'name': 'Actual Dandiya',
      'imageUrl': '/uploads/live.jpg',
      'price': 125,
      'mrp': 150,
      'stock': 10,
      'isAvailable': true,
    });
    final resolved = NavratriPromotion.resolve(item, [live]);
    expect(resolved.name, 'Actual Dandiya');
    expect(resolved.image, '/uploads/live.jpg');
    expect(resolved.price, 125);
    expect(resolved.originalPrice, 150);
    expect(resolved.demo, isFalse);
    expect(resolved.available, isTrue);
    final missing = NavratriPromotion.resolve(item, []);
    expect(missing.showPrice, isFalse);
    expect(missing.available, isFalse);
  });

  test('emoji and invalid live images retain configured campaign artwork', () {
    final item = NavratriProduct.fromJson({
      ...(manifest['products'] as List).first as Map<String, dynamic>,
      'productId': 'live-1',
    });
    for (final image in [
      '📦',
      'javascript:alert(1)',
      '../private.png',
      '//example.test/a.png'
    ]) {
      final live = Product.fromJson({
        'id': 'live-1',
        'name': 'Actual item',
        'imageUrl': image,
        'price': 100,
        'mrp': 125,
        'stock': 5,
        'isAvailable': true
      });
      expect(NavratriPromotion.resolve(item, [live]).image, item.image);
    }
    expect(validNavratriImage('/uploads/product.png'), isTrue);
    expect(validNavratriImage('https://example.test/product.svg?token=123'),
        isTrue);
  });

  Product product(String id, String name, {String? restaurantId}) =>
      Product.fromJson({
        'id': id,
        'name': name,
        'slug': name.toLowerCase().replaceAll(' ', '-'),
        'restaurantId': restaurantId,
        'price': 50,
        'mrp': 60,
        'tags': <String>[],
        'isAvailable': true,
      });

  test('manifest loads nullable title image and validates destinations', () {
    expect(data.headers[1].image, isNull);
    expect(data.destination(data.categories[0].destinationId).query, 'puja');
    expect(() => data.destination('missing'), throwsFormatException);
    expect(data.timings.header, const Duration(seconds: 4));
    expect(data.timings.product, const Duration(milliseconds: 2500));
  });

  test('tabs filter live products and keep restaurant stock out of grocery',
      () {
    final catalog = [
      product('diya', 'Puja brass diya'),
      product('dandiya', 'Dandiya Sticks'),
      product('flower', 'Fresh marigold flowers'),
      product('chunri', 'Mata Chunri'),
      product('food', 'Puja thali', restaurantId: 'restaurant-1'),
      product('other', 'Whole wheat bread'),
    ];
    expect(data.filterProducts(catalog, data.tabs[0]).map((p) => p.id),
        ['diya', 'dandiya', 'flower', 'chunri']);
    expect(
        data.filterProducts(catalog, data.tabs[1]).map((p) => p.id), ['diya']);
    expect(data.filterProducts(catalog, data.tabs[2]).map((p) => p.id),
        ['flower']);
    expect(data.filterProducts(catalog, data.tabs[3]).map((p) => p.id),
        ['chunri']);
  });

  test('keyword boundaries distinguish diya from dandiya and support plurals',
      () {
    expect(matchesNavratriKeywords('Dandiya Sticks', ['diya']), isFalse);
    expect(matchesNavratriKeywords('Marigold flowers', ['flower']), isTrue);
    expect(matchesNavratriKeywords('Brass idols', ['idol']), isTrue);
    expect(matchesNavratriKeywords('Puja-essentials', ['puja essentials']),
        isTrue);
    expect(data.demoProductsFor(data.tabs[1]).map((item) => item.id),
        ['mata-chunri']);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double textScale = 1,
    bool reducedMotion = false,
    bool tickerEnabled = true,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          accessibleNavigation: false,
        ),
        child: TickerMode(enabled: tickerEnabled, child: content!),
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    // SVG parsing is asynchronous; finish it without waiting on autoplay timers.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget section({NavratriNavigate? onNavigate}) => NavratriShoppingSection(
        data: data,
        catalog: const [],
        onNavigate: onNavigate ?? (_) {},
      );

  Finder promotion(String id) => find.descendant(
        of: find.byKey(const ValueKey('navratri-tall-card')),
        matching: find.byKey(ValueKey('promotion-$id')),
      );

  testWidgets('department row is removed from pinned campaign search',
      (tester) async {
    await mount(
        tester,
        SizedBox(
            height: 64,
            child: NavratriStickyHeader(
              data: data,
              onNavigate: (_) {},
              onSearch: () {},
            )));
    expect(find.text('Search for'), findsOneWidget);
    for (final label in ['All', 'Fresh', 'Fashion', 'Mobiles', 'Pharmacy']) {
      expect(find.text(label), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('generic campaign labels palette and disabled autoplay render',
      (tester) async {
    final custom = configuration()
      ..['autoplay'] = false
      ..['labels'] = {
        'sectionLabel': 'Weekend campaign',
        'specialsHeading': 'Weekend Specials',
        'curvedTabLabel': 'Explore',
        'demoLabel': 'Illustration',
        'emptyText': 'Nothing available'
      }
      ..['appearance'] = {'background': '#123456'}
      ..['decorationImage'] = null;
    await mount(
        tester,
        NavratriShoppingSection(
          data: NavratriData.fromJson(custom),
          catalog: const [],
          onNavigate: (_) {},
        ));
    expect(find.text('Weekend Specials'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.byKey(const ValueKey('navratri-pause')), findsNothing);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container && widget.color == const Color(0xFF123456)),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(promotion('dandiya-sticks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('eight editable tabs stay readable and selectable on mobile',
      (tester) async {
    final custom = configuration()..['autoplay'] = false;
    custom['tabs'] = List.generate(
        8,
        (index) => {
              ...(manifest['tabs'] as List).first as Map<String, dynamic>,
              'id': 'collection-$index',
              'label': 'Collection $index for everyday essentials',
            });
    await mount(
        tester,
        NavratriShoppingSection(
          data: NavratriData.fromJson(custom),
          catalog: const [],
          onNavigate: (_) {},
        ),
        width: 320,
        textScale: 2);
    final last = find.byKey(const ValueKey('tab-collection-7'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pump();
    expect(find.text('Collection 7 for everyday essentials'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'disabled campaign and unavailable live slots do not show demo offers',
      (tester) async {
    final custom = configuration()..['demo'] = false;
    custom['products'] = [
      {
        ...(manifest['products'] as List).first as Map<String, dynamic>,
        'productId': 'missing',
      }
    ];
    await mount(
        tester,
        NavratriShoppingSection(
          data: NavratriData.fromJson(custom),
          catalog: const [],
          onNavigate: (_) {},
        ));
    expect(promotion('dandiya-sticks'), findsNothing);
    expect(find.text('₹99'), findsNothing);
    expect(find.text('Demo prices'), findsNothing);
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await mount(
        tester,
        NavratriShoppingSection(
          data: NavratriData.fromJson({'version': 1, 'enabled': false}),
          catalog: const [],
          onNavigate: (_) {},
        ));
    expect(find.byKey(const ValueKey('navratri-grid')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'linked promo opens actual product and shows scoped catalogue price',
      (tester) async {
    final custom = configuration()..['demo'] = false;
    custom['products'] = [
      {
        ...(manifest['products'] as List).first as Map<String, dynamic>,
        'productId': 'selected-1',
      }
    ];
    final live = Product.fromJson({
      'id': 'selected-1',
      'name': 'Selected Item',
      'price': 125,
      'mrp': 150,
      'stock': 5,
      'isAvailable': true
    });
    Product? opened;
    await mount(
        tester,
        NavratriShoppingSection(
          data: NavratriData.fromJson(custom),
          catalog: [live],
          onNavigate: (_) {},
          onProductSelected: (item) => opened = item,
        ));
    expect(find.text('Selected Item'), findsOneWidget);
    expect(find.text('₹125'), findsOneWidget);
    expect(find.text('₹99'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('navratri-tall-card')));
    expect(opened, same(live));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('independent rotations preserve tall card and grid geometry',
      (tester) async {
    await mount(tester, section());
    final gridSize =
        tester.getSize(find.byKey(const ValueKey('navratri-grid')));
    final cardSize =
        tester.getSize(find.byKey(const ValueKey('navratri-tall-card')));
    expect(gridSize.height, 230);
    expect(cardSize.height, 230);
    expect(promotion('dandiya-sticks'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 401));
    expect(promotion('dandiya-sticks'), findsNothing);
    expect(promotion('mata-chunri'), findsOneWidget);
    expect(find.byKey(const ValueKey('header-festive-illustration')),
        findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('navratri-tall-card'))),
        cardSize);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 401));
    expect(find.byKey(const ValueKey('header-navratri-title')), findsOneWidget);
    expect(
        tester.getSize(find.byKey(const ValueKey('navratri-grid'))), gridSize);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('crossfade excludes outgoing content from semantics and pointers',
      (tester) async {
    await mount(tester, section());
    await tester.pump(const Duration(milliseconds: 2500));
    final outgoing = promotion('dandiya-sticks');
    expect(outgoing, findsOneWidget);
    expect(find.ancestor(of: outgoing, matching: find.byType(ExcludeSemantics)),
        findsWidgets);
    expect(find.ancestor(of: outgoing, matching: find.byType(IgnorePointer)),
        findsWidgets);
    expect(find.ancestor(of: outgoing, matching: find.byType(ExcludeFocus)),
        findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'inactive app pauses rotations and resumes after a fresh interval',
      (tester) async {
    await mount(tester, section());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 12));
    expect(promotion('dandiya-sticks'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 401));
    expect(promotion('mata-chunri'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion and inactive TickerMode disable autoplay',
      (tester) async {
    await mount(tester, section(), reducedMotion: true);
    await tester.pump(const Duration(seconds: 20));
    expect(promotion('dandiya-sticks'), findsOneWidget);
    expect(find.byKey(const ValueKey('header-festive-illustration')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, section(), tickerEnabled: false);
    await tester.pump(const Duration(seconds: 20));
    expect(promotion('dandiya-sticks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual pause stops both header and product clocks',
      (tester) async {
    await mount(tester, section());
    await tester.tap(find.byKey(const ValueKey('navratri-pause')));
    await tester.pump(const Duration(seconds: 10));
    expect(promotion('dandiya-sticks'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('navratri-pause')));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 401));
    expect(promotion('mata-chunri'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('category click targets and category tabs use declared data',
      (tester) async {
    final destinations = <String>[];
    await mount(
        tester, section(onNavigate: (value) => destinations.add(value.id)));
    for (final category in data.categories) {
      await tester.tap(find.byKey(ValueKey('category-${category.id}')));
    }
    expect(destinations,
        data.categories.map((category) => category.destinationId));
    await tester.tap(find.byKey(const ValueKey('tab-chunri-idols')));
    await tester.pump();
    expect(find.text('Dandiya Sticks'), findsOneWidget); // rotating hero only
    expect(find.text('Mata Chunri'), findsOneWidget); // filtered demo example
    expect(find.text('Garba Jacket'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('search suggestion alone rotates while prefix remains stable',
      (tester) async {
    await mount(
      tester,
      SizedBox(
        height: 112,
        child: NavratriStickyHeader(
          data: data,
          onNavigate: (_) {},
          onSearch: () {},
        ),
      ),
    );
    expect(find.text('Search for'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(tester.getSize(find.text('Search for')).height, lessThan(20));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 401));
    expect(find.text('Search for'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Puja essentials'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pinned search stays at the viewport top during scroll',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        body: CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 180)),
          SliverPersistentHeader(
            pinned: true,
            delegate: NavratriPinnedHeader(
              height: 112,
              child: NavratriStickyHeader(
                data: data,
                onNavigate: (_) {},
                onSearch: () {},
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ]),
      ),
    ));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(find.byType(NavratriStickyHeader)).dy, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('search fits width $width with 2x text and voice action',
        (tester) async {
      await mount(
        tester,
        Builder(
            builder: (context) => SizedBox(
                  height: NavratriStickyHeader.height(context, data: data),
                  child: NavratriStickyHeader(
                    data: data,
                    onNavigate: (_) {},
                    onSearch: () {},
                    onVoiceSearch: () {},
                  ),
                )),
        width: width,
        textScale: 2,
      );
      for (var suggestion = 0; suggestion < 4; suggestion++) {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 401));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 390.0, 840.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layout fits width $width and text scale $scale',
          (tester) async {
        await mount(tester, section(), width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 401));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 401));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
