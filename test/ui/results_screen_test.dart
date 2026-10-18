import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/ui/scoreboard/results_screen.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/state/house_rules.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

import 'analytics_test.dart' show pumpTable, winRound;

const atStakeTable = MatchSetup(
  playerCount: 2,
  difficulty: BotDifficulty.hard,
  stake: 25,
  rules: HouseRules(mode: GameMode.kidnap, manCards: true),
);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

/// Wins a round at [atStakeTable], then ends the match from the scoreboard.
/// Returns the engine's summary of the match, taken just before it ended.
Future<MatchSummary> endMatchAfterWinning(WidgetTester tester) async {
  await winRound(tester);
  await tester.pump(scoreboardDelay); // the scoreboard opens
  await tester.pumpAndSettle();
  final summary = MatchSummary(
    containerOf(tester).read(tableProvider).roundScores,
  );

  await tester.tap(find.byKey(const Key('end-match')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('end-match-confirm')));
  await tester.pumpAndSettle();
  return summary;
}

void main() {
  group('the results of a match', () {
    testWidgets('End match shows the winner and the engine\'s summary', (
      tester,
    ) async {
      await pumpTable(tester, setup: atStakeTable);

      final summary = await endMatchAfterWinning(tester);

      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.byType(ScoreboardScreen), findsNothing);
      expect(find.text('You win the match!'), findsOneWidget);
      expect(textOf(tester, 'rounds-played'), 'Rounds played: 1');
      expect(
        textOf(tester, 'your-result'),
        'Coins: ${signed(summary.coinsOf(0, 25))}',
      );
      expect(summary.coinsOf(0, 25), summary.totals[0] * 25);
      expect(
        textOf(tester, 'best-round'),
        'Your best round: ${signed(summary.totals[0])} in round 1',
      );
      expect(textOf(tester, 'standing-0'), signed(summary.totals[0]));
      expect(textOf(tester, 'standing-1'), signed(summary.totals[1]));
    });

    testWidgets('Rematch starts afresh at the same table, with the same rules '
        'and bots', (tester) async {
      final analytics = await pumpTable(tester, setup: atStakeTable);
      final names = containerOf(tester).read(tableProvider).seatNames;
      await endMatchAfterWinning(tester);

      await tester.tap(find.byKey(const Key('rematch')));
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      final state = container.read(tableProvider);
      final controller = container.read(tableProvider.notifier);
      expect(find.byType(ResultsScreen), findsNothing);
      expect(find.byType(TableScreen), findsOneWidget);
      expect(state.roundScores, isEmpty);
      expect(state.view.winner, isNull);
      expect(state.seatNames, names);
      expect(controller.stake, 25);
      expect(controller.mode, GameMode.kidnap);
      final setup = container.read(matchSetupProvider);
      expect(setup.stake, 25);
      expect(setup.difficulty, BotDifficulty.hard);
      expect(setup.rules, atStakeTable.rules);
      expect(analytics.events.where((e) => e.startsWith('game_started')), [
        'game_started kidnap 25 hard',
        'game_started kidnap 25 hard',
      ]);
    });

    testWidgets('on a small phone held sideways, the banner covers nothing '
        'and both buttons show without scrolling', (tester) async {
      await pumpTable(tester, setup: atStakeTable);
      await endMatchAfterWinning(tester);
      tester.view.physicalSize = const Size(667, 375);
      await tester.pumpAndSettle();

      final banner = tester.getRect(find.byKey(const Key('win-banner')));
      for (final key in ['rounds-played', 'your-result', 'best-round']) {
        expect(
          banner.overlaps(tester.getRect(find.byKey(Key(key)))),
          isFalse,
          reason: key,
        );
      }
      final screen = Offset.zero & const Size(667, 375);
      for (final key in ['rematch', 'results-home']) {
        final button = tester.getRect(find.byKey(Key(key)));
        expect(screen.contains(button.bottomRight), isTrue, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home goes back to the home screen', (tester) async {
      await pumpTable(tester, setup: atStakeTable);
      await endMatchAfterWinning(tester);

      await tester.tap(find.byKey(const Key('results-home')));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsScreen), findsNothing);
      expect(find.byType(TableScreen), findsNothing);
      expect(find.byKey(const Key('open-table')), findsOneWidget);
    });

    testWidgets('Back goes home too', (tester) async {
      await pumpTable(tester, setup: atStakeTable);
      await endMatchAfterWinning(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(find.byKey(const Key('open-table')), findsOneWidget);
    });
  });

  group('winnerTitle', () {
    RoundScore round(List<int> net) => RoundScore(
      winner: 0,
      maal: [for (final _ in net) const MaalBreakdown()],
      net: net,
    );
    const names = ['You', 'Asha', 'Bina'];

    test('names the winner, or says you won', () {
      final summary = MatchSummary([
        round([-5, 10, -5]),
      ]);
      expect(
        winnerTitle(summary, names: names, you: 0),
        'Asha wins the match!',
      );
      expect(winnerTitle(summary, names: names, you: 1), 'You win the match!');
    });

    test('a tie names everyone who shares the top', () {
      final summary = MatchSummary([
        round([5, 5, -10]),
      ]);
      expect(
        winnerTitle(summary, names: names, you: 2),
        'You and Asha tie for the win!',
      );
      expect(
        winnerTitle(summary, names: names, you: 0),
        'You tie for the win!',
      );
      expect(
        winnerTitle(
          MatchSummary([
            round([0, 0, 0]),
          ]),
          names: names,
        ),
        'You, Asha and Bina tie for the win!',
      );
    });
  });

  group('summaryLines', () {
    final summary = MatchSummary([
      RoundScore(
        winner: 0,
        maal: const [MaalBreakdown(), MaalBreakdown()],
        net: const [20, -20],
      ),
      RoundScore(
        winner: 1,
        maal: const [MaalBreakdown(), MaalBreakdown()],
        net: const [-3, 3],
      ),
    ]);
    const names = ['You', 'Asha'];

    test('at a stake table: rounds, coins and your best round', () {
      expect(summaryLines(summary, names: names, you: 0, stake: 10), [
        ('rounds-played', 'Rounds played: 2'),
        ('your-result', 'Coins: +170'),
        ('best-round', 'Your best round: +20 in round 1'),
      ]);
    });

    test('without a stake: points instead of coins', () {
      expect(summaryLines(summary, names: names, you: 1)[1], (
        'your-result',
        'Points: −17',
      ));
    });

    test('on a shared device: the best round anyone had', () {
      expect(summaryLines(summary, names: names, you: 0, sharesDevice: true), [
        ('rounds-played', 'Rounds played: 2'),
        ('best-round', 'Best round: You, +20 in round 1'),
      ]);
    });
  });
}
