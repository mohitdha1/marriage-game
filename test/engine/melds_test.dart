import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
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

    test('5 consecutive same-suit cards (the max) is valid', () {
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

    test('6 consecutive same-suit cards exceeds the cap', () {
      expect(
        isPureSequence([
          c(Suit.clubs, Rank.three),
          c(Suit.clubs, Rank.four),
          c(Suit.clubs, Rank.five),
          c(Suit.clubs, Rank.six),
          c(Suit.clubs, Rank.seven),
          c(Suit.clubs, Rank.eight),
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
}
