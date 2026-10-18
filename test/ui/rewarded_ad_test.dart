import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/ui/ads/rewarded_ad_service.dart';
import 'package:marriage_game/ui/ads/watch_ad.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/settings/preferences.dart';

final noon = DateTime(2026, 10, 17, 12);

/// Stands in for an ad network with nothing to show.
class _NoAds implements RewardedAdService {
  const _NoAds();

  @override
  Future<AdResult> show(BuildContext context) async => AdResult.unavailable;
}

/// A screen with a Watch button that offers an ad for coins, at noon, with
/// the app's own amounts. Returns the providers' container.
Future<ProviderContainer> pumpAdHost(
  WidgetTester tester, {
  Map<String, Object>? saved,
  RewardedAdService ads = const FakeRewardedAdService(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(InMemoryPreferences(saved)),
        economyConfigProvider.overrideWith(
          (ref) => EconomyConfig.fromJson(
            File(EconomyConfig.asset).readAsStringSync(),
          ),
        ),
        clockProvider.overrideWithValue(() => noon),
        rewardedAdServiceProvider.overrideWithValue(ads),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => watchAdForCoins(context, ref),
              child: const Text('Watch'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.text('Watch')),
  );
  await container.read(playerDataProvider.future);
  return container;
}

/// A screen with a button that shows the test ad and keeps the result.
class _AdLauncher extends StatelessWidget {
  const _AdLauncher(this.onResult);

  final void Function(AdResult) onResult;

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
      AdResult? watched;
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

      expect(watched, AdResult.watched);
      expect(find.text('Test ad'), findsNothing);
    });

    testWidgets('closed early, it pays nothing', (tester) async {
      AdResult? watched;
      await tester.pumpWidget(
        MaterialApp(home: _AdLauncher((result) => watched = result)),
      );
      await tester.tap(find.text('Show ad'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(watched, AdResult.skipped);
    });
  });

  group('Watching an ad for coins', () {
    testWidgets('pays 1,000 coins once watched to the end', (tester) async {
      final container = await pumpAdHost(tester);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Test ad'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('+1,000 coins'), findsOneWidget);
      expect(container.read(playerDataProvider).value!.coins, 11000);
    });

    testWidgets('closed early, pays nothing', (tester) async {
      final container = await pumpAdHost(tester);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ad-reward')), findsNothing);
      expect(container.read(playerDataProvider).value!.coins, 10000);
      expect(container.read(playerDataProvider.notifier).adsLeftToday(), 5);
    });

    testWidgets('with no ad to show, says so and pays nothing', (tester) async {
      final container = await pumpAdHost(tester, ads: const _NoAds());
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();

      expect(find.text(noAdText), findsOneWidget);
      expect(container.read(playerDataProvider).value!.coins, 10000);
    });

    testWidgets('once the day\'s 5 ads are used, says to come back '
        'tomorrow', (tester) async {
      await pumpAdHost(
        tester,
        saved: {'ads.day': '2026-10-17', 'ads.watched': 5},
      );
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();

      expect(find.text('Test ad'), findsNothing);
      expect(find.text(noAdsLeftText), findsOneWidget);
    });

    testWidgets('a new day brings the ads back', (tester) async {
      final container = await pumpAdHost(
        tester,
        saved: {'ads.day': '2026-10-16', 'ads.watched': 5},
      );

      expect(container.read(playerDataProvider.notifier).adsLeftToday(), 5);
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
