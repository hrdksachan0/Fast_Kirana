import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// The package exposes its manifest for tests that use bundled font fixtures.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:fastkirana_flutter/data/repositories/wishlist_repository.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';
import 'package:fastkirana_flutter/providers/store_settings_provider.dart';
import 'package:fastkirana_flutter/providers/wishlist_provider.dart';
import 'package:fastkirana_flutter/widgets/product_card.dart';
import 'package:fastkirana_flutter/features/navratri/campaign_block.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/features/navratri/campaign_block_section.dart';
import 'package:fastkirana_flutter/features/navratri/navratri_data.dart';
import 'package:fastkirana_flutter/features/navratri/navratri_shopping_section.dart';

class _CollectionCart extends CartNotifier {
  _CollectionCart() : super(CartRepository(Dio())) {
    state = AsyncValue.data(Cart.fromJson({'id': 'fixture', 'items': []}));
  }
  @override
  Future<void> loadCart([CartRepository? repo]) async {}
}

class _CollectionWishlist extends WishlistNotifier {
  _CollectionWishlist() : super(WishlistRepository(Dio()));
  @override
  Future<void> loadWishlist() async {}
}

class _FontManifest implements AssetManifest {
  final AssetManifest bundled;
  final Map<String, String> aliases;
  _FontManifest(this.bundled, this.aliases);
  @override
  List<String> listAssets() => [...bundled.listAssets(), ...aliases.keys];
  @override
  List<AssetMetadata>? getAssetVariants(String key) =>
      bundled.getAssetVariants(aliases[key] ?? key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> manifest;
  late ByteData productPhoto;
  setUpAll(() async {
    manifest =
        jsonDecode(await rootBundle.loadString('assets/navratri/navratri.json'))
            as Map<String, dynamic>;
    productPhoto = await rootBundle
        .load('assets/categories/fruits_vegetables_category.webp');
    final drawings = <String>{
      for (final source in ['headers', 'products', 'categories', 'tabs'])
        for (final item in manifest[source] as List)
          if (item['image'] is String) item['image'] as String,
      if (manifest['decorationImage'] is String)
        manifest['decorationImage'] as String,
    };
    await Future.wait(drawings
        .where((image) => image.endsWith('.svg'))
        .map((image) => SvgAssetLoader(navratriAsset(image)).loadBytes(null)));
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    final productFont = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([font.load(), productFont.load(), icons.load()]);
    // Serve Google Fonts' weight-specific names from existing variable fonts,
    // so native product fixtures and captures never fetch fonts over HTTP.
    final aliases = <String, String>{};
    for (final family in ['Inter', 'PlusJakartaSans']) {
      for (final weight in [
        'Thin',
        'ExtraLight',
        'Light',
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black'
      ]) {
        aliases['assets/fonts/$family-$weight.ttf'] =
            'assets/fonts/$family-Variable.ttf';
      }
    }
    final bytes = <String, ByteData>{};
    for (final path in aliases.values.toSet()) {
      bytes[path] = await rootBundle.load(path);
    }
    font_test.assetManifest = _FontManifest(
        await AssetManifest.loadFromAssetBundle(rootBundle), aliases);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (aliases.containsKey(key)) return bytes[aliases[key]];
      final result = Completer<ByteData?>();
      ui.PlatformDispatcher.instance
          .sendPlatformMessage('flutter/assets', message, result.complete);
      return result.future;
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    final styles = <TextStyle>[];
    for (final weight in FontWeight.values) {
      styles.add(GoogleFonts.inter(fontWeight: weight));
      styles.add(GoogleFonts.plusJakartaSans(fontWeight: weight));
    }
    await GoogleFonts.pendingFonts(styles);
    // Restore normal asset loading once the font aliases have been consumed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
  tearDownAll(() {
    font_test.assetManifest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
  Map<String, dynamic> block(String type, {String? preset}) => {
        'id': 'block-$type',
        'type': type,
        'title': 'Custom $type heading',
        'body': 'Shop this weekend collection.',
        'presentation': type == 'categories'
            ? 'grid'
            : type == 'collection'
                ? 'row'
                : type == 'text'
                    ? 'plain'
                    : 'wide',
        if (type == 'collection')
          'tabId': (manifest['tabs'] as List).first['id'],
        if (type == 'image') 'image': 'chunri.svg',
        if (preset != null) 'motion': {'preset': preset, 'speed': 'normal'},
      };
  NavratriData data(List<Map<String, dynamic>> blocks) =>
      NavratriData.fromJson(fresh()
        ..['composition'] = 'blocks'
        ..['blocks'] = blocks);

  Future<void> mount(WidgetTester tester, NavratriData value,
      {double scale = 1,
      bool reduced = false,
      bool enabled = true,
      void Function(NavratriDestination)? navigate}) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 1000),
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced),
            child: TickerMode(
                enabled: enabled,
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: NavratriShoppingSection(
                            data: value,
                            catalog: const [],
                            onNavigate: navigate ?? (_) {})))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('legacy configuration keeps template mode', () {
    final old = NavratriData.fromJson(fresh());
    expect(old.composition, 'template');
    expect(old.blocks, isEmpty);
  });
  test(
      'pinned collections match the web selection and append only explicit keyword matches',
      () {
    final config = NavratriData.fromJson(fresh());
    Product item(String id) => Product.fromJson({
          'id': id,
          'name': 'Puja essentials',
          'slug': id,
          'price': 90,
          'mrp': 100,
          'stock': 10,
          'tags': ['puja']
        });
    final first = item('selected'), second = item('other');
    const pinned = NavratriTab(
        id: 'pinned',
        label: 'Pinned',
        image: 'chunri.svg',
        keywords: [],
        productIds: ['selected']);
    expect(
        config.filterProducts([second, first], pinned).map((item) => item.id),
        ['selected']);
    const extended = NavratriTab(
        id: 'extended',
        label: 'Extended',
        image: 'chunri.svg',
        keywords: ['puja'],
        productIds: ['selected']);
    expect(
        config.filterProducts([second, first], extended).map((item) => item.id),
        ['selected', 'other']);
  });
  test('unknown motion, references and blank compositions fail', () {
    final invalid = [
      <Map<String, dynamic>>[],
      [
        {
          ...block('banner'),
          'itemIds': ['missing']
        }
      ],
      [
        {...block('collection'), 'tabId': 'missing'}
      ],
      [
        {...block('image'), 'image': 'javascript:alert(1)'}
      ],
      [
        {...block('text'), 'title': '', 'body': ''}
      ],
      [block('banner', preset: 'unknown')],
      [
        {...block('banner'), 'enabled': false}
      ],
    ];
    for (final blocks in invalid) {
      expect(() => data(blocks), throwsFormatException);
    }
  });
  test('motion speeds stay inside existing interval bounds', () {
    expect(
        const CampaignMotion(speed: 'fast')
            .interval(const Duration(milliseconds: 2500))
            .inMilliseconds,
        1625);
    expect(
        const CampaignMotion(speed: 'fast')
            .interval(const Duration(milliseconds: 1500))
            .inMilliseconds,
        1500);
    expect(
        const CampaignMotion(speed: 'slow')
            .interval(const Duration(milliseconds: 60000))
            .inMilliseconds,
        60000);
  });
  test('live blocks require links for displayed slots only', () {
    final value = fresh()
      ..['demo'] = false
      ..['composition'] = 'blocks'
      ..['blocks'] = [block('image')];
    expect(NavratriData.fromJson(value).demo, isFalse);
    final slot = (value['products'] as List)[1] as Map;
    value['blocks'] = [
      {
        ...block('spotlight'),
        'itemIds': [slot['id']]
      }
    ];
    expect(() => NavratriData.fromJson(value), throwsFormatException);
    slot['productId'] = 'catalogue-sku';
    expect(NavratriData.fromJson(value).composition, 'blocks');
  });
  for (final type in [
    'banner',
    'categories',
    'spotlight',
    'collection',
    'image',
    'text'
  ]) {
    testWidgets('$type renders at 320px with enlarged text without overflow',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, data([block(type)]), scale: 2, reduced: true);
      expect(
          find.byKey(const ValueKey('campaign-block-canvas')), findsOneWidget);
      expect(find.text('Custom $type heading'),
          type == 'banner' ? findsNWidgets(2) : findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'block order, hidden content, search destination and selected items are respected',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NavratriDestination? destination;
    final configured = data([
      {
        ...block('text'),
        'destinationId': (manifest['destinations'] as List).first['id']
      },
      {...block('image'), 'enabled': false},
      {
        ...block('categories'),
        'itemIds': [(manifest['categories'] as List)[2]['id']]
      },
    ]);
    await mount(tester, configured,
        reduced: true, navigate: (value) => destination = value);
    expect(find.text('Custom image heading'), findsNothing);
    expect(find.text((manifest['categories'] as List)[0]['label'] as String),
        findsNothing);
    expect(tester.getTopLeft(find.text('Custom text heading')).dy,
        lessThan(tester.getTopLeft(find.text('Custom categories heading')).dy));
    await tester.tap(find.text('Browse collection'));
    expect(destination?.id, (manifest['destinations'] as List).first['id']);
    await tester.pumpWidget(const SizedBox());
  });
  for (final variant in [
    ['categories', 'row'],
    ['spotlight', 'offer'],
    ['collection', 'grid'],
  ]) {
    testWidgets('${variant[0]} ${variant[1]} presentation fits enlarged text',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(
          tester,
          data([
            {...block(variant[0]), 'presentation': variant[1]}
          ]),
          scale: 2,
          reduced: true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('composed campaign presents a complete native first viewport',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    final config = data([
      'banner',
      'spotlight',
      'categories',
      'collection',
      'image',
      'text'
    ].map((type) => block(type)).toList());
    const capture = ValueKey('native-campaign-capture');
    await tester.pumpWidget(RepaintBoundary(
        key: capture,
        child: MaterialApp(
            theme: ThemeData(fontFamily: 'Inter'),
            home: MediaQuery(
                data: const MediaQueryData(
                    size: Size(390, 1000), disableAnimations: true),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: NavratriShoppingSection(
                            data: config,
                            catalog: const [],
                            onNavigate: (_) {})))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Custom banner heading'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAMPAIGN_CAPTURE')) {
      await tester.runAsync(() => vg.waitForPendingDecodes());
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('../artifacts/campaign-builder')
            .create(recursive: true);
        await File('../artifacts/campaign-builder/flutter-mobile.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
  for (final preset in ['none', 'fade', 'slide', 'float', 'zoom', 'sparkle']) {
    testWidgets('$preset preserves geometry and disposes timers and tickers',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, data([block('spotlight', preset: preset)]));
      final box = find.byKey(const ValueKey('campaign-block-block-spotlight'));
      final before = tester.getRect(box);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(box), before);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
      expect(tester.takeException(), isNull);
    });
  }
  for (final preset in ['fade', 'slide']) {
    testWidgets('$preset enters static artwork and resets safely on pause',
        (tester) async {
      Future<void> show(
              {bool paused = false,
              bool reduced = false,
              String asset = 'first'}) =>
          tester.pumpWidget(MaterialApp(
              home: MediaQuery(
                  data: MediaQueryData(disableAnimations: reduced),
                  child: CampaignArtworkMotion(
                      motion: CampaignMotion(preset: preset),
                      paused: paused,
                      color: Colors.brown,
                      assetKey: asset,
                      child: const SizedBox(width: 100, height: 100)))));
      final motion = find.byType(CampaignArtworkMotion);
      double progress() => preset == 'fade'
          ? tester
              .widget<Opacity>(
                  find.descendant(of: motion, matching: find.byType(Opacity)))
              .opacity
          : tester
              .widget<Transform>(
                  find.descendant(of: motion, matching: find.byType(Transform)))
              .transform
              .storage[12];
      await show();
      await tester.pump();
      expect(progress(), preset == 'fade' ? lessThan(1) : greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = progress();
      expect(intermediate,
          preset == 'fade' ? inExclusiveRange(.7, 1) : inExclusiveRange(0, 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(progress(), preset == 'fade' ? 1 : 0);
      await show();
      expect(progress(), preset == 'fade' ? 1 : 0,
          reason: 'Unrelated rebuilds do not replay a completed entrance');
      await show(asset: 'replacement');
      await tester.pump();
      expect(progress(), preset == 'fade' ? lessThan(1) : greaterThan(0));
      await show(paused: true);
      expect(find.descendant(of: motion, matching: find.byType(Opacity)),
          findsNothing);
      expect(find.descendant(of: motion, matching: find.byType(Transform)),
          findsNothing);
      await show(reduced: true);
      expect(find.descendant(of: motion, matching: find.byType(Opacity)),
          findsNothing);
      expect(find.descendant(of: motion, matching: find.byType(Transform)),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
      expect(tester.takeException(), isNull);
    });
  }
  for (final preset in ['none', 'fade', 'slide', 'float', 'zoom', 'sparkle']) {
    testWidgets('live collection applies $preset only to product artwork',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      final photo = productPhoto;
      final product = Product.fromJson({
        'id': 'live-puja',
        'slug': 'live-puja',
        'name': 'Puja fruit basket',
        'price': 90,
        'mrp': 120,
        'stock': 20,
        'tags': ['pooja', 'decor'],
        'isAvailable': true,
        'unit': '1 piece',
        'imageUrl':
            'data:image/webp;base64,${base64Encode(photo.buffer.asUint8List(photo.offsetInBytes, photo.lengthInBytes))}',
      });
      final config = data([block('collection', preset: preset)]);
      const capture = ValueKey('native-live-collection-capture');
      await tester.pumpWidget(RepaintBoundary(
          key: capture,
          child: ProviderScope(
              overrides: [
                cartProvider.overrideWith((ref) => _CollectionCart()),
                wishlistProvider.overrideWith((ref) => _CollectionWishlist()),
                storeSettingsProvider
                    .overrideWith((ref) async => const StoreSettings()),
              ],
              child: MaterialApp(
                  theme: ThemeData(fontFamily: 'Inter'),
                  home: Scaffold(
                      body: SingleChildScrollView(
                          child: NavratriShoppingSection(
                              data: config,
                              catalog: [product],
                              onNavigate: (_) {})))))));
      await tester.pump();
      final artwork = find.byType(CampaignArtworkMotion);
      expect(artwork, findsOneWidget);
      expect(
          tester.widget<CampaignArtworkMotion>(artwork).motion.preset, preset);
      expect(find.descendant(of: artwork, matching: find.text(product.name)),
          findsNothing);
      final card = find.byType(ProductCard);
      final before = tester.getRect(card);
      final titleBefore = tester.getRect(find.text(product.name));
      await tester.pump(const Duration(milliseconds: 100));
      if (preset == 'fade') {
        expect(
            tester
                .widget<Opacity>(find.descendant(
                    of: artwork, matching: find.byType(Opacity)))
                .opacity,
            lessThan(1));
      } else if (preset == 'slide' || preset == 'float' || preset == 'zoom') {
        final transform = tester.widget<Transform>(
            find.descendant(of: artwork, matching: find.byType(Transform)));
        expect(
            preset == 'zoom'
                ? transform.transform.storage[0]
                : transform.transform.storage[preset == 'slide' ? 12 : 13],
            isNot(preset == 'zoom' ? 1 : 0));
      } else if (preset == 'sparkle') {
        expect(find.descendant(of: artwork, matching: find.byType(CustomPaint)),
            findsOneWidget);
      }
      expect(tester.getRect(card), before);
      expect(tester.getRect(find.text(product.name)), titleBefore);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.descendant(of: artwork, matching: find.byType(Transform)),
          findsNothing);
      expect(find.descendant(of: artwork, matching: find.byType(Opacity)),
          findsNothing);
      expect(find.descendant(of: artwork, matching: find.byType(CustomPaint)),
          findsNothing);
      expect(tester.takeException(), isNull);
      if (preset == 'zoom' && const bool.fromEnvironment('CAMPAIGN_CAPTURE')) {
        final photoWidget = tester.widget<Image>(
            find.descendant(of: artwork, matching: find.byType(Image)));
        await tester.runAsync(
            () => precacheImage(photoWidget.image, tester.element(artwork)));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '../artifacts/campaign-builder/flutter-live-collection.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'reduced motion and inactive ticker mode keep artwork and header stationary',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final configured = data([block('banner', preset: 'float')]);
    await mount(tester, configured, reduced: true);
    final first = find.byKey(
        ValueKey('block-header-${(manifest['headers'] as List).first['id']}'));
    expect(first, findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(first, findsOneWidget);
    await mount(tester, configured, enabled: false);
    await tester.pump(const Duration(seconds: 9));
    expect(first, findsOneWidget);
    expect(find.byType(CampaignArtworkMotion), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
