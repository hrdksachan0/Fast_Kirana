import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/routes/page_transitions.dart';
import 'package:fastkirana_flutter/data/models/category.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';
import 'package:fastkirana_flutter/features/categories/category_products_screen.dart';
import 'package:fastkirana_flutter/features/home/featured_categories.dart';
import 'package:fastkirana_flutter/features/home/main_shell.dart';
import 'package:fastkirana_flutter/features/home/widgets/trending_categories_section.dart';
import 'package:fastkirana_flutter/providers/product_provider.dart';
import 'package:fastkirana_flutter/providers/store_settings_provider.dart';

const sources = [
  Category(
      id: 'fruit',
      name: 'Fruits & vegetables',
      slug: 'fruits-vegetables',
      sortOrder: 1,
      count: CategoryCount(products: 5)),
  Category(
      id: 'milk',
      name: 'Dairy & breakfast',
      slug: 'dairy-breakfast',
      sortOrder: 2,
      count: CategoryCount(products: 8)),
  Category(
      id: 'snacks',
      name: 'Snacks & munchies',
      slug: 'snacks-munchies',
      sortOrder: 3,
      count: CategoryCount(products: 2)),
  Category(
      id: 'drinks',
      name: 'Cold drinks & juices',
      slug: 'beverages',
      sortOrder: 4,
      count: CategoryCount(products: 3)),
];
Map<String, Object?> config(
        {bool enabled = true, List<Map<String, Object?>>? items}) =>
    {
      'version': 1,
      'enabled': enabled,
      'title': 'Featured categories',
      'items': items ??
          [
            {'categoryId': 'snacks', 'badge': 'Featured', 'tint': 'peach'},
            {'categoryId': 'milk', 'badge': 'Everyday', 'tint': 'cream'},
            {'categoryId': 'fruit', 'badge': 'Seasonal', 'tint': 'mint'},
            {'categoryId': 'drinks', 'tint': 'sky'},
          ]
    };

