import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/hand_arrangement.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/melds.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/engine/shoe.dart';
import 'package:marriage_game/engine/win_check.dart';

const c = PlayingCard.new;
const superman = PlayingCard.superman();
const man = PlayingCard.man();

// Tiplu 7♥: every 7 plus 6♥ (jhiplu) and 8♥ (poplu) is wild.
final jokers = Jokers(c(Suit.hearts, Rank.seven));

final spadesRun = [
  c(Suit.spades, Rank.two),
  c(Suit.spades, Rank.three),
  c(Suit.spades, Rank.four),
];
final clubsRun = [
  c(Suit.clubs, Rank.nine),
  c(Suit.clubs, Rank.ten),
  c(Suit.clubs, Rank.jack),
];

/// 5♠ Superman 7♠: a pure sequence with the Superman as its 6♠.
final gappedRun = [
  c(Suit.spades, Rank.five),
  superman,
  c(Suit.spades, Rank.seven),
];

/// Opened with nothing, holding [held] and the three pure sets to show.
/// After drawing [drawn], the sets are shown.
PlayerHand shownWith(
  List<List<PlayingCard>> sets, {
  List<PlayingCard> held = const [],
  PlayingCard? drawn,
}) => PlayerHand([...sets.expand((s) => s), ...held])
  ..showOpeningTunnellas([])
  ..draw(drawn ?? c(Suit.diamonds, Rank.two))
  ..showPureSets(sets);

