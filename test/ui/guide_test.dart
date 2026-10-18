import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/guide/guide.dart';
import 'package:marriage_game/ui/guide/table_guide.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/settings/how_to_play_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);

/// Three runs and some loose cards; after drawing Q♦ the runs can be shown,
/// with 7♥ picked as the tiplu.
final yourCards = [
  ...heartsRun,
  ...spadesRun,
  ...clubsRun,
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.two),
];

Round dealKnownCards(int seat) => Round.fromCards(
  config: GameConfig(playerCount: 2),
  random: Random(0),
  hands: [
    yourCards,
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
);

ProviderContainer containerWith([Map<String, Object>? saved]) {
  final container = ProviderContainer(
    overrides: [
      preferencesProvider.overrideWithValue(InMemoryPreferences(saved)),
      randomProvider.overrideWithValue(Random(0)),
      botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
      roundFactoryProvider.overrideWithValue(dealKnownCards),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> pumpTable(
  WidgetTester tester, {
  Map<String, Object>? saved,
  Duration thinkingTime = Duration.zero,
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(InMemoryPreferences(saved)),
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => thinkingTime),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        roundFactoryProvider.overrideWithValue(dealKnownCards),
      ],
      child: const MarriageApp(home: singlePlayerTable),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(TableScreen)));
}

void main() {
  group('Which tip shows', () {
    GuideStep? stepOf(ProviderContainer container, Set<GuideStep> done) =>
        guideStepFor(container.read(tableProvider), done);

    test('a new player is first told to draw', () {
      expect(stepOf(containerWith(), {}), GuideStep.draw);
    });

    test('once drawn, how to discard', () {
      final container = containerWith();
      container.read(tableProvider.notifier).draw(DrawSource.stock);

      expect(stepOf(container, {GuideStep.draw}), GuideStep.discard);
    });

    test('the draw tip doesn\'t show for a card already drawn', () {
      final container = containerWith();
      container.read(tableProvider.notifier).draw(DrawSource.stock);

      expect(stepOf(container, {}), isNull);
    });

    test('after a first draw and discard, how to make sets', () {
      expect(
        stepOf(containerWith(), {GuideStep.draw, GuideStep.discard}),
        GuideStep.sets,
      );
    });

    test('the joker tip waits until the joker has been seen', () async {
      final done = {GuideStep.draw, GuideStep.discard, GuideStep.sets};
      final container = containerWith();
      expect(stepOf(container, done), isNull);

      final controller = container.read(tableProvider.notifier)
        ..draw(DrawSource.stock);
      for (final run in [heartsRun, spadesRun, clubsRun]) {
        for (final card in run) {
          controller.toggleSelected(
            container
                .read(tableProvider)
                .hand
                .firstWhere((h) => h.card == card)
                .id,
          );
        }
        controller.groupSelected();
      }
      controller.showGroups();
      expect(
        stepOf(container, done),
        isNull,
        reason: 'not seen until the discard',
      );

      final spare = container.read(tableProvider).hand.last.id;
      await controller.discard(spare);
      expect(stepOf(container, done), isNull, reason: 'picking the tiplu');

      controller.pickTiplu(1);
      expect(stepOf(container, done), isNull, reason: 'the reveal is open');

      controller.dismissReveal();
      expect(stepOf(container, done), isNull, reason: "the bot's turn");

      await controller.botsSettled;
      expect(stepOf(container, done), GuideStep.joker);
    });

    test('nothing shows on someone else\'s turn', () async {
      final container = containerWith();
      final controller = container.read(tableProvider.notifier)
        ..draw(DrawSource.stock);
      // Straight after the discard, before the bot has had its turn.
      unawaited(
        controller.discard(
          container
              .read(tableProvider)
              .hand
              .firstWhere((h) => h.card == c(Suit.spades, Rank.king))
              .id,
        ),
      );
      expect(container.read(tableProvider).view.isYourTurn, isFalse);
      expect(stepOf(container, {GuideStep.draw}), isNull);
      await controller.botsSettled;
    });

    test('nothing more once every tip is done', () {
      expect(stepOf(containerWith(), GuideStep.values.toSet()), isNull);
    });
  });

  group('Saving progress', () {
    test('finished tips are saved and read back next launch', () {
      final store = InMemoryPreferences();
      ProviderContainer open() {
        final container = ProviderContainer(
          overrides: [preferencesProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);
        return container;
      }

      open().read(guideProvider.notifier)
        ..complete(GuideStep.draw)
        ..complete(GuideStep.sets);

      expect(open().read(guideProvider), {GuideStep.draw, GuideStep.sets});
    });

    test('skip finishes every tip; restart clears them', () {
      final container = containerWith();
      final guide = container.read(guideProvider.notifier)..skip();
      expect(container.read(guideProvider), GuideStep.values.toSet());

      guide.restart();
      expect(container.read(guideProvider), isEmpty);
    });

    test('unknown saved names are ignored', () {
      expect(
        containerWith({
          'guide.done': 'draw,teleport,,joker',
        }).read(guideProvider),
        {GuideStep.draw, GuideStep.joker},
      );
    });

    test('every tip is short enough for one line on a small phone', () {
      for (final step in GuideStep.values) {
        expect(tipFor(step), isNotEmpty);
        expect(tipFor(step).length, lessThanOrEqualTo(56), reason: '$step');
      }
    });
  });

  group('At the table', () {
    Finder tip(GuideStep step) => find.byKey(Key('guide-${step.name}'));

    testWidgets('the tips follow a first game: draw, discard, then sets', (
      tester,
    ) async {
      final container = await pumpTable(tester);
      expect(tip(GuideStep.draw), findsOneWidget);
      expect(find.byKey(const Key('guide-got-it')), findsNothing);

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();
      expect(tip(GuideStep.draw), findsNothing);
      expect(tip(GuideStep.discard), findsOneWidget);

      final king = container
          .read(tableProvider)
          .hand
          .firstWhere((h) => h.card == c(Suit.spades, Rank.king))
          .id;
      unawaited(container.read(tableProvider.notifier).discard(king));
      await tester.pumpAndSettle();

      // The bot has played and it's the player's turn again.
      expect(tip(GuideStep.discard), findsNothing);
      expect(tip(GuideStep.sets), findsOneWidget);
      await tester.tap(find.byKey(const Key('guide-got-it')));
      await tester.pump();
      expect(tip(GuideStep.sets), findsNothing);
      expect(container.read(guideProvider), {
        GuideStep.draw,
        GuideStep.discard,
        GuideStep.sets,
      });
    });

    testWidgets('the tip doesn\'t get in the way of the cards under it', (
      tester,
    ) async {
      await pumpTable(tester);

      // The draw tip lies below the piles; the stock above it still works.
      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();

      expect(tip(GuideStep.discard), findsOneWidget);
    });

    testWidgets('Skip guide hides every tip, for good', (tester) async {
      final container = await pumpTable(tester);

      await tester.tap(find.byKey(const Key('guide-skip')));
      await tester.pump();

      expect(find.byKey(const Key('guide-skip')), findsNothing);
      expect(container.read(guideProvider), GuideStep.values.toSet());
    });

    testWidgets('a returning player sees no tips', (tester) async {
      await pumpTable(tester, saved: {'guide.done': 'draw,discard,sets,joker'});

      expect(find.byKey(const Key('guide-skip')), findsNothing);
    });
  });

  testWidgets('How to play can start the guide over', (tester) async {
    final store = InMemoryPreferences({'guide.done': 'draw,discard,sets'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(store)],
        child: const MarriageApp(home: HowToPlayScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('guide-restart')));
    await tester.pump();

    expect(find.text('The guide will show in your next game.'), findsOneWidget);
    expect(store.getString('guide.done'), '');
  });
}