class _Navigation extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Plus Jakarta Sans')
          ..addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<ProviderContainer> render(WidgetTester tester,
      {double width = 390,
      double scale = 1,
      bool reduced = false,
      Object? raw,
      List<Category> categories = sources,
      _Navigation? observer}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      categoriesProvider.overrideWith((_) async => categories),
      storeSettingsProvider.overrideWith((_) async => StoreSettings(
          raw: {if (raw != null) featuredCategoriesKey: jsonEncode(raw)}))
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorObservers: [if (observer != null) observer],
            theme: ThemeData(fontFamily: 'Plus Jakarta Sans'),
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 500),
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduced),
                child: Scaffold(
                    backgroundColor: Colors.white,
                    body: SingleChildScrollView(
                        child: RepaintBoundary(
                            key: const ValueKey('capture'),
                            child: const TrendingCategoriesSection())))))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final widget in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
            widget.image, tester.element(find.byType(Image).first));
      }
    });
    await tester.pumpAndSettle();
    return container;
  }

  test(
      'curation filters unavailable roots and keeps admin order and category identity',
      () {
    final mixed = [
      ...sources,
      const Category(
          id: 'empty',
          name: 'Empty',
          slug: 'empty',
          count: CategoryCount(products: 0)),
      const Category(id: 'cafe', name: 'Cafe', slug: 'restaurant-food'),
      const Category(
          id: 'child', name: 'Child', slug: 'child', parentId: 'snacks')
    ];
    expect(
        FeaturedCategoriesConfig.defaults(mixed)
            .items
            .map((item) => item.categoryId),
        ['fruit', 'milk', 'snacks', 'drinks']);
    final edited = FeaturedCategoriesConfig.parse(config(items: [
      {'categoryId': 'snacks', 'label': 'Movie night'},
      {'categoryId': 'milk', 'enabled': false},
      {'categoryId': 'empty'},
      {'categoryId': 'gone'}
    ]))!
        .select(mixed);
    expect(edited.length, 1);
    expect(edited.single.label, 'Movie night');
    expect(edited.single.category, sources[2]);
    expect(
        FeaturedCategoriesConfig.parse(config(enabled: false))!.select(sources),
        isEmpty);
    expect(FeaturedCategoriesConfig.parse(config(items: []))!.select(sources),
        isEmpty);
  });
  test('invalid persisted curation cannot inject claims or unsafe images', () {
    for (final item in [
      {'categoryId': 'snacks', 'badge': 'LIVE'},
      {'categoryId': 'snacks', 'image': 'javascript:alert(1)'},
      {'categoryId': 'snacks', 'image': '/%2e%2e/thing.webp'},
      {'categoryId': 'snacks', 'label': 5}
    ]) {
      expect(FeaturedCategoriesConfig.parse(config(items: [item])), isNull);
    }
    expect(FeaturedCategoriesConfig.parse('{broken'), isNull);
    expect(
        FeaturedCategoriesConfig.parse(config(items: [
          {'categoryId': 'snacks'},
          {'categoryId': 'snacks'}
        ])),
        isNull);
  });
  for (final viewport in [
    (390.0, 1.0, 'mobile'),
    (320.0, 1.0, 'compact'),
    (320.0, 2.0, 'large-text'),
    (672.0, 1.0, 'tablet')
  ]) {
    testWidgets('actual rail is readable and has no overflow: ${viewport.$3}',
        (tester) async {
      await render(tester,
          width: viewport.$1, scale: viewport.$2, raw: config());
      expect(find.text('Featured categories'), findsOneWidget);
      expect(find.text('Snacks & munchies'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      expect(find.text('10m'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(tester.takeException(), isNull);
      if (Platform.environment['FEATURED_CAPTURE'] == 'true') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file =
            File('../artifacts/featured-categories/flutter-${viewport.$3}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }
    });
  }
  testWidgets('view all opens category tab with a minimum touch target',
      (tester) async {
    final container = await render(tester);
    final button = find.widgetWithText(TextButton, 'View all');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(container.read(selectedTabProvider), 2);
  });
  testWidgets('renaming preserves real navigation and assistive activation',
      (tester) async {
    final observer = _Navigation();
    await render(tester,
        raw: config(items: [
          {'categoryId': 'snacks', 'label': 'Movie night'}
        ]),
        observer: observer);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    expect(
        tester
            .getSemantics(find.bySemanticsLabel('Shop Movie night'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        true);
    await tester.tap(find.text('Movie night'));
    final route = observer.routes.last as ZeptoSlideRoute;
    expect((route.page as CategoryProductsScreen).category.id, 'snacks');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'reduced motion removes press animation and empty selection hides',
      (tester) async {
    await render(tester, reduced: true, raw: config());
    expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).duration,
        Duration.zero);
    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Snacks & munchies')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        .98);
    await gesture.cancel();
    await tester.pumpAndSettle();
    await render(tester, raw: config(items: []));
    expect(find.byKey(const ValueKey('featured-category-rail')), findsNothing);
  });
  testWidgets('all empty categories and missing categories hide',
      (tester) async {
    await render(tester, categories: [
      sources[0].copyWith(count: const CategoryCount(products: 0))
    ]);
    expect(find.byKey(const ValueKey('featured-category-rail')), findsNothing);
  });
  testWidgets(
      'settings load completes before showing a configured hidden section',
      (tester) async {
    final pending = Completer<StoreSettings>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((_) async => sources),
          storeSettingsProvider.overrideWith((_) => pending.future)
        ],
        child: const MaterialApp(
            home: Scaffold(body: TrendingCategoriesSection()))));
    await tester.pump();
    expect(find.byKey(const ValueKey('featured-category-rail')), findsNothing);
    pending.complete(StoreSettings(
        raw: {featuredCategoriesKey: jsonEncode(config(enabled: false))}));
    await tester.pumpAndSettle();
    expect(find.text('Featured categories'), findsNothing);
  });
}