void main() {
  group('The Superman card', () {
    test('is a printed joker, unlike a man card or any natural card', () {
      expect(const PlayingCard.superman(), superman);
      expect(superman.isSuperman, isTrue);
      expect(superman.isPrinted, isTrue);
      expect(superman.isMan, isFalse);
      expect(man.isSuperman, isFalse);
      expect(superman, isNot(man));
      expect(superman, isNot(c(Suit.spades, Rank.two)));
      expect('$superman', 'Superman');
    });

    test('cardIndex gives it a number of its own', () {
      final cards = [
        for (final suit in Suit.values)
          for (final rank in Rank.values) c(suit, rank),
        man,
        superman,
      ];
      expect(cards.map(cardIndex).toSet(), hasLength(54));
      expect(cardIndex(superman), 53);
    });
  });

  group('The shoe', () {
    test('has no Superman unless it is on', () {
      expect(
        Shoe.fromConfig(GameConfig()).cards.where((c) => c.isSuperman),
        isEmpty,
      );
    });

    test('has exactly one when it is on, alongside any man cards', () {
      final shoe = Shoe.fromConfig(
        GameConfig(supermanCardEnabled: true, manCardsEnabled: true),
      );

      expect(shoe.length, 3 * 52 + 3 + 1);
      expect(shoe.cards.where((c) => c.isSuperman), hasLength(1));
      expect(shoe.cards.where((c) => c.isMan), hasLength(3));
    });
  });

  group('Showing to see the joker', () {
    test('it fills one card of a pure sequence, anywhere in the run', () {
      expect(isPureSetWithSuperman(gappedRun), isTrue);
      expect(
        isPureSetWithSuperman([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.king),
          superman,
        ]),
        isTrue,
      );
      expect(
        isPureSetWithSuperman([
          superman,
          c(Suit.clubs, Rank.two),
          c(Suit.clubs, Rank.three),
        ]),
        isTrue,
        reason: 'A-2-3, with the Superman as the ace',
      );
      expect(
        isPureSetWithSuperman([
          c(Suit.clubs, Rank.four),
          c(Suit.clubs, Rank.five),
          superman,
          c(Suit.clubs, Rank.seven),
        ]),
        isTrue,
      );
    });

    test('it fills one card of a tunnella', () {
      final king = c(Suit.spades, Rank.king);
      expect(isPureSetWithSuperman([king, king, superman]), isTrue);
      expect(isShowPureSet([king, superman, king]), isTrue);
    });

    test('the rest of the set must be pure', () {
      expect(
        isPureSetWithSuperman([
          c(Suit.spades, Rank.five),
          superman,
          c(Suit.hearts, Rank.seven),
        ]),
        isFalse,
        reason: 'mixed suits',
      );
      expect(
        isPureSetWithSuperman([
          c(Suit.spades, Rank.five),
          superman,
          c(Suit.spades, Rank.eight),
        ]),
        isFalse,
        reason: 'two cards missing',
      );
      expect(
        isPureSetWithSuperman([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.king),
          superman,
        ]),
        isFalse,
        reason: 'a trial is not a pure set',
      );
      expect(
        isPureSetWithSuperman([c(Suit.spades, Rank.five), superman, man]),
        isFalse,
      );
      expect(
        isPureSetWithSuperman([c(Suit.spades, Rank.five), superman]),
        isFalse,
      );
    });

    test('it is not pure by itself', () {
      expect(isPureSequence(gappedRun), isFalse);
      expect(isTunnella([superman, superman, superman]), isFalse);
    });

    test('a hand can show a pure set made with it', () {
      final hand = shownWith([spadesRun, clubsRun, gappedRun]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.shownSets.last, gappedRun);
    });

    test('it is no part of an opening tunnella', () {
      final king = c(Suit.spades, Rank.king);
      expect(isOpeningTunnella([king, king, superman]), isFalse);
      expect(findTunnellas([king, king, superman]), isEmpty);
      expect(
        () => PlayerHand([king, king, superman]).showOpeningTunnellas([
          [king, king, superman],
        ]),
        throwsArgumentError,
      );
    });

    test('it pairs with any card as a doublee', () {
      expect(isShowDoublee([superman, c(Suit.spades, Rank.king)]), isTrue);
      expect(isShowDoublee([c(Suit.spades, Rank.king), superman]), isTrue);
      expect(isShowDoublee([superman, man]), isTrue);
      expect(isDoublee([superman, c(Suit.spades, Rank.king)]), isFalse);
      expect(
        isShowDoublee([c(Suit.spades, Rank.king), c(Suit.clubs, Rank.king)]),
        isFalse,
      );
    });

    test('a hand can show 7 doublees with it', () {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.three,
          Rank.four,
          Rank.five,
          Rank.nine,
          Rank.ten,
        ])
          [c(Suit.clubs, rank), c(Suit.clubs, rank)],
        [superman, c(Suit.hearts, Rank.king)],
      ];
      final hand =
          PlayerHand([
              ...pairs.expand((pair) => pair),
              c(Suit.spades, Rank.king),
            ])
            ..showOpeningTunnellas([])
            ..draw(c(Suit.spades, Rank.queen))
            ..showDoublees(pairs);

      expect(hand.showKind, ShowKind.doublees);
    });
  });

  group('Planning a show', () {
    test('it counts toward the most pure sets a hand can make', () {
      final cards = [...spadesRun, ...gappedRun.where((c) => !c.isSuperman)];

      expect(maxPureSets(cards), 1);
      expect(maxPureSets([...cards, superman]), 2);
    });

    test('it completes a pair into a tunnella', () {
      final king = c(Suit.spades, Rank.king);

      expect(findPureSets([king, king, superman], 1), [
        [king, king, superman],
      ]);
    });

    test('it is used in only one set', () {
      expect(
        maxPureSets([
          c(Suit.spades, Rank.five),
          c(Suit.spades, Rank.seven),
          c(Suit.hearts, Rank.five),
          c(Suit.hearts, Rank.seven),
          superman,
        ]),
        1,
      );
    });

    test('it pairs with a card left over from the real doublees', () {
      final king = c(Suit.spades, Rank.king);
      final queen = c(Suit.hearts, Rank.queen);

      expect(countDoublees([king, king, queen]), 1);
      expect(countDoublees([king, king, queen, superman]), 2);
      expect(countDoublees([king, king, superman]), 1);
      expect(findDoublees([king, king, queen, superman], 2), [
        [king, king],
        [superman, queen],
      ]);
    });

    test('the best arrangement before seeing uses it', () {
      final arrangement = bestArrangement([
        c(Suit.spades, Rank.five),
        c(Suit.spades, Rank.seven),
        superman,
        c(Suit.hearts, Rank.king),
      ], null);

      expect(arrangement, hasLength(1));
      expect(arrangement.single, containsAll([superman]));
    });
  });

  group('After the joker is seen', () {
    test('it is a joker of its own kind', () {
      expect(jokers.kindOf(superman), JokerKind.superman);
      expect(jokers.isWild(superman), isTrue);
    });

    test('it can never be the tiplu', () {
      expect(() => Jokers(superman), throwsArgumentError);
    });

    test('it fills a sequence or a trial', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.two),
          superman,
          c(Suit.spades, Rank.five),
          c(Suit.spades, Rank.three),
        ], jokers),
        isTrue,
      );
      expect(
        isTrialWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.king),
          superman,
        ], jokers),
        isTrue,
      );
    });

    test('it helps a hand split into finishing sets', () {
      expect(
        canSplitIntoSets([
          c(Suit.hearts, Rank.queen),
          superman,
          c(Suit.hearts, Rank.ace),
        ], jokers),
        isTrue,
      );
    });

    test('it makes the 8th doublee', () {
      expect(
        containsDoubleeWithJokers([
          c(Suit.spades, Rank.king),
          superman,
        ], jokers),
        isTrue,
      );
    });
  });

  group('The Superman as maal', () {
    test('is worth 5, held or shown', () {
      final held = shownWith([spadesRun, clubsRun, clubsRun], held: [superman]);
      final shown = shownWith([spadesRun, clubsRun, gappedRun]);

      expect(scoreMaal(held, jokers).superman, 5);
      expect(scoreMaal(shown, jokers).superman, 5);
      expect(scoreMaal(shown, jokers).total, 5);
    });

    test('is worth 5 kept aside from a tiplu pick', () {
      final hand = shownWith([spadesRun, clubsRun, clubsRun])
        ..keepAside(superman);

      expect(scoreMaal(hand, jokers).superman, 5);
    });

    test('counts for nothing until its holder sees the joker', () {
      final unseen = PlayerHand([superman, ...spadesRun])
        ..showOpeningTunnellas([]);

      expect(scoreMaal(unseen, jokers).total, 0);
      expect(kidnappedMaal(unseen, jokers).superman, 5);
    });

    test('adds to the rest of the maal', () {
      final maal = scoreMaal(
        shownWith(
          [spadesRun, clubsRun, gappedRun],
          held: [man, c(Suit.diamonds, Rank.seven)],
        ),
        jokers,
      );

      expect(maal.superman, 5);
      expect(maal.man, 5);
      expect(maal.alter, 5);
      expect(maal.total, 15);
    });
  });
}
