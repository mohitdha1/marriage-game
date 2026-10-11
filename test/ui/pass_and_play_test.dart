import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/pass_screen.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

// In the order the hand is shown: sorted by suit (♠ before ♥), then rank.
final ashasCards = [
  c(Suit.spades, Rank.king),
  c(Suit.hearts, Rank.three),
  c(Suit.hearts, Rank.four),
  c(Suit.hearts, Rank.five),
];
final binasCards = [
  c(Suit.spades, Rank.six),
  c(Suit.spades, Rank.eight),
  c(Suit.spades, Rank.queen),
];

Future<ProviderContainer> pumpTable(WidgetTester tester) async {
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
        // The first-time guide is done, so only the pass screen shows.
        preferencesProvider.overrideWithValue(
          InMemoryPreferences({'guide.done': 'draw,discard,sets,joker'}),
        ),
        randomProvider.overrideWithValue(Random(0)),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [ashasCards, binasCards],
            stock: [c(Suit.clubs, Rank.five), c(Suit.diamonds, Rank.queen)],
            discardPile: [c(Suit.clubs, Rank.king)],
            firstSeat: seat,
          ),
        ),
      ],
      child: const MarriageApp(home: singlePlayerTable),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TableScreen)),
  );
  container
      .read(matchSetupProvider.notifier)
      .choose(MatchSetup.passAndPlay(['Asha', 'Bina']));
  container.invalidate(tableProvider);
  await tester.pump();
  return container;
}

List<PlayingCard> handShown(WidgetTester tester) => [
  for (final face in tester.widgetList<CardFace>(
    find.descendant(of: find.byType(HandFan), matching: find.byType(CardFace)),
  ))
    face.card,
];

void main() {
  group('movesSince', () {
    String name(int seat) => ['Asha', 'Bina', 'Chandra'][seat];

    test('lists what happened after the seat\'s own latest move', () {
      final events = [
        const DrewCard(0, DrawSource.stock),
        DiscardedCard(0, c(Suit.spades, Rank.king)),
        const DrewCard(1, DrawSource.stock),
        DiscardedCard(1, c(Suit.hearts, Rank.two)),
        const DrewCard(2, DrawSource.stock),
      ];

      expect(movesSince(events, 0, name), [
        'Bina drew from the stock',
        'Bina discarded 2♥',
        'Chandra drew from the stock',
      ]);
    });

    test('a seat that hasn\'t moved hears the whole round', () {
      final events = [const DrewCard(0, DrawSource.stock)];

      expect(movesSince(events, 1, name), ['Asha drew from the stock']);
    });
  });

  testWidgets('the table is covered between turns, and each person sees '
      'only their own cards', (tester) async {
    final container = await pumpTable(tester);

    // The round opens covered for Asha, who plays first.
    expect(find.text('Pass the device to Asha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pass-ready')));
    await tester.pump();
    expect(find.byKey(const Key('pass-screen')), findsNothing);
    expect(handShown(tester), ashasCards);

    // Asha draws and discards K♠; the table covers itself for Bina.
    final controller = container.read(tableProvider.notifier)
      ..draw(DrawSource.stock);
    final king = container
        .read(tableProvider)
        .hand
        .firstWhere((h) => h.card == c(Suit.spades, Rank.king))
        .id;
    unawaited(controller.discard(king));
    await tester.pump();

    expect(find.text('Pass the device to Bina'), findsOneWidget);
    expect(find.textContaining('Asha drew from the stock'), findsOneWidget);
    expect(find.byKey(const Key('pass-since')), findsOneWidget);

    // Nothing on the covered table can be touched.
    await tester.tap(find.byKey(const Key('stock')), warnIfMissed: false);
    await tester.pump();
    expect(container.read(tableProvider).view.youHaveDrawn, isFalse);

    await tester.tap(find.byKey(const Key('pass-ready')));
    await tester.pump();
    expect(handShown(tester), binasCards);
    expect(container.read(tableProvider).view.you.name, 'Bina');
  });
}
