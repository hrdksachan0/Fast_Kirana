import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/utils/app_connectivity.dart';
import 'package:fastkirana_flutter/widgets/offline_banner.dart';
import 'offline_experience_test.dart' show TestConnection;

void main() {
  testWidgets('OfflineBanner displays full text without truncation in offline and online recovery states', (tester) async {
    final connection = TestConnection()..online = false;
    var retryCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => connection),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineText: 'Offline • Cart saved locally',
              onlineText: 'Back Online • Cart synced',
              onRetry: () => retryCalls++,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify offline banner texts are fully rendered without ellipsis
    final offlineTitleFinder = find.text('Offline • Cart saved locally');
    expect(offlineTitleFinder, findsOneWidget);
    final Text offlineTitleWidget = tester.widget(offlineTitleFinder);
    expect(offlineTitleWidget.overflow, isNot(TextOverflow.ellipsis));
    expect(offlineTitleWidget.maxLines, isNull);

    final offlineSubtitleFinder = find.text('Items added to cart will sync as soon as you reconnect.');
    expect(offlineSubtitleFinder, findsOneWidget);
    final Text offlineSubtitleWidget = tester.widget(offlineSubtitleFinder);
    expect(offlineSubtitleWidget.overflow, isNot(TextOverflow.ellipsis));
    expect(offlineSubtitleWidget.maxLines, isNull);

    // Tap retry
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retryCalls, 1);

    // Transition to online state ("jab internet aa jata hai")
    connection.reconnect();
    await tester.pumpAndSettle();

    // Verify online banner appears and is not truncated
    final onlineTitleFinder = find.text('Back Online • Cart synced');
    expect(onlineTitleFinder, findsOneWidget);
    final Text onlineTitleWidget = tester.widget(onlineTitleFinder);
    expect(onlineTitleWidget.overflow, isNot(TextOverflow.ellipsis));
    expect(onlineTitleWidget.maxLines, isNull);

    final onlineSubtitleFinder = find.text('Your cart and live prices are verified and up to date.');
    expect(onlineSubtitleFinder, findsOneWidget);
    final Text onlineSubtitleWidget = tester.widget(onlineSubtitleFinder);
    expect(onlineSubtitleWidget.overflow, isNot(TextOverflow.ellipsis));
    expect(onlineSubtitleWidget.maxLines, isNull);
  });
}
