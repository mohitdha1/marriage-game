import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/player_hand.dart';

const c = PlayingCard.new;

// Pure sequences of 3 and 4 cards.
final heartsRun = [
  c(Suit.hearts, Rank.three),
  c(Suit.hearts, Rank.four),
  c(Suit.hearts, Rank.five),
];
final spadesRun = [
  c(Suit.spades, Rank.nine),
  c(Suit.spades, Rank.ten),
  c(Suit.spades, Rank.jack),
  c(Suit.spades, Rank.queen),
];
final diamondsRun = [
  c(Suit.diamonds, Rank.jack),
  c(Suit.diamonds, Rank.queen),
  c(Suit.diamonds, Rank.king),
];

List<PlayingCard> tunnellaOf(Suit suit, Rank rank) => [
  c(suit, rank),
  c(suit, rank),
  c(suit, rank),
];

final kingTunnella = tunnellaOf(Suit.clubs, Rank.king);
final aceTunnella = tunnellaOf(Suit.spades, Rank.ace);
final fourTunnella = tunnellaOf(Suit.diamonds, Rank.four);
final sevenTunnella = tunnellaOf(Suit.hearts, Rank.seven);

// Cards that don't form any set, to pad hands out to 21.
final fillers = [
  c(Suit.clubs, Rank.two),
  c(Suit.clubs, Rank.five),
  c(Suit.clubs, Rank.eight),
  c(Suit.clubs, Rank.jack),
  c(Suit.diamonds, Rank.two),
  c(Suit.diamonds, Rank.six),
  c(Suit.diamonds, Rank.nine),
  c(Suit.spades, Rank.two),
  c(Suit.spades, Rank.six),
  c(Suit.hearts, Rank.ace),
  c(Suit.hearts, Rank.eight),
];

final drawnCard = c(Suit.clubs, Rank.queen);

/// 21 cards with 3 pure sequences and no tunnellas.
List<PlayingCard> noTunnellaCards() => [
  ...heartsRun,
  ...spadesRun,
  ...diamondsRun,
  ...fillers,
];

/// 21 cards with 2 pure sequences and 1 tunnella.
List<PlayingCard> oneTunnellaCards() => [
  ...heartsRun,
  ...spadesRun,
  ...kingTunnella,
  ...fillers,
];

/// A hand that has made its opening show with [openingTunnellas].
PlayerHand openedHand(
  List<PlayingCard> cards, [
  List<List<PlayingCard>> openingTunnellas = const [],
]) => PlayerHand(cards)..showOpeningTunnellas(openingTunnellas);

/// Seven doublees: 2♣2♣, 3♣3♣, … 8♣8♣.
final doublees = [
  for (final rank in [
    Rank.two,
    Rank.three,
    Rank.four,
    Rank.five,
    Rank.six,
    Rank.seven,
    Rank.eight,
  ])
    [c(Suit.clubs, rank), c(Suit.clubs, rank)],
];

/// 21 cards: [doublees] plus 7 unpaired cards, no tunnellas.
List<PlayingCard> doubleesCards() => [
  ...doublees.expand((pair) => pair),
  ...fillers.skip(4).take(7),
];

