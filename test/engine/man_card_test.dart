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
const man = PlayingCard.man();

// Tiplu 7♥: every 7 plus 6♥ (jhiplu) and 8♥ (poplu) is wild, and so is
// every man card.
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
final diamondsRun = [
  c(Suit.diamonds, Rank.jack),
  c(Suit.diamonds, Rank.queen),
  c(Suit.diamonds, Rank.king),
];

/// A hand that has opened with [opening] and seen the joker by showing
/// 3 − opening count pure sets, still holding [held]. Man cards in [held]
/// are drawn after the opening, each in place of a plain heart, so three
/// of them aren't an opening tunnella. A plain 5♥ is drawn before the show.
PlayerHand seenHand({
  List<PlayingCard> held = const [],
  List<List<PlayingCard>> opening = const [],
}) {
  final sets = [spadesRun, clubsRun, diamondsRun].skip(opening.length);
  final swapped = [
    c(Suit.hearts, Rank.two),
    c(Suit.hearts, Rank.three),
    c(Suit.hearts, Rank.four),
  ].take(held.where((c) => c.isMan).length);
  final hand = PlayerHand([
    ...opening.expand((t) => t),
    ...sets.expand((s) => s),
    ...held.where((c) => !c.isMan),
    ...swapped,
  ])..showOpeningTunnellas(opening);
  for (final out in swapped) {
    hand
      ..draw(man)
      ..discard(out);
  }
  hand
    ..draw(c(Suit.hearts, Rank.five))
    ..showPureSets(sets.toList());
  // The joker is seen with the discard that ends the show's turn; the same
  // card comes back next turn, so the hand holds what it did.
  final out = hand.cards.first;
  return hand
    ..discard(out)
    ..draw(out);
}

