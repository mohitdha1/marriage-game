import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';

void main() {
  group('PlayingCard equality', () {
    test('cards with the same suit and rank are equal', () {
      const a = PlayingCard(Suit.hearts, Rank.queen);
      const b = PlayingCard(Suit.hearts, Rank.queen);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cards with different ranks are not equal', () {
      const a = PlayingCard(Suit.hearts, Rank.queen);
      const b = PlayingCard(Suit.hearts, Rank.king);

      expect(a, isNot(equals(b)));
    });

    test('cards with different suits are not equal', () {
      const a = PlayingCard(Suit.hearts, Rank.queen);
      const b = PlayingCard(Suit.spades, Rank.queen);

      expect(a, isNot(equals(b)));
    });

    test('3 decks worth of the same card are all equal to each other', () {
      final threeQueensOfHearts = List.generate(
        3,
        (_) => const PlayingCard(Suit.hearts, Rank.queen),
      );

      expect(threeQueensOfHearts.toSet(), hasLength(1));
      expect(
        threeQueensOfHearts
            .where((c) => c == const PlayingCard(Suit.hearts, Rank.queen)),
        hasLength(3),
      );
    });
  });

  group('Rank order', () {
    test('ace outranks king, which outranks two', () {
      expect(Rank.ace.order, greaterThan(Rank.king.order));
      expect(Rank.king.order, greaterThan(Rank.two.order));
    });
  });
}
