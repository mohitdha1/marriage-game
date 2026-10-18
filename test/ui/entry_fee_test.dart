import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';
import 'package:marriage_game/ui/home/entry_fee.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/scoreboard/results_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/shop/shop_screen.dart';
import 'package:marriage_game/ui/state/house_rules.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/bots/bot_player.dart';

import 'analytics_test.dart' show pumpTable;
import 'home_screen_test.dart' show pumpHome;
import 'results_screen_test.dart' show containerOf, endMatchAfterWinning;

/// A player who has unlocked the 250 table, has the coins for it and last
/// chose it, with [gems] gems and their starting gems already given.
Map<String, Object> at250With({required int gems}) => {
  'lobby.stake': 250,
  'coins.balance': 50000,
  'stakes.gamesPlayed': '{"5": 50, "10": 50, "25": 75, "50": 75, "100": 100}',
  'gems.balance': gems,
  'gems.startingGiven': true,
};

final noon = DateTime(2026, 10, 17, 12);

/// The player's gems, as the app holds them.
int gemsOf(WidgetTester tester) =>
    containerOf(tester).read(playerDataProvider).value!.gems;

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('single-player')));
  await tester.pumpAndSettle();
}

void main() {
  test('the prompt names the fee, the ad while there is one, and the free '
      'tables', () {
    const ad = RewardedAd(
      coins: 1000,
      perDay: 5,
      length: Duration(seconds: 30),
    );

    expect(
      shortOfGemsText(stake: 2500, fee: 1, ad: ad, freeUpTo: 100),
      'The 2.5K table costs 1 gem a game. Get gems in the shop, or watch a '
      '30s ad to play this game free. Tables up to 100 a point are always '
      'free.',
    );
    expect(
      shortOfGemsText(stake: 250, fee: 2, ad: null, freeUpTo: 100),
      'The 250 table costs 2 gems a game. Get gems in the shop, or come back '
      'tomorrow for more ads. Tables up to 100 a point are always free.',
    );
  });

  group('The table picker', () {
    testWidgets('shows the gem fee on tables above 100 only', (tester) async {
      await pumpHome(tester, saved: at250With(gems: 3));
      await openPicker(tester);

      expect(find.byKey(const Key('stake-100-fee')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('stake-250-fee')),
          matching: find.text('1 gem'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('stake-summary'))).data,
        endsWith(' · 1 gem a game'),
      );
    });

    testWidgets('Play spends a gem and opens the table', (tester) async {
      final container = await pumpHome(tester, saved: at250With(gems: 3));
      await openPicker(tester);

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      expect(container.read(matchSetupProvider).stake, 250);
      expect(container.read(playerDataProvider).value!.gems, 2);
    });

    testWidgets('a free table spends no gems', (tester) async {
      final container = await pumpHome(
        tester,
        saved: {...at250With(gems: 0), 'lobby.stake': 100},
      );
      await openPicker(tester);

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      expect(find.byKey(const Key('short-of-gems')), findsNothing);
      expect(container.read(playerDataProvider).value!.gems, 0);
    });
  });

  group('Short of gems', () {
    testWidgets('a friendly prompt opens instead, and Not now stays on the '
        'picker', (tester) async {
      await pumpHome(tester, saved: at250With(gems: 0), clock: () => noon);
      await openPicker(tester);

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.text('Out of gems'), findsOneWidget);
      expect(find.byKey(const Key('gems-shop')), findsOneWidget);
      expect(find.byKey(const Key('gems-watch-ad')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gems-not-now')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(find.byKey(const Key('setup-play')), findsOneWidget);
    });

    testWidgets('a watched ad plays the game free, and pays no coins', (
      tester,
    ) async {
      final container = await pumpHome(
        tester,
        saved: at250With(gems: 0),
        clock: () => noon,
      );
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gems-watch-ad')));
      await tester.pumpAndSettle();
      expect(find.text('Test ad'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      final controller = container.read(playerDataProvider.notifier);
      expect(controller.adsLeftToday(), 4);
      expect(container.read(playerDataProvider).value!.coins, 50000);
      expect(container.read(playerDataProvider).value!.gems, 0);
    });

    testWidgets('an ad closed early starts nothing', (tester) async {
      final container = await pumpHome(
        tester,
        saved: at250With(gems: 0),
        clock: () => noon,
      );
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gems-watch-ad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(container.read(playerDataProvider.notifier).adsLeftToday(), 5);
    });

    testWidgets('with the day\'s ads used up, only the shop is offered', (
      tester,
    ) async {
      await pumpHome(
        tester,
        saved: {
          ...at250With(gems: 0),
          'ads.day': '2026-10-17',
          'ads.watched': 5,
        },
        clock: () => noon,
      );
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gems-watch-ad')), findsNothing);
      expect(find.textContaining('come back tomorrow'), findsOneWidget);
    });

    testWidgets('the shop opens, and coming back without gems starts nothing', (
      tester,
    ) async {
      await pumpHome(tester, saved: at250With(gems: 0), clock: () => noon);
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gems-shop')));
      await tester.pumpAndSettle();
      expect(find.byType(ShopScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(find.byKey(const Key('setup-play')), findsOneWidget);
    });

    testWidgets('gems got in the shop pay the fee on the way back', (
      tester,
    ) async {
      final container = await pumpHome(
        tester,
        saved: at250With(gems: 0),
        clock: () => noon,
      );
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gems-shop')));
      await tester.pumpAndSettle();

      await container.read(playerDataProvider.notifier).addGems(10);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      expect(container.read(playerDataProvider).value!.gems, 9);
    });
  });

  testWidgets('Quick Play names the fee, and charges it', (tester) async {
    final container = await pumpHome(tester, saved: at250With(gems: 1));
    expect(find.text('4 bots · Medium · 250 table · 1 gem'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();

    expect(find.byType(TableScreen), findsOneWidget);
    expect(container.read(playerDataProvider).value!.gems, 0);
  });

  group('A rematch', () {
    const at250 = MatchSetup(
      playerCount: 2,
      difficulty: BotDifficulty.medium,
      stake: 250,
      rules: HouseRules(mode: GameMode.standard),
    );

    Future<void> pumpAt250(WidgetTester tester, {required int gems}) =>
        pumpTable(
          tester,
          setup: at250,
          overrides: [
            preferencesProvider.overrideWithValue(
              InMemoryPreferences({
                'gems.balance': gems,
                'gems.startingGiven': true,
              }),
            ),
            economyConfigProvider.overrideWith(
              (ref) => EconomyConfig.fromJson(
                File(EconomyConfig.asset).readAsStringSync(),
              ),
            ),
            clockProvider.overrideWithValue(() => noon),
          ],
        );

    testWidgets('costs a gem, like any new match', (tester) async {
      await pumpAt250(tester, gems: 1);
      await endMatchAfterWinning(tester);

      await tester.tap(find.byKey(const Key('rematch')));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsScreen), findsNothing);
      expect(gemsOf(tester), 0);
    });

    testWidgets('short of gems, stays on the results until paid', (
      tester,
    ) async {
      await pumpAt250(tester, gems: 0);
      await endMatchAfterWinning(tester);

      await tester.tap(find.byKey(const Key('rematch')));
      await tester.pumpAndSettle();
      expect(find.text('Out of gems'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gems-not-now')));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(containerOf(tester).read(tableProvider).roundScores, isNotEmpty);
    });
  });
}
