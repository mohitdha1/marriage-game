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
}
