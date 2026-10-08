import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/melds.dart';

const c = PlayingCard.new;

void main() {
  group('isPureSequence', () {
    test('3 consecutive same-suit cards is valid', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.six),
          c(Suit.hearts, Rank.seven),
        ]),
        isTrue,
      );
    });

    test('order of the input list does not matter', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.seven),
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.six),
        ]),
        isTrue,
      );
    });

    test('5 consecutive same-suit cards is valid', () {
      expect(
        isPureSequence([
          c(Suit.clubs, Rank.three),
          c(Suit.clubs, Rank.four),
          c(Suit.clubs, Rank.five),
          c(Suit.clubs, Rank.six),
          c(Suit.clubs, Rank.seven),
        ]),
        isTrue,
      );
    });

    test('6 or more consecutive same-suit cards is valid (no upper cap)', () {
      expect(
        isPureSequence([
          c(Suit.clubs, Rank.three),
          c(Suit.clubs, Rank.four),
          c(Suit.clubs, Rank.five),
          c(Suit.clubs, Rank.six),
          c(Suit.clubs, Rank.seven),
          c(Suit.clubs, Rank.eight),
        ]),
        isTrue,
      );
    });

    test('a full 13-card suit from 2 to A is valid', () {
      expect(
        isPureSequence([for (final r in Rank.values) c(Suit.spades, r)]),
        isTrue,
      );
    });

    test('a 14-card run would have to wrap, so is invalid', () {
      expect(
        isPureSequence([
          c(Suit.spades, Rank.ace),
          for (final r in Rank.values) c(Suit.spades, r),
        ]),
        isFalse,
      );
    });

    test('mixed suits is invalid', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.five),
          c(Suit.spades, Rank.six),
          c(Suit.hearts, Rank.seven),
        ]),
        isFalse,
      );
    });

    test('a gap in rank is invalid', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.six),
          c(Suit.hearts, Rank.eight),
        ]),
        isFalse,
      );
    });

    test('ace can play high: Q-K-A', () {
      expect(
        isPureSequence([
          c(Suit.diamonds, Rank.queen),
          c(Suit.diamonds, Rank.king),
          c(Suit.diamonds, Rank.ace),
        ]),
        isTrue,
      );
    });

    test('ace can play low: A-2-3', () {
      expect(
        isPureSequence([
          c(Suit.diamonds, Rank.ace),
          c(Suit.diamonds, Rank.two),
          c(Suit.diamonds, Rank.three),
        ]),
        isTrue,
      );
    });

    test('ace does not wrap: K-A-2 is invalid', () {
      expect(
        isPureSequence([
          c(Suit.diamonds, Rank.king),
          c(Suit.diamonds, Rank.ace),
          c(Suit.diamonds, Rank.two),
        ]),
        isFalse,
      );
    });

    test('a duplicated card instead of a run is invalid', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.six),
        ]),
        isFalse,
      );
    });
  });

  group('isTrial', () {
    test('same rank across 3 different suits is valid', () {
      expect(
        isTrial([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.queen),
          c(Suit.clubs, Rank.queen),
        ]),
        isTrue,
      );
    });

    test('two cards sharing a suit is invalid, even from different decks', () {
      expect(
        isTrial([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.queen),
        ]),
        isFalse,
      );
    });

    test('different ranks is invalid', () {
      expect(
        isTrial([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.queen),
        ]),
        isFalse,
      );
    });

    test('wrong card count is invalid', () {
      expect(
        isTrial([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.queen),
        ]),
        isFalse,
      );
    });
  });

  group('isTunnella', () {
    test('3 physically-identical cards is valid', () {
      expect(
        isTunnella([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.queen),
        ]),
        isTrue,
      );
    });

    test('only 2 matching plus 1 different is invalid', () {
      expect(
        isTunnella([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.king),
        ]),
        isFalse,
      );
    });

    test('same rank but different suits is a trial, not a tunnella', () {
      expect(
        isTunnella([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.queen),
          c(Suit.clubs, Rank.queen),
        ]),
        isFalse,
      );
    });
  });

  group('findTunnellas', () {
    test('finds each card held 3 times', () {
      final kings = [for (var i = 0; i < 3; i++) c(Suit.clubs, Rank.king)];
      final twos = [for (var i = 0; i < 3; i++) c(Suit.hearts, Rank.two)];

      expect(findTunnellas([...kings, c(Suit.spades, Rank.ace), ...twos]), [
        kings,
        twos,
      ]);
    });

    test('2 copies, or the same rank in other suits, are not tunnellas', () {
      expect(
        findTunnellas([
          c(Suit.clubs, Rank.king),
          c(Suit.clubs, Rank.king),
          c(Suit.hearts, Rank.king),
          c(Suit.spades, Rank.king),
        ]),
        isEmpty,
      );
    });

    test('copies need not be next to each other', () {
      expect(
        findTunnellas([
          c(Suit.clubs, Rank.nine),
          c(Suit.hearts, Rank.two),
          c(Suit.clubs, Rank.nine),
          c(Suit.spades, Rank.ace),
          c(Suit.clubs, Rank.nine),
        ]),
        hasLength(1),
      );
    });
  });

  group('isDoublee', () {
    test('2 physically-identical cards is valid', () {
      expect(
        isDoublee([c(Suit.spades, Rank.nine), c(Suit.spades, Rank.nine)]),
        isTrue,
      );
    });

    test('same rank in different suits is invalid', () {
      expect(
        isDoublee([c(Suit.spades, Rank.nine), c(Suit.hearts, Rank.nine)]),
        isFalse,
      );
    });

    test('wrong card count is invalid', () {
      expect(isDoublee([c(Suit.spades, Rank.nine)]), isFalse);
      expect(
        isDoublee([
          c(Suit.spades, Rank.nine),
          c(Suit.spades, Rank.nine),
          c(Suit.spades, Rank.nine),
        ]),
        isFalse,
      );
    });
  });

  // Tiplu 7♥: every 7 plus 6♥ (jhiplu) and 8♥ (poplu) is wild.
  final jokers = Jokers(c(Suit.hearts, Rank.seven));

  group('isSequenceWithJokers', () {
    test('a joker can fill a gap in the middle', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.three),
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.five),
        ], jokers),
        isTrue,
      );
    });

    test('a joker can extend either end', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.three),
          c(Suit.spades, Rank.four),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('a joker can extend an ace-high run (Q-K-joker as A)', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.queen),
          c(Suit.spades, Rank.king),
          c(Suit.diamonds, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('a joker can extend an ace-low run (A-2-joker as 3)', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.ace),
          c(Suit.spades, Rank.two),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('a joker cannot make the run wrap round the ace (K-joker-2)', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.two),
        ], jokers),
        isFalse,
      );
    });

    test('several jokers with one natural card is valid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.nine),
          c(Suit.clubs, Rank.seven),
          c(Suit.hearts, Rank.six),
        ], jokers),
        isTrue,
      );
    });

    test('a 5-card sequence with a joker is valid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.two),
          c(Suit.spades, Rank.three),
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.five),
          c(Suit.spades, Rank.six),
        ], jokers),
        isTrue,
      );
    });

    test('all jokers with no natural card is invalid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.seven),
          c(Suit.hearts, Rank.eight),
        ], jokers),
        isFalse,
      );
    });

    test('wild cards forming a run on face value are still a sequence', () {
      final cards = [
        c(Suit.hearts, Rank.six),
        c(Suit.hearts, Rank.seven),
        c(Suit.hearts, Rank.eight),
      ];

      expect(isSequenceWithJokers(cards, jokers), isTrue);
    });

    test('tiplu in its natural place keeps the sequence pure', () {
      expect(
        isPureSequence([
          c(Suit.hearts, Rank.six),
          c(Suit.hearts, Rank.seven),
          c(Suit.hearts, Rank.eight),
        ]),
        isTrue,
      );
    });

    test('natural cards in different suits are invalid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.three),
          c(Suit.clubs, Rank.four),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });

    test('a gap too wide for the jokers available is invalid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.three),
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.nine),
        ], jokers),
        isFalse,
      );
    });

    test('duplicate natural cards are invalid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.four),
          c(Suit.spades, Rank.four),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });

    test('fewer than 3 cards is invalid', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.four),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });

    test('6 or more cards with a joker is valid (no upper cap)', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.two),
          c(Suit.spades, Rank.three),
          c(Suit.spades, Rank.four),
          c(Suit.spades, Rank.five),
          c(Suit.spades, Rank.six),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('more than 13 cards is invalid even with jokers', () {
      // 12 natural spades (all but the 7) plus 2 jokers: one would fill the
      // 7, but the other has nowhere to go without wrapping.
      expect(
        isSequenceWithJokers([
          for (final r in Rank.values)
            if (r != Rank.seven) c(Suit.spades, r),
          c(Suit.clubs, Rank.seven),
          c(Suit.diamonds, Rank.seven),
        ], jokers),
        isFalse,
      );
    });
  });

  group('isTrialWithJokers', () {
    test('a joker can stand in for a missing suit', () {
      expect(
        isTrialWithJokers([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.queen),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('two jokers with one natural card is valid', () {
      expect(
        isTrialWithJokers([
          c(Suit.hearts, Rank.queen),
          c(Suit.clubs, Rank.seven),
          c(Suit.hearts, Rank.eight),
        ], jokers),
        isTrue,
      );
    });

    test('all jokers with no natural card is invalid', () {
      expect(
        isTrialWithJokers([
          c(Suit.clubs, Rank.seven),
          c(Suit.hearts, Rank.six),
          c(Suit.hearts, Rank.eight),
        ], jokers),
        isFalse,
      );
    });

    test('wild cards forming a trial on face value are still a trial', () {
      expect(
        isTrialWithJokers([
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.seven),
          c(Suit.diamonds, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('natural cards sharing a suit are invalid', () {
      expect(
        isTrialWithJokers([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.queen),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });

    test('natural cards of different ranks are invalid', () {
      expect(
        isTrialWithJokers([
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });

    test('wrong card count is invalid', () {
      expect(
        isTrialWithJokers([
          c(Suit.hearts, Rank.queen),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });
  });
}