void main() {
  final jokers = Jokers(c(Suit.hearts, Rank.seven));

  group('PlayerHand before showing', () {
    test('has not opened or seen the joker', () {
      final hand = PlayerHand(noTunnellaCards());

      expect(hand.hasOpened, isFalse);
      expect(hand.hasSeenJoker, isFalse);
      expect(hand.showKind, isNull);
      expect(hand.openingTunnellas, isEmpty);
      expect(hand.shownSets, isEmpty);
      expect(hand.visibleJokers(jokers), isNull);
    });
  });

  group('PlayerHand.showOpeningTunnellas', () {
    test('a hand with no tunnellas opens with an empty show', () {
      final hand = openedHand(noTunnellaCards());

      expect(hand.hasOpened, isTrue);
      expect(hand.openingTunnellas, isEmpty);
      expect(hand.cards.length, 21);
      expect(hand.pureSetsStillNeeded, 3);
    });

    test('a dealt tunnella is laid down and counts toward the 3 sets', () {
      final hand = openedHand(oneTunnellaCards(), [kingTunnella]);

      expect(hand.openingTunnellas, [kingTunnella]);
      expect(hand.cards.length, 18);
      expect(hand.pureSetsStillNeeded, 2);
      expect(hand.hasSeenJoker, isFalse);
    });

    test('every dealt tunnella must be shown', () {
      final hand = PlayerHand([...kingTunnella, ...aceTunnella, ...fillers]);

      expect(
        () => hand.showOpeningTunnellas([kingTunnella]),
        throwsArgumentError,
      );
      expect(() => hand.showOpeningTunnellas([]), throwsArgumentError);
    });

    test('with more than 3 tunnellas, the player picks exactly 3', () {
      final cards = [
        ...kingTunnella,
        ...aceTunnella,
        ...fourTunnella,
        ...sevenTunnella,
        ...fillers.take(9),
      ];

      expect(
        () => PlayerHand(cards).showOpeningTunnellas([
          kingTunnella,
          aceTunnella,
          fourTunnella,
          sevenTunnella,
        ]),
        throwsArgumentError,
      );
      expect(
        () =>
            PlayerHand(cards).showOpeningTunnellas([kingTunnella, aceTunnella]),
        throwsArgumentError,
      );

      final hand = PlayerHand(cards)
        ..showOpeningTunnellas([kingTunnella, aceTunnella, sevenTunnella]);

      expect(hand.openingTunnellas.length, 3);
      expect(hand.pureSetsStillNeeded, 0);
      expect(
        hand.cards.where((card) => card == fourTunnella.first).length,
        3,
        reason: 'the tunnella not picked stays in hand',
      );
    });

    test('a set that is not a tunnella is rejected', () {
      final hand = PlayerHand(oneTunnellaCards());

      expect(() => hand.showOpeningTunnellas([heartsRun]), throwsArgumentError);
    });

    test('a tunnella that is not in the hand is rejected', () {
      final hand = PlayerHand(oneTunnellaCards());

      expect(
        () => hand.showOpeningTunnellas([aceTunnella]),
        throwsArgumentError,
      );
    });

    test('a rejected opening show leaves the hand unchanged', () {
      final hand = PlayerHand(oneTunnellaCards());
      final before = hand.cards;

      expect(() => hand.showOpeningTunnellas([]), throwsArgumentError);
      expect(hand.cards, before);
      expect(hand.hasOpened, isFalse);
    });

    test('the opening show can only be made once', () {
      final hand = openedHand(oneTunnellaCards(), [kingTunnella]);

      expect(() => hand.showOpeningTunnellas([]), throwsStateError);
    });

    test('drawing or showing before the opening show throws', () {
      final hand = PlayerHand(noTunnellaCards());

      expect(() => hand.draw(drawnCard), throwsStateError);
      expect(
        () => hand.showPureSets([heartsRun, spadesRun, diamondsRun]),
        throwsStateError,
      );
    });
  });

  group('PlayerHand draw and discard', () {
    test('drawing adds the card and starts the turn', () {
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);

      expect(hand.cards.length, 22);
      expect(hand.cards, contains(drawnCard));
      expect(hand.hasDrawn, isTrue);
    });

    test('drawing twice without discarding throws', () {
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);

      expect(() => hand.draw(drawnCard), throwsStateError);
    });

    test('discarding removes one copy and ends the turn', () {
      final cards = [...noTunnellaCards(), heartsRun.first];
      final hand = openedHand(cards)
        ..draw(drawnCard)
        ..discard(heartsRun.first);

      expect(hand.cards.length, 22);
      expect(hand.cards.where((card) => card == heartsRun.first).length, 1);
      expect(hand.hasDrawn, isFalse);
    });

    test('discarding before drawing throws', () {
      final hand = openedHand(noTunnellaCards());

      expect(() => hand.discard(fillers.first), throwsStateError);
    });

    test('discarding a card not in the hand throws and keeps the turn', () {
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);

      expect(
        () => hand.discard(c(Suit.hearts, Rank.king)),
        throwsArgumentError,
      );
      expect(hand.hasDrawn, isTrue);
      expect(hand.cards.length, 22);
    });
  });

  group('PlayerHand.showPureSets', () {
    test('after drawing, 3 pure sets sees the joker', () {
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);

      hand.showPureSets([heartsRun, spadesRun, diamondsRun]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.showKind, ShowKind.pureSets);
      expect(hand.shownSets, [heartsRun, spadesRun, diamondsRun]);
      expect(hand.cards.length, 22 - 10);
      expect(hand.visibleJokers(jokers), same(jokers));
    });

    test('an opening tunnella means only 2 more sets are needed', () {
      final hand = openedHand(oneTunnellaCards(), [kingTunnella])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, diamondsRun]),
        throwsArgumentError,
      );

      hand.showPureSets([heartsRun, spadesRun]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.shownSets, [heartsRun, spadesRun]);
      expect(hand.openingTunnellas, [kingTunnella]);
    });

    test('after showing, the player still discards to end the turn', () {
      final hand = openedHand(noTunnellaCards())
        ..draw(drawnCard)
        ..showPureSets([heartsRun, spadesRun, diamondsRun]);

      expect(hand.hasDrawn, isTrue);
      expect(() => hand.draw(fillers.first), throwsStateError);

      hand.discard(drawnCard);
      expect(hand.hasDrawn, isFalse);
      expect(hand.cards.length, 11);
    });

    test('sets ready from the deal can be shown before the first draw', () {
      final hand = openedHand(noTunnellaCards())
        ..showPureSets([heartsRun, spadesRun, diamondsRun]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.hasDrawn, isFalse);
      expect(hand.cards.length, 11);

      // The first turn then carries on as normal.
      hand
        ..draw(drawnCard)
        ..discard(drawnCard);
      expect(hand.cards.length, 11);
    });

    test('3 opening tunnellas see the joker with an empty show', () {
      final hand = openedHand(
        [...kingTunnella, ...aceTunnella, ...fourTunnella, ...fillers],
        [kingTunnella, aceTunnella, fourTunnella],
      )..showPureSets([]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.shownSets, isEmpty);
    });

    test('after the first draw, showing without drawing throws', () {
      final hand = openedHand(noTunnellaCards())
        ..draw(drawnCard)
        ..discard(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, diamondsRun]),
        throwsStateError,
      );
    });

    test('a tunnella completed by drawing counts as a pure set', () {
      // Only 2 kings at the deal, so nothing to open with; drawing the
      // third makes a tunnella, which counts (but isn't an opening one).
      final hand =
          openedHand([
              ...heartsRun,
              ...spadesRun,
              ...kingTunnella.take(2),
              ...fillers,
            ])
            ..draw(kingTunnella.first)
            ..showPureSets([heartsRun, spadesRun, kingTunnella]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.openingTunnellas, isEmpty);
    });

    test('a 5-card pure sequence can be shown', () {
      final longRun = [...spadesRun, c(Suit.spades, Rank.king)];
      final hand = openedHand([...heartsRun, ...longRun, ...diamondsRun])
        ..draw(drawnCard);

      hand.showPureSets([heartsRun, longRun, diamondsRun]);

      expect(hand.hasSeenJoker, isTrue);
    });

    test('a trial does not count as a pure set', () {
      final trial = [
        c(Suit.clubs, Rank.ace),
        c(Suit.spades, Rank.ace),
        c(Suit.diamonds, Rank.ace),
      ];
      final hand = openedHand([...heartsRun, ...spadesRun, ...trial])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, trial]),
        throwsArgumentError,
      );
    });

    test('a sequence needing a joker does not count as pure', () {
      // 7♣ would be wild with tiplu 7♥, but before seeing the joker it's
      // just a 7, so 3♠-7♣-5♠ isn't a sequence.
      final jokerRun = [
        c(Suit.spades, Rank.three),
        c(Suit.clubs, Rank.seven),
        c(Suit.spades, Rank.five),
      ];
      final hand = openedHand([...heartsRun, ...spadesRun, ...jokerRun])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, jokerRun]),
        throwsArgumentError,
      );
    });

    test('showing cards that are not in the hand throws', () {
      final hand = openedHand([...heartsRun, ...spadesRun, ...fillers])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, diamondsRun]),
        throwsArgumentError,
      );
    });

    test('the same card cannot be used in two sets', () {
      // Only one copy of 3♥-4♥-5♥ is held, so it can't be shown twice.
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, heartsRun, diamondsRun]),
        throwsArgumentError,
      );
    });

    test('a rejected show leaves the hand unchanged', () {
      final hand = openedHand(noTunnellaCards())..draw(drawnCard);
      final before = hand.cards;

      expect(
        () => hand.showPureSets([heartsRun, heartsRun, diamondsRun]),
        throwsArgumentError,
      );
      expect(hand.cards, before);
      expect(hand.shownSets, isEmpty);
      expect(hand.hasSeenJoker, isFalse);
    });

    test('a show that would leave nothing to discard throws', () {
      final hand = openedHand([
        ...heartsRun,
        ...spadesRun.take(3),
        ...kingTunnella.take(2),
      ])..draw(kingTunnella.first);

      expect(
        () => hand.showPureSets([
          heartsRun,
          spadesRun.take(3).toList(),
          kingTunnella,
        ]),
        throwsArgumentError,
      );
    });

    test('a player cannot show a second time', () {
      final hand = openedHand(noTunnellaCards())
        ..draw(drawnCard)
        ..showPureSets([heartsRun, spadesRun, diamondsRun])
        ..discard(drawnCard)
        ..draw(drawnCard);

      expect(() => hand.showDoublees(doublees), throwsStateError);
      expect(
        () => hand.showPureSets([heartsRun, spadesRun, diamondsRun]),
        throwsStateError,
      );
    });
  });

  group('PlayerHand.showDoublees', () {
    test('showing 7 doublees after drawing sees the joker', () {
      final hand = openedHand(doubleesCards())..draw(drawnCard);

      hand.showDoublees(doublees);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.showKind, ShowKind.doublees);
      expect(hand.shownSets, doublees);
      expect(hand.cards.length, 22 - 14);
      expect(hand.visibleJokers(jokers), same(jokers));
    });

    test('doublees cannot be shown before the first draw', () {
      final hand = openedHand(doubleesCards());

      expect(() => hand.showDoublees(doublees), throwsStateError);
    });

    test('showing fewer than 7 doublees throws', () {
      final hand = openedHand(doubleesCards())..draw(drawnCard);

      expect(
        () => hand.showDoublees(doublees.take(6).toList()),
        throwsArgumentError,
      );
    });

    test('a pair of the same rank in different suits is not a doublee', () {
      final mixedPair = [c(Suit.hearts, Rank.nine), c(Suit.spades, Rank.nine)];
      final hand = openedHand([
        ...doublees.take(6).expand((pair) => pair),
        ...mixedPair,
      ])..draw(drawnCard);

      expect(
        () => hand.showDoublees([...doublees.take(6), mixedPair]),
        throwsArgumentError,
      );
    });
  });
}
