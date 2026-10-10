import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/ui/table/move_log.dart';
import 'package:marriage_game/ui/table/suit_icon.dart';

const c = PlayingCard.new;

String nameOf(int seat) => const ['You', 'Priya', 'Jack'][seat];

void main() {
  group('describeEvent', () {
    final nine = c(Suit.clubs, Rank.nine);
    final run = [
      c(Suit.spades, Rank.ace),
      c(Suit.spades, Rank.two),
      c(Suit.spades, Rank.three),
    ];

    test('a stock draw keeps the card hidden', () {
      expect(
        describeEvent(const DrewCard(1, DrawSource.stock), nameOf),
        'Priya drew from the stock',
      );
    });

    test('a card taken from the discard pile is named', () {
      expect(
        describeEvent(DrewCard(2, DrawSource.discardPile, nine), nameOf),
        'Jack took 9♣ from the discard pile',
      );
    });

    test('discards, shows, openings, wins and reshuffles', () {
      expect(describeEvent(DiscardedCard(0, nine), nameOf), 'You discarded 9♣');
      expect(
        describeEvent(ShowedSets(1, ShowKind.pureSets, [run]), nameOf),
        'Priya showed ♠A23 and saw the joker',
      );
      expect(
        describeEvent(
          ShowedSets(1, ShowKind.doublees, [
            [nine, nine],
          ]),
          nameOf,
        ),
        'Priya showed ♣99 (doublees) and saw the joker',
      );
      expect(
        describeEvent(
          OpenedTunnellas(2, [
            [nine, nine, nine],
          ]),
          nameOf,
        ),
        'Jack opened with ♣999',
      );
      expect(
        describeEvent(WonRound(2, nine), nameOf),
        'Jack discarded 9♣ and won the round',
      );
      expect(
        describeEvent(const StockReshuffled(0), nameOf),
        'The stock ran out and the discards were shuffled',
      );
    });
  });

  group('MoveLog', () {
    Future<void> pump(WidgetTester tester, List<TableEvent> events) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MoveLog(events: events, nameOf: nameOf),
            ),
          ),
        );

    testWidgets('lists the moves newest first', (tester) async {
      await pump(tester, [
        const DrewCard(0, DrawSource.stock),
        DiscardedCard(0, c(Suit.hearts, Rank.king)),
        const DrewCard(1, DrawSource.stock),
      ]);

      final lines = tester
          .widgetList<SuitText>(find.byType(SuitText))
          .map((line) => line.text)
          .toList();
      expect(lines, [
        'Priya drew from the stock',
        'You discarded K♥',
        'You drew from the stock',
      ]);
    });

    testWidgets('says so when nothing has happened yet', (tester) async {
      await pump(tester, const []);

      expect(find.text('No moves yet.'), findsOneWidget);
    });
  });
}
