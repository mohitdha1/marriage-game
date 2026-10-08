import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/shoe.dart';

const c = PlayingCard.new;

void main() {
  // Tiplu 7♥ is used throughout unless a test needs something else.
  final jokers = Jokers(c(Suit.hearts, Rank.seven));

  group('Jokers derived cards', () {
    test('jhiplu is one rank below the tiplu, same suit', () {
      expect(jokers.jhiplu, c(Suit.hearts, Rank.six));
    });

    test('poplu is one rank above the tiplu, same suit', () {
      expect(jokers.poplu, c(Suit.hearts, Rank.eight));
    });

    test('alter is the same rank in the same-colour suit', () {
      expect(jokers.alter, c(Suit.diamonds, Rank.seven));
    });

    test('alter pairs hearts/diamonds and clubs/spades both ways', () {
      const expectedAlterSuit = {
        Suit.hearts: Suit.diamonds,
        Suit.diamonds: Suit.hearts,
        Suit.clubs: Suit.spades,
        Suit.spades: Suit.clubs,
      };

      expectedAlterSuit.forEach((tipluSuit, alterSuit) {
        final alter = Jokers(c(tipluSuit, Rank.queen)).alter;
        expect(
          alter,
          c(alterSuit, Rank.queen),
          reason: 'tiplu suit $tipluSuit',
        );
      });
    });
  });

  group('Jokers ace wraparound', () {
    test('tiplu ace: poplu wraps to two, jhiplu is king', () {
      final aceJokers = Jokers(c(Suit.spades, Rank.ace));

      expect(aceJokers.poplu, c(Suit.spades, Rank.two));
      expect(aceJokers.jhiplu, c(Suit.spades, Rank.king));
    });

    test('tiplu two: jhiplu wraps to ace, poplu is three', () {
      final twoJokers = Jokers(c(Suit.clubs, Rank.two));

      expect(twoJokers.jhiplu, c(Suit.clubs, Rank.ace));
      expect(twoJokers.poplu, c(Suit.clubs, Rank.three));
    });

    test('tiplu king: poplu is ace', () {
      expect(
        Jokers(c(Suit.diamonds, Rank.king)).poplu,
        c(Suit.diamonds, Rank.ace),
      );
    });
  });

  group('Jokers.kindOf', () {
    test('identifies each joker kind', () {
      expect(jokers.kindOf(c(Suit.hearts, Rank.seven)), JokerKind.tiplu);
      expect(jokers.kindOf(c(Suit.hearts, Rank.six)), JokerKind.jhiplu);
      expect(jokers.kindOf(c(Suit.hearts, Rank.eight)), JokerKind.poplu);
      expect(jokers.kindOf(c(Suit.diamonds, Rank.seven)), JokerKind.alter);
    });

    test('same rank in an opposite-colour suit is an ordinary joker', () {
      expect(jokers.kindOf(c(Suit.clubs, Rank.seven)), JokerKind.ordinary);
      expect(jokers.kindOf(c(Suit.spades, Rank.seven)), JokerKind.ordinary);
    });

    test('unrelated cards are not jokers', () {
      expect(jokers.kindOf(c(Suit.hearts, Rank.nine)), isNull);
      expect(jokers.kindOf(c(Suit.spades, Rank.king)), isNull);
    });

    test('jhiplu/poplu rank in a different suit is not a joker', () {
      expect(jokers.kindOf(c(Suit.diamonds, Rank.six)), isNull);
      expect(jokers.kindOf(c(Suit.clubs, Rank.eight)), isNull);
    });
  });

  group('Jokers.isWild', () {
    test('every joker kind is wild', () {
      for (final card in [
        c(Suit.hearts, Rank.seven),
        c(Suit.hearts, Rank.six),
        c(Suit.hearts, Rank.eight),
        c(Suit.diamonds, Rank.seven),
        c(Suit.clubs, Rank.seven),
      ]) {
        expect(jokers.isWild(card), isTrue, reason: '$card');
      }
    });

    test('normal cards are not wild', () {
      expect(jokers.isWild(c(Suit.hearts, Rank.nine)), isFalse);
    });

    test('a 3-deck shoe has 18 wild cards: 12 of the tiplu rank + 3 + 3', () {
      final wildCount = Shoe(3).cards.where(jokers.isWild).length;

      expect(wildCount, 18);
    });
  });
}
