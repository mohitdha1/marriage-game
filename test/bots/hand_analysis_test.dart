import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/hand_analysis.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

void main() {
  // Tiplu 7♥: every 7 plus 6♥ and 8♥ is wild.
  final jokers = Jokers(c(Suit.hearts, Rank.seven));
  final heartsRun = run(Suit.hearts, [Rank.two, Rank.three, Rank.four]);
  final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);

  group('findPureSets and allPureSetChoices', () {
    test('finds separate pure sets', () {
      final sets = findPureSets([
        ...heartsRun,
        c(Suit.spades, Rank.king),
        ...clubsRun,
      ], 2)!;

      expect(sets, unorderedEquals([heartsRun, clubsRun]));
    });

    test('never uses a card twice', () {
      final cards = run(Suit.clubs, [
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]);

      expect(findPureSets(cards, 2), isNull);
      // 3-4-5 and 4-5-6 are both possible single choices.
      expect(allPureSetChoices(cards, 1), hasLength(2));
    });

    test('counts tunnellas and ace-low runs', () {
      final kings = [for (var i = 0; i < 3; i++) c(Suit.spades, Rank.king)];
      final aceLow = run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]);

      expect(
        findPureSets([...kings, ...aceLow], 2),
        unorderedEquals([kings, aceLow]),
      );
    });
  });

  group('findDoublees', () {
    test('finds pairs of identical cards', () {
      final pairs = findDoublees([
        c(Suit.clubs, Rank.two),
        c(Suit.clubs, Rank.two),
        c(Suit.hearts, Rank.two),
        c(Suit.spades, Rank.nine),
        c(Suit.spades, Rank.nine),
      ], 2);

      expect(pairs, [
        [c(Suit.clubs, Rank.two), c(Suit.clubs, Rank.two)],
        [c(Suit.spades, Rank.nine), c(Suit.spades, Rank.nine)],
      ]);
    });

    test('returns null when there are too few pairs', () {
      expect(findDoublees(heartsRun, 1), isNull);
    });
  });

  group('usefulness', () {
    final card = c(Suit.clubs, Rank.five);

    test('a card with no partners scores 0', () {
      expect(usefulness(card, [c(Suit.hearts, Rank.king)], null), 0);
    });

    test('close same-suit cards and identical copies help', () {
      expect(usefulness(card, [c(Suit.clubs, Rank.six)], null), 2);
      expect(usefulness(card, [c(Suit.clubs, Rank.seven)], null), 1);
      expect(usefulness(card, [card], null), 2);
    });

    test('same rank only helps once the joker is seen', () {
      final other = c(Suit.hearts, Rank.five);

      expect(usefulness(card, [other], null), 0);
      expect(usefulness(card, [other], jokers), 1);
    });

    test('wild cards are always kept', () {
      expect(usefulness(c(Suit.spades, Rank.seven), [], jokers), 100);
    });

    test('a pair bonus favours identical cards', () {
      expect(usefulness(card, [card], null, pairBonus: 2), 4);
    });

    test('a gap that can never be filled counts for less', () {
      // 5♣ and 7♣ need 6♣, and none are left.
      int noneLeft(PlayingCard card) => card == c(Suit.clubs, Rank.six) ? 0 : 3;

      expect(
        usefulness(card, [c(Suit.clubs, Rank.seven)], null),
        greaterThan(
          usefulness(
            card,
            [c(Suit.clubs, Rank.seven)],
            null,
            stillAvailable: noneLeft,
          ),
        ),
      );
    });
  });

  group('rankGap', () {
    test('the ace sits next to both the king and the two', () {
      expect(rankGap(Rank.ace, Rank.king), 1);
      expect(rankGap(Rank.ace, Rank.two), 1);
      expect(rankGap(Rank.two, Rank.four), 2);
    });
  });

  group('maxCoverage', () {
    test('before the joker, only pure sets count', () {
      final cards = [
        ...heartsRun,
        c(Suit.spades, Rank.king),
        c(Suit.diamonds, Rank.king),
        c(Suit.clubs, Rank.seven), // would be wild, but the joker is unseen
      ];

      expect(maxCoverage(cards, null), 3);
    });

    test('after the joker, trials and joker-filled sets count too', () {
      final cards = [
        ...heartsRun,
        c(Suit.spades, Rank.king),
        c(Suit.diamonds, Rank.king),
        c(Suit.clubs, Rank.seven),
      ];

      expect(maxCoverage(cards, jokers), 6);
    });

    test('a hand with nothing in sets covers 0', () {
      expect(
        maxCoverage([
          c(Suit.spades, Rank.two),
          c(Suit.hearts, Rank.nine),
          c(Suit.clubs, Rank.king),
        ], jokers),
        0,
      );
    });

    test('picks the best way to split overlapping sets', () {
      // 3♣ 4♣ 5♣ 6♣ 6♦ 6♠: the run 3-4-5 plus the trial of 6s covers all 6.
      final cards = [
        ...run(Suit.clubs, [Rank.three, Rank.four, Rank.five, Rank.six]),
        c(Suit.diamonds, Rank.six),
        c(Suit.spades, Rank.six),
      ];

      expect(maxCoverage(cards, Jokers(c(Suit.hearts, Rank.king))), 6);
    });
  });
}
