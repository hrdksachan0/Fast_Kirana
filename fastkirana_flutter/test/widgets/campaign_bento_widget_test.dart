import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fastminute_flutter/features/campaign_bento/campaign_bento_zone.dart';
import 'package:fastminute_flutter/providers/store_settings_provider.dart';
import 'package:fastminute_flutter/data/models/store_settings.dart';

void main() {
  testWidgets('CampaignBentoZone renders all 6 archetype zones without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeSettingsProvider.overrideWith((ref) => Future.value(const StoreSettings())),
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
    expect(find.text('Featured Zones'), findsOneWidget);

    // Verify Archetypes
    expect(find.text('bloom'), findsOneWidget);
    expect(find.text('See All'), findsWidgets);
    expect(find.text('The Seasonal Switch-Up'), findsOneWidget);
    expect(find.text('See all products'), findsOneWidget);
    expect(find.text('Value Picks'), findsOneWidget);
    expect(find.text('Gifting Boutique'), findsOneWidget);
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
