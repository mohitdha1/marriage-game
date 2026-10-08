import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/opening_picker.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

final yourCards = [
  c(Suit.hearts, Rank.three),
  c(Suit.hearts, Rank.four),
  c(Suit.hearts, Rank.five),
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.two),
];
final queenOfDiamonds = c(Suit.diamonds, Rank.queen);
final kingOfClubs = c(Suit.clubs, Rank.king);

Future<void> pumpTable(
  WidgetTester tester, {
  List<PlayingCard>? yourHand,
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        roundFactoryProvider.overrideWithValue(
          () => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              yourHand ?? yourCards,
              [
                c(Suit.spades, Rank.six),
                c(Suit.spades, Rank.eight),
                c(Suit.spades, Rank.queen),
              ],
            ],
            stock: [
              c(Suit.clubs, Rank.five),
              c(Suit.hearts, Rank.seven),
              c(Suit.clubs, Rank.two),
              queenOfDiamonds,
            ],
            discardPile: [kingOfClubs],
          ),
        ),
      ],
      child: const MarriageApp(),
    ),
  );
}

TableState stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider);

/// The right-most card in the fan: the only one not partly covered by its
/// neighbour, so it's safe to tap or drag.
Finder lastHandCard(WidgetTester tester) =>
    find.byKey(ValueKey(stateOf(tester).hand.last.id));

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-line'))).data!;

/// Drags from [from] to [to] the way a finger would.
Future<void> dragBetween(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a card selects it with a highlight', (tester) async {
    await pumpTable(tester);

    await tester.tap(lastHandCard(tester));
    await tester.pump();

    expect(stateOf(tester).selected, {stateOf(tester).hand.last.id});
    final face = tester.widget<CardFace>(
      find.descendant(
        of: lastHandCard(tester),
        matching: find.byType(CardFace),
      ),
    );
    expect(face.highlighted, isTrue);
  });

  testWidgets('tap the stock to draw, then select and tap the pile to '
      'discard', (tester) async {
    await pumpTable(tester);
    expect(status(tester), contains('tap the stock or the discard pile'));

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    expect(stateOf(tester).hand.last.card, queenOfDiamonds);
    expect(status(tester), contains('Select a card'));

    await tester.tap(lastHandCard(tester));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pump();

    // The bot has played, and it is your turn again.
    final state = stateOf(tester);
    expect(state.hand.map((c) => c.card), isNot(contains(queenOfDiamonds)));
    expect(state.view.isYourTurn, isTrue);
    expect(status(tester), contains('tap the stock or the discard pile'));
  });

  testWidgets('a refused move pops up the reason', (tester) async {
    await pumpTable(tester);

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pump();

    expect(
      find.text('Select one card, then tap the discard pile.'),
      findsOneWidget,
    );
  });

  testWidgets('drag the stock onto the hand to draw', (tester) async {
    await pumpTable(tester);

    await dragBetween(
      tester,
      find.byKey(const Key('stock')),
      find.byType(HandFan),
    );

    expect(stateOf(tester).hand.last.card, queenOfDiamonds);
  });

  testWidgets('drag the discard pile onto the hand to take its card', (
    tester,
  ) async {
    await pumpTable(tester);

    await dragBetween(
      tester,
      find.byKey(const Key('discard-pile')),
      find.byType(HandFan),
    );

    expect(stateOf(tester).hand.last.card, kingOfClubs);
  });

  testWidgets('drag a card onto the discard pile to discard it', (
    tester,
  ) async {
    await pumpTable(tester);
    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();

    await dragBetween(
      tester,
      lastHandCard(tester),
      find.byKey(const Key('discard-pile')),
    );

    expect(
      stateOf(tester).hand.map((c) => c.card),
      isNot(contains(queenOfDiamonds)),
    );
    expect(stateOf(tester).view.isYourTurn, isTrue);
  });

  testWidgets('Sort orders the hand by suit, then rank', (tester) async {
    await pumpTable(tester);

    await tester.tap(find.byKey(const Key('sort-button')));
    await tester.pump();

    final shown = tester
        .widgetList<CardFace>(
          find.descendant(
            of: find.byType(HandFan),
            matching: find.byType(CardFace),
          ),
        )
        .map((face) => face.card)
        .toList();
    expect(shown, [
      c(Suit.clubs, Rank.seven),
      c(Suit.diamonds, Rank.two),
      c(Suit.diamonds, Rank.king),
      c(Suit.hearts, Rank.three),
      c(Suit.hearts, Rank.four),
      c(Suit.hearts, Rank.five),
      c(Suit.spades, Rank.king),
    ]);
  });

  testWidgets('with 4 dealt tunnellas, the player picks 3 to show', (
    tester,
  ) async {
    await pumpTable(
      tester,
      yourHand: [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          ...tunnellaOf(c(Suit.clubs, rank)),
        c(Suit.hearts, Rank.ace),
      ],
    );
    expect(find.byType(OpeningPicker), findsOneWidget);
    expect(status(tester), 'Choose your opening tunnellas.');

    final showButton = find.widgetWithText(FilledButton, 'Show these 3');
    expect(tester.widget<FilledButton>(showButton).onPressed, isNull);

    for (final i in [0, 1, 3]) {
      await tester.tap(find.byKey(Key('opening-tunnella-$i')));
    }
    await tester.pump();
    await tester.tap(showButton);
    await tester.pump();

    expect(find.byType(OpeningPicker), findsNothing);
    expect(stateOf(tester).hand, hasLength(4));
    expect(status(tester), contains('tap the stock or the discard pile'));
  });
}
