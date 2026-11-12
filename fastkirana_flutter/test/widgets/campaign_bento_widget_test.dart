import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fastminute_flutter/features/campaign_bento/campaign_bento_zone.dart';
import 'package:fastminute_flutter/providers/store_settings_provider.dart';
import 'package:fastminute_flutter/providers/product_provider.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/data/models/store_settings.dart';

void main() {
  testWidgets('CampaignBentoZone renders all 6 archetype zones without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockProducts = [
      Product(
        id: 'p1',
        name: 'Nivea Body Lotion Moisturizer',
        slug: 'nivea-body-lotion',
        description: 'Body lotion',
        imageUrl: '',
        mrp: 299,
        price: 199,
        discount: 33,
        unit: '200ml',
        stock: 20,
        isAvailable: true,
        tags: const ['lotion', 'body', 'moisturizer'],
        minStock: 1,
        costPrice: 150,
        isFlashDeal: false,
        isTopPick: true,
        isBestSeller: true,
        sortOrder: 1,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeSettingsProvider.overrideWith((ref) => Future.value(const StoreSettings())),
          homeProductCatalogProvider.overrideWith((ref) => Future.value(mockProducts)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampaignBentoZone(showLiveEditButton: true),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Section Header
    // Section title/subtitle headers are cleanly omitted for direct bento focus
    expect(find.byType(CampaignBentoZone), findsOneWidget);

    // Verify Archetypes matching 1:1 with Web Admin
    expect(find.text('Fresh Market'), findsWidgets);
    expect(find.text('Daily Restock'), findsOneWidget);
    expect(find.text('Value Picks'), findsOneWidget);
    expect(find.text('Gifting Boutique'), findsWidgets);
    expect(find.text('Movie Night'), findsOneWidget);
    expect(find.text('Breakfast Club'), findsOneWidget);

    // Verify Card Numbering is cleanly removed (no slide numbers)
    expect(find.text('01'), findsNothing);
    expect(find.text('02'), findsNothing);
    expect(find.text('03'), findsNothing);
    expect(find.text('04'), findsNothing);
    expect(find.text('05'), findsNothing);
    expect(find.text('06'), findsNothing);
  });
}
