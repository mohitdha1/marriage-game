import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/hand_arrangement.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/melds.dart';
import 'package:marriage_game/engine/player_hand.dart';

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

  group('maxPureSets', () {
    test('counts separate pure sequences and tunnellas', () {
      final kings = [for (var i = 0; i < 3; i++) c(Suit.spades, Rank.king)];

      expect(maxPureSets([...heartsRun, ...clubsRun, ...kings]), 3);
    });

    test('a long run counts once; overlapping runs do not double up', () {
      final fiveRun = run(Suit.clubs, [
        Rank.two,
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]);

      expect(maxPureSets(fiveRun), 1);
      expect(maxPureSets([...fiveRun, c(Suit.clubs, Rank.seven)]), 2);
    });

    test('trials and joker-filled sets do not count toward the show', () {
      expect(
        maxPureSets([
          c(Suit.spades, Rank.nine),
          c(Suit.hearts, Rank.nine),
          c(Suit.clubs, Rank.nine),
        ]),
        0,
      );
    });

    test('an empty hand has none', () {
      expect(maxPureSets([]), 0);
    });
  });

  group('countDoublees', () {
    test('counts pairs of identical cards, one per pair', () {
      final two = c(Suit.clubs, Rank.two);
      final nine = c(Suit.spades, Rank.nine);

      expect(countDoublees([two, two, nine, nine, nine]), 2);
      expect(countDoublees([two, c(Suit.hearts, Rank.two)]), 0);
    });
  });

  group('bestArrangement', () {
    test('covers as many cards as possible', () {
      final cards = [
        ...run(Suit.clubs, [Rank.three, Rank.four, Rank.five, Rank.six]),
        c(Suit.diamonds, Rank.six),
        c(Suit.spades, Rank.six),
      ];

      final sets = bestArrangement(cards, Jokers(c(Suit.hearts, Rank.king)));

      expect(sets.expand((set) => set), unorderedEquals(cards));
      expect(sets, hasLength(2));
    });

    test('before the joker, only pure sets count', () {
      final cards = [
        ...heartsRun,
        c(Suit.spades, Rank.king),
        c(Suit.diamonds, Rank.king),
        c(Suit.clubs, Rank.seven),
      ];

      expect(bestArrangement(cards, null), [heartsRun]);
      expect(bestArrangement(cards, jokers).expand((set) => set), hasLength(6));
    });

    test('a hand with nothing in sets arranges into nothing', () {
      expect(
        bestArrangement([
          c(Suit.spades, Rank.two),
          c(Suit.hearts, Rank.nine),
        ], jokers),
        isEmpty,
      );
    });
  });

  group('handProgress', () {
    PlayerHand opened(List<PlayingCard> cards) =>
        PlayerHand(cards)
          ..showOpeningTunnellas(findTunnellas(cards).take(3).toList());

    test('before the joker: pure sets and doublees toward the show', () {
      final pair = c(Suit.diamonds, Rank.queen);
      final hand = opened([...heartsRun, ...clubsRun, pair, pair]);

      final progress = handProgress(hand, null);

      expect(progress, isA<ShowProgress>());
      progress as ShowProgress;
      expect(progress.pureSets, 2);
      expect(progress.pureSetsNeeded, 3);
      expect(progress.doublees, 1);
      expect(progress.doubleesNeeded, 7);
    });

    test('opening tunnellas lower the pure sets still needed', () {
      final kings = [for (var i = 0; i < 3; i++) c(Suit.spades, Rank.king)];
      final hand = opened([...kings, ...heartsRun]);

      final progress = handProgress(hand, null) as ShowProgress;

      expect(progress.pureSetsNeeded, 2);
      expect(progress.pureSets, 1);
    });

    test('a player who has not seen the joker still gets show progress', () {
      final hand = opened([...heartsRun]);

      expect(handProgress(hand, jokers), isA<ShowProgress>());
    });

    test('after seeing the joker: sets made, unmatched cards and maal', () {
      // Shows three runs, then holds K♠ K♦ 7♣ (a trial with a joker),
      // 8♥ (the poplu, worth 2) and a loose 2♦.
      final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
      final diamondsRun = run(Suit.diamonds, [Rank.nine, Rank.ten, Rank.jack]);
      final hand = opened([
        ...heartsRun,
        ...spadesRun,
        ...diamondsRun,
        c(Suit.spades, Rank.king),
        c(Suit.diamonds, Rank.king),
        c(Suit.clubs, Rank.seven),
        c(Suit.hearts, Rank.eight),
        c(Suit.diamonds, Rank.two),
      ])..showPureSets([heartsRun, spadesRun, diamondsRun]);

      final progress = handProgress(hand, jokers) as WinProgress;

      // 3 shown + the K trial (K♠ K♦ with 7♣, or 8♥, as the joker).
      expect(progress.setsMade, 4);
      expect(progress.unmatched, 2);
      expect(progress.maal, 2);
    });

    test('after showing doublees: progress toward the 8th', () {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.three,
          Rank.four,
          Rank.five,
          Rank.nine,
          Rank.ten,
          Rank.jack,
        ])
          [c(Suit.clubs, rank), c(Suit.clubs, rank)],
      ];
      PlayerHand dubleeHand(List<PlayingCard> extras) =>
          opened([...pairs.expand((p) => p), ...extras])
            ..draw(c(Suit.spades, Rank.ace))
            ..showDoublees(pairs);

      final noPair =
          handProgress(dubleeHand([c(Suit.spades, Rank.king)]), jokers)
              as DubleeProgress;
      expect(noPair.doublees, 7);
      expect(noPair.doubleesNeeded, 8);

      // 7♣ is a joker, so it pairs with anything for the 8th.
      final withJoker =
          handProgress(dubleeHand([c(Suit.clubs, Rank.seven)]), jokers)
              as DubleeProgress;
      expect(withJoker.doublees, 8);
    });
  });
}
