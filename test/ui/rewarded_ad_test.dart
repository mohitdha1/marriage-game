import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/ui/ads/rewarded_ad_service.dart';
import 'package:marriage_game/ui/ads/watch_ad.dart';

import 'home_screen_test.dart' show pumpHome;

final noon = DateTime(2026, 10, 17, 12);

/// Collects the hourly gift on the home screen, which offers an ad while
/// there are any left today.
Future<void> collectGift(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hourly-gift')));
  await tester.pump();
  await tester.pump();
}

/// A screen with a button that shows the test ad and keeps the result.
class _AdLauncher extends StatelessWidget {
  const _AdLauncher(this.onResult);

  final void Function(bool) onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () async =>
          onResult(await const FakeRewardedAdService().show(context)),
      child: const Text('Show ad'),
    ),
  );
}

void main() {
  group('The test ad', () {
    testWidgets('pays out after 3 seconds', (tester) async {
      bool? watched;
      await tester.pumpWidget(
        MaterialApp(home: _AdLauncher((result) => watched = result)),
      );
      await tester.tap(find.text('Show ad'));
      await tester.pumpAndSettle();
      expect(find.text('Test ad'), findsOneWidget);
      expect(find.text('Reward in 3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(watched, isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(watched, isTrue);
      expect(find.text('Test ad'), findsNothing);
    });

    testWidgets('closed early, it pays nothing', (tester) async {
      bool? watched;
      await tester.pumpWidget(
        MaterialApp(home: _AdLauncher((result) => watched = result)),
      );
      await tester.tap(find.text('Show ad'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(watched, isFalse);
    });
  });

  group('After the hourly gift', () {
    testWidgets('an ad is offered, and watching it pays 1,000 coins', (
      tester,
    ) async {
      await pumpHome(tester, clock: () => noon);
      await collectGift(tester);

      expect(
        find.text('Want more? Watch a 30s ad for 1,000 coins (5 left today).'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('gift-watch-ad')));
      await tester.pumpAndSettle();
      expect(find.text('Test ad'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('+1,000 coins'), findsOneWidget);
      // 10,000 to start, 500 from the gift and 1,000 from the ad.
      expect(find.text('11,500'), findsOneWidget);
    });

    testWidgets('No thanks shows no ad', (tester) async {
      await pumpHome(tester, clock: () => noon);
      await collectGift(tester);

      await tester.tap(find.byKey(const Key('gift-no-ad')));
      await tester.pumpAndSettle();

      expect(find.text('Test ad'), findsNothing);
      expect(find.text('10,500'), findsOneWidget);
    });

    testWidgets('an ad closed early pays nothing', (tester) async {
      await pumpHome(tester, clock: () => noon);
      await collectGift(tester);
      await tester.tap(find.byKey(const Key('gift-watch-ad')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ad-reward')), findsNothing);
      expect(find.text('10,500'), findsOneWidget);
    });

    testWidgets('once the day\'s 5 ads are used, none is offered', (
      tester,
    ) async {
      await pumpHome(
        tester,
        clock: () => noon,
        saved: {'ads.day': '2026-10-17', 'ads.watched': 5},
      );
      await collectGift(tester);

      expect(find.byKey(const Key('gift-watch-ad')), findsNothing);
      expect(find.text('+500 coins'), findsOneWidget);
    });

    testWidgets('a new day brings the ads back', (tester) async {
      await pumpHome(
        tester,
        clock: () => noon,
        saved: {'ads.day': '2026-10-16', 'ads.watched': 5},
      );
      await collectGift(tester);

      expect(find.byKey(const Key('gift-watch-ad')), findsOneWidget);
    });
  });

  test('the offer names the ad\'s length and coins', () {
    const ad = RewardedAd(
      coins: 2500,
      perDay: 3,
      length: Duration(seconds: 15),
    );

    expect(adOfferText(ad), 'Watch a 15s ad for 2,500 coins');
    expect(adsLeftText(3), '3 left today');
  });

  test('no ads during a hand: nothing at the table can reach the ad code', () {
    // The table screen and the game state never import the ads, so no hand
    // can be interrupted by one.
    final atTheTable = [
      ...Directory('lib/ui/table').listSync(recursive: true),
      ...Directory('lib/ui/state').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in atTheTable) {
      expect(
        file.readAsStringSync(),
        isNot(contains('ads/')),
        reason: '${file.path} must not reach the ads',
      );
    }
  });
}
