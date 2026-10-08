import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/win_check.dart';

const c = PlayingCard.new;

void main() {
  // Tiplu 7♥: every 7 plus 6♥ (jhiplu) and 8♥ (poplu) is wild.
  final jokers = Jokers(c(Suit.hearts, Rank.seven));

  group('isFinishingSet', () {
    test('sequences, trials and tunnellas all count, jokers allowed', () {
      expect(
        isFinishingSet([
          c(Suit.spades, Rank.two),
          c(Suit.clubs, Rank.seven),
          c(Suit.spades, Rank.four),
        ], jokers),
        isTrue,
      );
      expect(
        isFinishingSet([
          c(Suit.spades, Rank.king),
          c(Suit.diamonds, Rank.king),
          c(Suit.hearts, Rank.eight),
        ], jokers),
        isTrue,
      );
      expect(
        isFinishingSet([
          c(Suit.clubs, Rank.queen),
          c(Suit.clubs, Rank.queen),
          c(Suit.clubs, Rank.queen),
        ], jokers),
        isTrue,
      );
    });

    test('two identical cards plus a joker is not a set', () {
      expect(
        isFinishingSet([
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.five),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isFalse,
      );
    });
  });

  group('canSplitIntoSets', () {
    test('an empty hand splits trivially', () {
      expect(canSplitIntoSets([], jokers), isTrue);
    });

    test('4 sets of 3, in any order, split', () {
      final cards = [
        c(Suit.spades, Rank.king), // trial K with a joker…
        c(Suit.diamonds, Rank.ten), // …sequence 10♦ J♦ Q♦…
        c(Suit.clubs, Rank.two), // …pure sequence 2♣ 3♣ 4♣…
        c(Suit.diamonds, Rank.king),
        c(Suit.diamonds, Rank.jack),
        c(Suit.clubs, Rank.three),
        c(Suit.clubs, Rank.seven), // joker
        c(Suit.diamonds, Rank.queen),
        c(Suit.clubs, Rank.four),
        c(Suit.spades, Rank.ace), // …tunnella A♠
        c(Suit.spades, Rank.ace),
        c(Suit.spades, Rank.ace),
      ];

      expect(canSplitIntoSets(cards, jokers), isTrue);
    });

    test('a long sequence plus a trial splits', () {
      final cards = [
        for (final r in [Rank.two, Rank.three, Rank.four, Rank.five])
          c(Suit.spades, r),
        c(Suit.hearts, Rank.eight), // joker as 6♠
        c(Suit.clubs, Rank.nine),
        c(Suit.diamonds, Rank.nine),
        c(Suit.hearts, Rank.nine),
      ];

      expect(canSplitIntoSets(cards, jokers), isTrue);
    });

    test('a leftover card means no split', () {
      final cards = [
        c(Suit.clubs, Rank.two),
        c(Suit.clubs, Rank.three),
        c(Suit.clubs, Rank.four),
        c(Suit.diamonds, Rank.queen),
      ];

      expect(canSplitIntoSets(cards, jokers), isFalse);
    });

    test('finds the split that works when a greedy one would fail', () {
      final cards = [
        c(Suit.clubs, Rank.three),
        c(Suit.clubs, Rank.four),
        c(Suit.clubs, Rank.five),
        c(Suit.clubs, Rank.six),
        c(Suit.diamonds, Rank.six),
        c(Suit.spades, Rank.six),
      ];

      // 3♣ 4♣ 5♣ + trial 6♣ 6♦ 6♠ works; 3♣-4♣-5♣-6♣ would strand 6♦ 6♠.
      expect(canSplitIntoSets(cards, jokers), isTrue);
    });

    test('order does not matter, even with a wild card listed first', () {
      final cards = [
        c(Suit.clubs, Rank.seven), // wild
        c(Suit.diamonds, Rank.nine),
        c(Suit.spades, Rank.two),
        c(Suit.diamonds, Rank.nine),
        c(Suit.spades, Rank.three),
        c(Suit.hearts, Rank.six), // wild
        c(Suit.clubs, Rank.nine),
      ];

      // 2♠ 3♠ + a joker, and 9♦ 9♣ + a joker… with one 9♦ left over: no.
      expect(canSplitIntoSets(cards, jokers), isFalse);
      // Without the spare 9♦ it splits.
      expect(canSplitIntoSets([...cards]..removeAt(1), jokers), isTrue);
    });

    test('wild cards forming a set on face value still split', () {
      // All three are wild with tiplu 7♥, but 6♥-7♥-8♥ is a pure sequence.
      final cards = [
        c(Suit.hearts, Rank.eight),
        c(Suit.hearts, Rank.six),
        c(Suit.hearts, Rank.seven),
      ];

      expect(canSplitIntoSets(cards, jokers), isTrue);
    });

    test('a set of only jokers does not count', () {
      final cards = [
        c(Suit.clubs, Rank.seven),
        c(Suit.spades, Rank.seven),
        c(Suit.hearts, Rank.eight),
      ];

      expect(canSplitIntoSets(cards, jokers), isFalse);
    });
  });

  group('containsDoubleeWithJokers', () {
    test('two identical cards are a doublee', () {
      expect(
        containsDoubleeWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.two),
          c(Suit.spades, Rank.king),
        ], jokers),
        isTrue,
      );
    });

    test('a joker pairs with any card', () {
      expect(
        containsDoubleeWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.seven),
        ], jokers),
        isTrue,
      );
    });

    test('two jokers are a doublee', () {
      expect(
        containsDoubleeWithJokers([
          c(Suit.clubs, Rank.seven),
          c(Suit.hearts, Rank.six),
        ], jokers),
        isTrue,
      );
    });

    test('no pair and no joker is not a doublee', () {
      expect(
        containsDoubleeWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.hearts, Rank.king),
          c(Suit.clubs, Rank.two),
        ], jokers),
        isFalse,
      );
    });

    test('a single card is not a doublee', () {
      expect(
        containsDoubleeWithJokers([c(Suit.clubs, Rank.seven)], jokers),
        isFalse,
      );
    });
  });
}
