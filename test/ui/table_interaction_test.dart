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
import 'package:marriage_game/ui/table/joker_reveal.dart';
import 'package:marriage_game/ui/table/opening_picker.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/table/tiplu_picker.dart';

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
  int firstSeat = 0,
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
            firstSeat: firstSeat,
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
    expect(status(tester), 'Your turn: draw a card.');

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    expect(stateOf(tester).hand.last.card, queenOfDiamonds);
    expect(status(tester), 'Select a card to discard.');

    await tester.tap(lastHandCard(tester));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pump();

    // The bot has played, and it is your turn again.
    final state = stateOf(tester);
    expect(state.hand.map((c) => c.card), isNot(contains(queenOfDiamonds)));
    expect(state.view.isYourTurn, isTrue);
    expect(status(tester), 'Your turn: draw a card.');
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
    expect(status(tester), 'Your turn: draw a card.');
  });

  group('Turn flow', () {
    final heartsRun = [
      c(Suit.hearts, Rank.three),
      c(Suit.hearts, Rank.four),
      c(Suit.hearts, Rank.five),
    ];
    final spadesRun = [
      c(Suit.spades, Rank.two),
      c(Suit.spades, Rank.three),
      c(Suit.spades, Rank.four),
    ];
    final clubsRun = [
      c(Suit.clubs, Rank.nine),
      c(Suit.clubs, Rank.ten),
      c(Suit.clubs, Rank.jack),
    ];
    final twoOfDiamonds = c(Suit.diamonds, Rank.two);
    final winnableHand = [
      ...heartsRun,
      ...spadesRun,
      ...clubsRun,
      c(Suit.spades, Rank.king),
      c(Suit.diamonds, Rank.king),
      c(Suit.clubs, Rank.seven),
      c(Suit.diamonds, Rank.ten),
      c(Suit.diamonds, Rank.jack),
      c(Suit.hearts, Rank.eight),
      twoOfDiamonds,
    ];

    TableController controllerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(TableScreen)),
        ).read(tableProvider.notifier);

    /// Selects one copy of each of [cards].
    void select(WidgetTester tester, List<PlayingCard> cards) {
      final used = <int>{};
      for (final card in cards) {
        final id = stateOf(
          tester,
        ).hand.firstWhere((h) => h.card == card && !used.contains(h.id)).id;
        used.add(id);
        controllerOf(tester).toggleSelected(id);
      }
    }

    testWidgets('draw, group, show, pick the tiplu, see it revealed, and win', (
      tester,
    ) async {
      await pumpTable(tester, yourHand: winnableHand);
      expect(find.byKey(const Key('joker-chip')), findsNothing);

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();

      // Group the three runs with the Group button.
      for (final run in [heartsRun, spadesRun, clubsRun]) {
        select(tester, run);
        await tester.pump();
        await tester.tap(find.byKey(const Key('group-button')));
        await tester.pump();
      }
      expect(stateOf(tester).groups, hasLength(3));

      // First to show: pick the tiplu from the face-down stock.
      await tester.tap(find.byKey(const Key('show-button')));
      await tester.pump();
      expect(find.byType(TipluPicker), findsOneWidget);
      await tester.tap(find.byKey(const Key('stock-card-1')));
      await tester.pump();

      // The reveal flips the tiplu over.
      expect(find.byType(JokerReveal), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('The joker is 7♥'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.byType(JokerReveal), findsNothing);

      // The joker stays in the corner, and wild cards in hand get a badge.
      expect(find.byKey(const Key('joker-chip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HandFan),
          matching: find.byKey(const Key('joker-badge')),
        ),
        findsNWidgets(2), // 7♣ and 8♥
      );
      expect(find.byKey(const Key('your-laid-down-sets')), findsOneWidget);

      // Win is offered only for a card whose discard wins.
      select(tester, [c(Suit.diamonds, Rank.ten)]);
      await tester.pump();
      final win = find.byKey(const Key('win-button'));
      expect(tester.widget<FilledButton>(win).onPressed, isNull);

      controllerOf(tester).toggleSelected(stateOf(tester).selected.single);
      select(tester, [twoOfDiamonds]);
      await tester.pump();
      expect(tester.widget<FilledButton>(win).onPressed, isNotNull);
      await tester.tap(win);
      await tester.pump();

      expect(status(tester), 'You won the round.');
      expect(find.text('You won the round!'), findsOneWidget);
    });

    testWidgets('Show and Group only appear when they can be used', (
      tester,
    ) async {
      await pumpTable(tester, yourHand: winnableHand);

      expect(find.byKey(const Key('group-button')), findsNothing);
      expect(find.byKey(const Key('show-button')), findsNothing);
      expect(find.byKey(const Key('win-button')), findsNothing);

      select(tester, heartsRun);
      await tester.pump();
      expect(find.byKey(const Key('group-button')), findsOneWidget);
    });

    testWidgets('the opponent whose turn it is glows', (tester) async {
      // A bot plays first, but waits while you choose opening tunnellas.
      await pumpTable(
        tester,
        firstSeat: 1,
        yourHand: [
          for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
            ...tunnellaOf(c(Suit.clubs, rank)),
        ],
      );

      expect(
        tester.widget<OpponentSeat>(find.byType(OpponentSeat)).isCurrentTurn,
        isTrue,
      );
      expect(status(tester), 'Choose your opening tunnellas.');

      for (final i in [0, 1, 2]) {
        await tester.tap(find.byKey(Key('opening-tunnella-$i')));
      }
      await tester.pump();
      await tester.tap(find.text('Show these 3'));
      await tester.pump();

      // The bot has had its turn; now it's yours, and its seat is calm.
      expect(
        tester.widget<OpponentSeat>(find.byType(OpponentSeat)).isCurrentTurn,
        isFalse,
      );
      expect(stateOf(tester).view.isYourTurn, isTrue);
    });
  });
}