void main() {
  group('The man card', () {
    test('all man cards are equal, and unlike any natural card', () {
      expect(const PlayingCard.man(), man);
      expect(man.isMan, isTrue);
      expect(man.suit, isNull);
      expect(man.rank, isNull);
      expect(c(Suit.spades, Rank.two).isMan, isFalse);
      expect(man, isNot(c(Suit.spades, Rank.two)));
      expect('$man', 'Man');
    });

    test('cardIndex gives each kind of card its own number', () {
      final cards = [
        for (final suit in Suit.values)
          for (final rank in Rank.values) c(suit, rank),
        man,
      ];
      expect(cards.map(cardIndex).toSet(), hasLength(53));
      expect(cardIndex(man), 52);
    });
  });

  group('The shoe', () {
    test('has no man cards unless they are on', () {
      expect(
        Shoe.fromConfig(GameConfig()).cards.where((c) => c.isMan),
        isEmpty,
      );
    });

    test('has one man card per deck when they are on', () {
      final shoe = Shoe.fromConfig(GameConfig(manCardsEnabled: true));

      expect(shoe.length, 3 * 52 + 3);
      expect(shoe.cards.where((c) => c.isMan), hasLength(3));
    });
  });

  group('Before the joker is seen, a man card is dead', () {
    test('it is in no pure sequence or trial', () {
      expect(isPureSequence([...spadesRun.take(2), man]), isFalse);
      expect(isPureSequence([man, man, man]), isFalse);
      expect(
        isTrial([c(Suit.spades, Rank.two), c(Suit.clubs, Rank.two), man]),
        isFalse,
      );
    });

    test('two make no doublee', () {
      expect(isDoublee([man, man]), isFalse);
      expect(countDoublees([man, man, man]), 0);
    });

    test('they cannot be shown as doublees', () {
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
        [man, man],
      ];
      final hand =
          PlayerHand([
              ...pairs.expand((pair) => pair),
              c(Suit.spades, Rank.king),
            ])
            ..showOpeningTunnellas([])
            ..draw(c(Suit.spades, Rank.queen));

      expect(() => hand.showDoublees(pairs), throwsArgumentError);
    });

    test('three are no tunnella to show for the joker', () {
      expect(isTunnella([man, man, man]), isFalse);
      final hand = PlayerHand([...spadesRun, ...clubsRun, man, man, man])
        ..showOpeningTunnellas([
          [man, man, man],
        ]);

      expect(
        () => hand.showPureSets([spadesRun, clubsRun]),
        returnsNormally,
        reason: 'only the opening show takes all three',
      );
      expect(allPureSetChoices([man, man, man], 1), isEmpty);
    });
  });

  group('Three man cards at the deal', () {
    test('are an opening tunnella', () {
      expect(isOpeningTunnella([man, man, man]), isTrue);
      expect(findTunnellas([man, c(Suit.spades, Rank.two), man, man]), [
        [man, man, man],
      ]);
    });

    test('must be shown in the opening, like any tunnella', () {
      final hand = PlayerHand([man, man, man, ...spadesRun]);

      expect(() => hand.showOpeningTunnellas([]), throwsArgumentError);
      hand.showOpeningTunnellas([
        [man, man, man],
      ]);
      expect(hand.openingTunnellas, [
        [man, man, man],
      ]);
    });
  });

  group('After the joker is seen, a man card is wild', () {
    test('it is a joker of its own kind', () {
      expect(jokers.kindOf(man), JokerKind.man);
      expect(jokers.isWild(man), isTrue);
    });

    test('it can never be the tiplu', () {
      expect(() => Jokers(man), throwsArgumentError);
    });

    test('it fills a sequence or a trial', () {
      expect(
        isSequenceWithJokers([
          c(Suit.spades, Rank.two),
          man,
          c(Suit.spades, Rank.four),
        ], jokers),
        isTrue,
      );
      expect(
        isTrialWithJokers([
          c(Suit.spades, Rank.king),
          c(Suit.clubs, Rank.king),
          man,
        ], jokers),
        isTrue,
      );
    });

    test('a set still needs one natural card', () {
      expect(isSequenceWithJokers([man, man, man], jokers), isFalse);
      expect(isFinishingSet([man, man, man], jokers), isFalse);
    });

    test('it helps a hand split into finishing sets', () {
      expect(
        canSplitIntoSets([
          c(Suit.hearts, Rank.queen),
          c(Suit.hearts, Rank.king),
          man,
          c(Suit.clubs, Rank.two),
          c(Suit.diamonds, Rank.two),
          man,
        ], jokers),
        isTrue,
      );
    });

    test('it makes the 8th doublee', () {
      expect(
        containsDoubleeWithJokers([c(Suit.spades, Rank.king), man], jokers),
        isTrue,
      );
    });
  });

  group('Man cards as maal', () {
    test('1, 2 and 3 are worth 5, 15 and 25', () {
      expect(scoreMaal(seenHand(held: [man]), jokers).man, 5);
      expect(scoreMaal(seenHand(held: [man, man]), jokers).man, 15);
      expect(scoreMaal(seenHand(held: [man, man, man]), jokers).man, 25);
    });

    test('three shown in the opening are a tunnella worth 35', () {
      final maal = scoreMaal(
        seenHand(
          opening: [
            [man, man, man],
          ],
        ),
        jokers,
      );

      expect(maal.tunnellas, 35);
      expect(maal.man, 0, reason: 'already counted in the tunnella');
      expect(maal.total, 35);
    });

    test('one kept aside from a tiplu pick counts with those held', () {
      final aside = seenHand()..keepAside(man);
      final both = seenHand(held: [man])..keepAside(man);

      expect(scoreMaal(aside, jokers).man, 5);
      expect(scoreMaal(both, jokers).man, 15);
    });

    test('only a player who has shown keeps one aside', () {
      final unseen = PlayerHand([...spadesRun])..showOpeningTunnellas([]);

      expect(() => unseen.keepAside(man), throwsStateError);
    });

    test('they count for nothing until their holder sees the joker', () {
      final unseen = PlayerHand([man, man, ...spadesRun])
        ..showOpeningTunnellas([]);

      expect(scoreMaal(unseen, jokers).total, 0);
    });

    test('they add to the rest of the maal', () {
      final maal = scoreMaal(
        seenHand(held: [man, c(Suit.diamonds, Rank.seven)]),
        jokers,
      );

      expect(maal.man, 5);
      expect(maal.alter, 5);
      expect(maal.total, 10);
    });
  });
}
