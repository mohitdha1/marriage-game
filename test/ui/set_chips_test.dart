import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/ui/state/table_view.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/set_chips.dart';
import 'package:marriage_game/ui/table/suit_icon.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('SetChip.label', () {
    test('a sequence reads as its suit and ranks', () {
      expect(
        SetChip.label(run(Suit.spades, [Rank.ace, Rank.two, Rank.three])),
        '♠A23',
      );
      expect(
        SetChip.label(run(Suit.hearts, [Rank.eight, Rank.nine, Rank.ten])),
        '♥8910',
      );
    });

    test('tunnellas and doublees read the same way', () {
      final king = c(Suit.clubs, Rank.king);

      expect(SetChip.label([king, king, king]), '♣KKK');
      expect(SetChip.label([king, king]), '♣KK');
    });

    test('mixed suits list each card', () {
      expect(
        SetChip.label([c(Suit.spades, Rank.nine), c(Suit.hearts, Rank.nine)]),
        '9♠ 9♥',
      );
    });
  });

  testWidgets('a chip draws its suit and enlarges when tapped', (tester) async {
    final set = run(Suit.diamonds, [Rank.jack, Rank.queen, Rank.king]);
    await pump(tester, SetChip(set));

    expect(tester.widget<SuitIcon>(find.byType(SuitIcon)).suit, Suit.diamonds);

    await tester.tap(find.byType(SetChip));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('enlarged-set')), findsOneWidget);
    expect(
      tester
          .widgetList<CardFace>(
            find.descendant(
              of: find.byKey(const Key('enlarged-set')),
              matching: find.byType(CardFace),
            ),
          )
          .map((face) => face.card),
      set,
    );
  });

  testWidgets('a seat shows the sets its player has laid down', (tester) async {
    await pump(
      tester,
      OpponentSeat(
        seat: SeatView(
          seat: 2,
          name: 'Emma',
          cardCount: 12,
          hasSeenJoker: true,
          laidDown: [
            run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
            run(Suit.hearts, [Rank.jack, Rank.queen, Rank.king]),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('seat-sets-2')), findsOneWidget);
    expect(find.byType(SetChip), findsNWidgets(2));
  });

  testWidgets('a seat with no sets shows no chips', (tester) async {
    await pump(
      tester,
      const OpponentSeat(seat: SeatView(seat: 1, name: 'Jack', cardCount: 21)),
    );

    expect(find.byType(SetChip), findsNothing);
  });
}
