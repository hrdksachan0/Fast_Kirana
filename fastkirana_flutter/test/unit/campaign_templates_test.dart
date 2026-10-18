import 'dart:convert';

import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/features/navratri/navratri_data.dart';
import 'package:fastminute_flutter/features/navratri/navratri_shopping_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _templateIds = [
  'navratri',
  'diwali',
  'holi',
  'ramadan',
  'daily-essentials',
  'value-picks',
  'summer',
  'monsoon',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> index;
  final manifests = <String, Map<String, dynamic>>{};

  setUpAll(() async {
    final source =
        await rootBundle.loadString('assets/navratri/templates/index.json');
    index = (jsonDecode(source) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    for (final template in index) {
      manifests[template['id'] as String] = jsonDecode(await rootBundle
              .loadString('assets/navratri/${template['manifest']}'))
          as Map<String, dynamic>;
    }
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await Future.wait([inter.load(), poppins.load()]);
  });

  Map<String, dynamic> fresh(String id) =>
      jsonDecode(jsonEncode(manifests[id])) as Map<String, dynamic>;

  List<Product> catalogue(NavratriData data) => data.products.map((item) {
        final category = data.categories
            .firstWhere((category) => category.id == item.categoryId);
        return Product.fromJson({
          'id': item.id,
          'name': item.name,
          'slug': item.id,
          'price': item.price,
          'mrp': item.originalPrice,
          'stock': 1,
          'isAvailable': true,
          'tags': category.keywords,
        });
      }).toList();

  test('shared template index is present in the release asset bundle', () {
    expect(index.map((item) => item['id']), _templateIds);
  });

  for (final id in _templateIds) {
    test(
        '$id published configuration resolves all assets, destinations and collection filters',
        () async {
      final data = NavratriData.fromJson(manifests[id]!);
      expect(data.enabled, isTrue);
      expect(data.demo, isTrue);
      expect(data.categories, hasLength(4));
      expect(
          data.labels.sectionLabel, manifests[id]!['labels']['sectionLabel']);
      expect(data.layout, manifests[id]!['layout'] ?? 'classic');
      expect(data.navigation, isEmpty);
      final images = {
        index.firstWhere((item) => item['id'] == id)['thumbnail'] as String,
        if (data.decorationImage != null) data.decorationImage!,
        ...data.headers.map((item) => item.image).whereType<String>(),
        ...data.products.map((item) => item.image),
        ...data.categories.map((item) => item.image),
        ...data.tabs.map((item) => item.image),
      };
      for (final image in images) {
        expect((await rootBundle.load(navratriAsset(image))).lengthInBytes,
            greaterThan(0),
            reason: '$id needs bundled $image');
      }
      for (final destinationId in [
        ...data.products.map((item) => item.destinationId),
        ...data.categories.map((item) => item.destinationId),
      ]) {
        expect(data.destination(destinationId).query.trim(), isNotEmpty);
      }
      final products = catalogue(data);
      final food = Product.fromJson({
        'id': 'restaurant',
        'name': products.first.name,
        'restaurantId': 'food',
        'price': 10,
        'mrp': 10
      });
      for (final tab in data.tabs) {
        final matches = data.filterProducts([...products, food], tab);
        expect(matches.every((item) => item.restaurantId == null), isTrue);
        if (id != 'navratri') {
          expect(data.demoProductsFor(tab), isNotEmpty,
              reason: '$id ${tab.id} needs demonstration products');
          expect(matches, isNotEmpty,
              reason: '$id ${tab.id} needs catalogue filter terms');
        }
      }
    });
  }

  test(
      'empty custom-ID tabs mean all configured collections and top-picks obeys its own keywords',
      () {
    final data = NavratriData.fromJson(manifests['navratri']!);
    final all = NavratriTab(
        id: 'my-editable-tab',
        label: 'All essentials',
        image: data.tabs.first.image,
        keywords: const []);
    final focused = NavratriTab(
        id: 'top-picks',
        label: 'Only Chunri',
        image: data.tabs.first.image,
        keywords: const ['chunri']);
    expect(data.demoProductsFor(all).map((item) => item.id),
        data.products.map((item) => item.id));
    expect(data.filterProducts(catalogue(data), all).map((item) => item.id),
        data.products.map((item) => item.id));
    expect(
        data.demoProductsFor(focused).map((item) => item.id), ['mata-chunri']);
    expect(data.filterProducts(catalogue(data), focused).map((item) => item.id),
        ['mata-chunri']);
  });

  test(
      'legacy publication defaults to classic and unknown layouts fail instead of fallback silently',
      () {
    expect(NavratriData.fromJson(fresh('navratri')..remove('layout')).layout,
        'classic');
    for (final layout in [null, 'carousel', 1]) {
      final config = fresh('navratri')..['layout'] = layout;
      expect(() => NavratriData.fromJson(config), throwsFormatException);
    }
  });

  for (final entry in {
    'classic': 'diwali',
    'banner': 'ramadan',
    'split': 'holi',
    'grid': 'daily-essentials',
    'deals': 'value-picks',
  }.entries) {
    testWidgets(
        '${entry.key} composition fits small screens and enlarged text with independent product rotation',
        (tester) async {
      final data = NavratriData.fromJson(manifests[entry.value]!);
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destinations = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
            body: SingleChildScrollView(
                child: NavratriShoppingSection(
          data: data,
          catalog: const [],
          onNavigate: (value) => destinations.add(value.id),
        ))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final composition = find.byKey(ValueKey(entry.key == 'classic'
          ? 'navratri-grid'
          : 'navratri-layout-${entry.key}'));
      expect(composition, findsOneWidget);
      final size = tester.getSize(composition);
      final promotion = find.byKey(ValueKey(entry.key == 'classic'
          ? 'navratri-tall-card'
          : 'navratri-promo-strip'));
      Finder active(String id) => find.descendant(
          of: promotion, matching: find.byKey(ValueKey('promotion-$id')));
      expect(active(data.products.first.id), findsOneWidget);
      final categories = data.categories
          .map((item) => find.byKey(ValueKey('category-${item.id}')))
          .toList();
      if (entry.key == 'grid' || entry.key == 'split') {
        expect(tester.getTopLeft(categories[0]).dy,
            tester.getTopLeft(categories[1]).dy);
        expect(tester.getTopLeft(categories[2]).dy,
            greaterThan(tester.getTopLeft(categories[0]).dy));
        expect(tester.getTopLeft(promotion).dy,
            greaterThan(tester.getTopLeft(categories[2]).dy));
        if (entry.key == 'split') {
          expect(tester.getSize(categories[0]).height,
              greaterThan(tester.getSize(categories[2]).height));
        } else {
          expect(tester.getSize(categories[0]), tester.getSize(categories[2]));
        }
      } else if (entry.key != 'classic') {
        expect(tester.getTopLeft(categories[0]).dy,
            tester.getTopLeft(categories[3]).dy);
        expect(tester.getTopLeft(categories[0]).dy,
            greaterThan(tester.getTopLeft(promotion).dy));
        expect(tester.getSize(promotion).width, size.width);
      }
      expect(tester.takeException(), isNull);
      await tester.pump(data.timings.product);
      await tester
          .pump(data.timings.crossfade + const Duration(milliseconds: 1));
      expect(active(data.products.first.id), findsNothing);
      expect(active(data.products[1].id), findsOneWidget);
      expect(tester.getSize(composition), size);
      expect(tester.takeException(), isNull);
      final firstCategory =
          find.byKey(ValueKey('category-${data.categories.first.id}'));
      await tester.ensureVisible(firstCategory);
      await tester.tap(firstCategory);
      expect(destinations.last, data.categories.first.destinationId);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    });
  }
}
