import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/core/services/location_service.dart';
import 'package:fastminute_flutter/core/theme/responsive.dart';
import 'package:fastminute_flutter/data/models/category.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/features/categories/category_products_screen.dart';
import 'package:fastminute_flutter/providers/product_provider.dart';
import 'package:fastminute_flutter/providers/store_hub_provider.dart';
import 'package:fastminute_flutter/data/models/store_hub.dart';
import 'package:fastminute_flutter/features/delivery/widgets/doorstep_cashfree_qr_sheet.dart';
import 'package:fastminute_flutter/widgets/product/product_quantity_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sentry crash regression fixes', () {
    testWidgets(
      'Responsive.scaledFontSize never throws ArgumentError for baseSize < 11 on <360dp width',
      (tester) async {
        late double s85, s95, s105, s11, s13, s16, s0;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)),
            child: Builder(
              builder: (context) {
                s85 = Responsive.scaledFontSize(context, 8.5);
                s95 = Responsive.scaledFontSize(context, 9.5);
                s105 = Responsive.scaledFontSize(context, 10.5);
                s11 = Responsive.scaledFontSize(context, 11.0);
                s13 = Responsive.scaledFontSize(context, 13.0);
                s16 = Responsive.scaledFontSize(context, 16.0);
                s0 = Responsive.scaledFontSize(context, 0.0);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(s85, 8.5);
        expect(s95, 9.5);
        expect(s105, 10.5);
        expect(s11, 11.0);
        expect(s13, 13.0);
        expect(s16, closeTo(15.36, 0.01));
        expect(s0, 0.0);
      },
    );

    testWidgets(
      'VariantPill handles ProductVariant without NoSuchMethodError',
      (tester) async {
        final variant = ProductVariant(
          name: '500 ml',
          price: 45,
          mrp: 50,
          stock: 10,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VariantPill(
                product: variant,
                variants: const [],
                hasVariants: false,
                isOutOfStock: false,
                isFood: false,
                uiScale: 1.0,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('500 ml'), findsOneWidget);
      },
    );

    testWidgets(
      'CategoryProductsScreen handles subcategory switches during AnimatedSwitcher without Too many elements StateError',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const parentCat = Category(
          id: 'CAT-101',
          name: 'Fruits & Vegetables',
          slug: 'fruits-vegetables',
          sortOrder: 1,
        );
        const subCat1 = Category(
          id: 'SUB-101-01',
          name: 'Fresh Fruits',
          slug: 'fresh-fruits',
          parentId: 'CAT-101',
          sortOrder: 1,
        );
        const subCat2 = Category(
          id: 'SUB-101-02',
          name: 'Fresh Vegetables',
          slug: 'fresh-vegetables',
          parentId: 'CAT-101',
          sortOrder: 2,
        );

        final products = List.generate(
          20,
          (i) => Product(
            id: 'prod_$i',
            name: 'Fresh Item $i',
            slug: 'fresh-item-$i',
            categoryId: i.isEven ? 'SUB-101-01' : 'SUB-101-02',
            mrp: 100,
            price: 80,
            discount: 20,
            unit: '500 g',
            stock: 10,
            isAvailable: true,
            tags: const ['fresh'],
            minStock: 1,
            costPrice: 60,
            isFlashDeal: false,
            isTopPick: false,
            isBestSeller: false,
            sortOrder: i,
            createdAt: DateTime(2026),
          ),
        );

        final originalOnError = FlutterError.onError;
        final nonLayoutErrors = <Object>[];
        FlutterError.onError = (FlutterErrorDetails details) {
          final msg = details.exceptionAsString();
          if (!msg.contains('RenderFlex overflowed')) {
            nonLayoutErrors.add(details.exception);
          }
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentStoreHubProvider.overrideWithValue(StoreHub.defaultGhatampur),
              categoriesProvider.overrideWith((ref) => Future.value(const [parentCat, subCat1, subCat2])),
              productsProvider.overrideWith((ref, key) => Future.value(products)),
              homeProductCatalogProvider.overrideWith((ref) => Future.value(products)),
            ],
            child: const MaterialApp(
              home: CategoryProductsScreen(category: parentCat),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Scroll down to attach ScrollPosition, then rapidly switch subcategory
        // while AnimatedSwitcher keeps outgoing + incoming CustomScrollView alive.
        final scrollable = find.byType(CustomScrollView).first;
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump();

        await tester.tap(find.text('Fresh Fruits'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Fresh Vegetables'));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpAndSettle();
        expect(nonLayoutErrors, isEmpty);
      },
    );

    test('LocationService.isLocationServiceEnabledSafe never throws without platform plugin', () async {
      final result = await LocationService.isLocationServiceEnabledSafe();
      expect(result, isA<bool>());
    });

    testWidgets(
      'DoorstepCashfreeQrSheet hides Normal UPI tab and manual Confirm Customer Paid button',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DoorstepCashfreeQrSheet(
                    order: const {'id': 'ord_1', 'readableId': 'FK-101', 'total': 250},
                    orderId: 'ord_1',
                    orderNum: 'FK-101',
                    total: 250,
                    onConfirmPaid: (_) async {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Normal UPI 🏦'), findsNothing);
        expect(find.textContaining('Confirm Customer Paid'), findsNothing);
        expect(find.textContaining('Switch to Normal UPI'), findsNothing);
      },
    );
  });
}
