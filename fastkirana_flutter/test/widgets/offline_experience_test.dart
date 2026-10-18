import 'dart:io';
import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/core/utils/app_connectivity.dart';
import 'package:fastminute_flutter/data/models/cart.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/data/repositories/cart_repository.dart';
import 'package:fastminute_flutter/features/offline/offline_zero_signal_screen.dart';
import 'package:fastminute_flutter/providers/cart_provider.dart';
import 'package:fastminute_flutter/widgets/zepto_connectivity_pill.dart';

class TestConnection extends ChangeNotifier implements AppConnectivityObserver {
  bool online = false;
  bool fail = false;
  @override
  bool get isOnline => online;
  @override
  bool get isWifi => online;
  @override
  bool get isMobileData => false;
  @override
  List<ConnectivityResult> get results =>
      [online ? ConnectivityResult.wifi : ConnectivityResult.none];
  @override
  Future<bool> checkConnection() async {
    if (fail) throw StateError('platform unavailable');
    return online;
  }

  void reconnect() {
    online = true;
    notifyListeners();
  }
}

class TestCartRepository extends CartRepository {
  List<CartItem> stored;
  TestCartRepository(this.stored) : super(Dio());
  @override
  Future<List<CartItem>> getLocalCart() async => stored;
}

class TestCartNotifier extends CartNotifier {
  TestCartNotifier(super.repository, Cart cart) {
    state = AsyncData(cart);
  }
  @override
  Future<void> loadCart([CartRepository? repo]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> render(WidgetTester tester, Widget child,
      {int saved = 0,
      double scale = 1,
      Size size = const Size(320, 480),
      TestConnection? connection,
      GlobalKey? previewKey}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          connectivityProvider
              .overrideWith((ref) => connection ?? TestConnection()),
          savedOfflineCartCountProvider.overrideWith((ref) async => saved),
        ],
        child: RepaintBoundary(
            key: previewKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'Inter',
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: const Color(0xFFE20A22))
                          .copyWith(surface: Colors.white)),
              builder: (context, content) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: content!),
              home: child,
            ))));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/offline-previews')
        ..createSync(recursive: true);
      File('${dir.path}/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Offline layout preview on a standard phone', (tester) async {
    final key = GlobalKey();
    await render(tester, const OfflineZeroSignalScreen(),
        saved: 3, size: const Size(390, 760), previewKey: key);
    expect(tester.takeException(), isNull);
    await preview(tester, key, 'offline-phone');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'Offline screen wraps and scrolls at 320px with text scale $scale',
        (tester) async {
      final key = GlobalKey();
      await render(tester, const OfflineZeroSignalScreen(),
          saved: 123, scale: scale, previewKey: key);
      expect(tester.takeException(), isNull);
      expect(
          find.text(
              'Your cart is saved on this device.\nReconnect to continue shopping.'),
          findsOneWidget);
      await tester.ensureVisible(find.text('View saved cart · 123 items'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1) await preview(tester, key, 'offline-320');
    });
    testWidgets('Connection notice has no truncated text at scale $scale',
        (tester) async {
      await render(tester,
          const Scaffold(body: Stack(children: [ZeptoConnectivityPill()])),
          scale: scale);
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('You’re offline'));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48));
    });
  }

  testWidgets(
      'Unconfirmed cart makes no saved promise; failed retry remains usable',
      (tester) async {
    final connection = TestConnection()..fail = true;
    await render(tester, const OfflineZeroSignalScreen(),
        connection: connection);
    expect(find.textContaining('Your cart is saved'), findsNothing);
    expect(find.textContaining('View saved cart'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to check. Please try again.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reconnection returns once to shopping', (tester) async {
    final connection = TestConnection();
    var recoveries = 0;
    await render(tester, OfflineZeroSignalScreen(onRetry: () => recoveries++),
        connection: connection);
    connection.reconnect();
    await tester.pumpAndSettle();
    await tester.pump();
    expect(recoveries, 1);
    expect(tester.takeException(), isNull);
  });

  test('Saved confirmation requires matching persisted cart contents',
      () async {
    final product = Product.fromJson({'id': 'p1', 'name': 'Milk', 'price': 30});
    final item = CartItem(
        id: 'i1', cartId: 'c1', productId: 'p1', product: product, quantity: 2);
    final cart = Cart.empty().copyWith(items: [item]);
    final repo = TestCartRepository([item]);
    final container = ProviderContainer(overrides: [
      cartRepoProvider.overrideWithValue(repo),
      cartProvider.overrideWith((ref) => TestCartNotifier(repo, cart)),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(savedOfflineCartCountProvider, (_, next) {});
    addTearDown(subscription.close);
    expect(await container.read(savedOfflineCartCountProvider.future), 2);
    repo.stored = [item.copyWith(quantity: 1)];
    container.invalidate(savedOfflineCartCountProvider);
    expect(await container.read(savedOfflineCartCountProvider.future), 0);
  });
}
