import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/haptics/haptics.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/house_rules.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_notifier.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/telemetry/analytics.dart';

import 'haptics_test.dart'
    show clubsRun, heartsRun, run, spadesRun, twoOfDiamonds, winnableHand;

const c = PlayingCard.new;

/// Remembers every event it's asked to report, and every screen opened.
class RecordingAnalytics implements Analytics {
  final events = <String>[];
  final screens = <String?>[];

  @override
  void gameStarted({
    required GameMode mode,
    required int? stake,
    required BotDifficulty? difficulty,
  }) => events.add(
    'game_started ${mode.name} ${stake ?? 'none'} '
    '${difficulty?.name ?? 'none'}',
  );

  @override
  void roundFinished({required bool won, required bool sawJoker}) =>
      events.add('round_finished ${won ? 'won' : 'lost'} saw:$sawJoker');

  @override
  void gameQuitEarly() => events.add('game_quit_early');

  @override
  late final List<NavigatorObserver> navigatorObservers = [
    _ScreenRecorder(screens),
  ];
}

class _ScreenRecorder extends NavigatorObserver {
  _ScreenRecorder(this.screens);

  final List<String?> screens;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) screens.add(route.settings.name);
  }
}

/// A screen with one button that opens the table, so leaving it has
/// somewhere to go back to.
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      key: const Key('open-table'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'table'),
          builder: (_) => singlePlayerTable,
        ),
      ),
      child: const Text('Open'),
    ),
  );
}

Future<RecordingAnalytics> pumpTable(
  WidgetTester tester, {
  MatchSetup setup = quickPlaySetup,
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final analytics = RecordingAnalytics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsProvider.overrideWithValue(analytics),
        matchSetupProvider.overrideWith(() => _Fixed(setup)),
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        hapticsProvider.overrideWithValue(const SilentHaptics()),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2, mode: setup.rules.mode),
            random: Random(0),
            hands: [
              winnableHand,
              run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
            ],
            stock: [
              c(Suit.clubs, Rank.five),
              c(Suit.hearts, Rank.seven),
              c(Suit.clubs, Rank.two),
              c(Suit.diamonds, Rank.queen),
            ],
            discardPile: [c(Suit.clubs, Rank.king)],
            firstSeat: seat,
          ),
        ),
      ],
      child: const MarriageApp(home: _Launcher()),
    ),
  );
  await tester.tap(find.byKey(const Key('open-table')));
  await tester.pumpAndSettle();
  return analytics;
}

class _Fixed extends MatchSetupController {
  _Fixed(this.setup);

  final MatchSetup setup;

  @override
  MatchSetup build() => setup;
}

TableNotifier controllerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider.notifier);

int idOf(WidgetTester tester, PlayingCard card) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider).hand.firstWhere((h) => h.card == card).id;

/// Draws, shows three runs to see the joker and wins with 2♦.
Future<void> winRound(WidgetTester tester) async {
  final controller = controllerOf(tester)..draw(DrawSource.stock);
  for (final set in [heartsRun, spadesRun, clubsRun]) {
    for (final card in set) {
      controller.toggleSelected(idOf(tester, card));
    }
    controller.groupSelected();
  }
  controller
    ..showGroups()
    ..pickTiplu(1)
    ..dismissReveal()
    ..toggleSelected(idOf(tester, twoOfDiamonds))
    ..declareWin();
  await tester.pump();
}

void main() {
  testWidgets('a match reports its mode, stake table and bots as it starts', (
    tester,
  ) async {
    final analytics = await pumpTable(
      tester,
      setup: const MatchSetup(
        playerCount: 2,
        difficulty: BotDifficulty.hard,
        stake: 25,
        rules: HouseRules(mode: GameMode.kidnap),
      ),
    );

    expect(analytics.events, ['game_started kidnap 25 hard']);
  });

  testWidgets('away from the stake tables, the stake tier is none', (
    tester,
  ) async {
    final analytics = await pumpTable(tester);

    expect(analytics.events.single, startsWith('game_started standard none'));
  });

  testWidgets('a pass-and-play match has no bots to report', (tester) async {
    final analytics = await pumpTable(
      tester,
      setup: MatchSetup.passAndPlay(['Asha', 'Bina']),
    );

    expect(analytics.events, ['game_started standard none none']);
  });

  testWidgets('a won round is reported with the joker seen', (tester) async {
    final analytics = await pumpTable(tester);

    await winRound(tester);

    expect(analytics.events.last, 'round_finished won saw:true');
    await tester.pump(scoreboardDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('a round among friends on one device isn\'t reported', (
    tester,
  ) async {
    final analytics = await pumpTable(
      tester,
      setup: MatchSetup.passAndPlay(['Asha', 'Bina']),
    );
    controllerOf(tester).takeOver();
    await tester.pump();

    await winRound(tester);

    expect(analytics.events, isNot(contains(startsWith('round_finished'))));
    await tester.pump(scoreboardDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('leaving mid-round is reported as quitting early', (
    tester,
  ) async {
    final analytics = await pumpTable(tester);

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-confirm')));
    await tester.pumpAndSettle();

    expect(analytics.events.last, 'game_quit_early');
    expect(find.byType(TableScreen), findsNothing);
  });

  testWidgets('staying at the table reports nothing', (tester) async {
    final analytics = await pumpTable(tester);

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(analytics.events, isNot(contains('game_quit_early')));
  });

  testWidgets('leaving once the round is won isn\'t quitting early', (
    tester,
  ) async {
    final analytics = await pumpTable(tester);
    await winRound(tester);

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pump(scoreboardDelay);
    await tester.pumpAndSettle();

    expect(analytics.events, isNot(contains('game_quit_early')));
    expect(find.byType(TableScreen), findsNothing);
  });

  testWidgets('screens are reported by name as they open', (tester) async {
    final analytics = await pumpTable(tester);

    await winRound(tester);
    await tester.pump(scoreboardDelay);
    await tester.pumpAndSettle();

    expect(analytics.screens, containsAllInOrder(['table', 'scoreboard']));
  });
}
