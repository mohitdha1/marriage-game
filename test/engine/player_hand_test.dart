import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/player_hand.dart';

const c = PlayingCard.new;

// Three pure sets: a 3-card sequence, a 4-card sequence, and a tunnella.
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
final kingTunnella = [
  c(Suit.diamonds, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.diamonds, Rank.king),
];

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

/// A 21-card hand holding [heartsRun], [spadesRun] and [kingTunnella].
PlayerHand pureSetsHand() =>
    PlayerHand([...heartsRun, ...spadesRun, ...kingTunnella, ...fillers]);

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

/// A 21-card hand holding [doublees] plus 7 unpaired cards.
PlayerHand doubleesHand() => PlayerHand([
  ...doublees.expand((pair) => pair),
  ...fillers.skip(4).take(7),
]);

void main() {
  final jokers = Jokers(c(Suit.hearts, Rank.seven));

  group('PlayerHand before showing', () {
    test('has not seen the joker and cannot see the round jokers', () {
      final hand = pureSetsHand();

      expect(hand.hasSeenJoker, isFalse);
      expect(hand.showKind, isNull);
      expect(hand.shownSets, isEmpty);
      expect(hand.visibleJokers(jokers), isNull);
    });
  });

  group('PlayerHand draw and discard', () {
    test('drawing adds the card and starts the turn', () {
      final hand = pureSetsHand()..draw(drawnCard);

      expect(hand.cards.length, 22);
      expect(hand.cards, contains(drawnCard));
      expect(hand.hasDrawn, isTrue);
    });

    test('drawing twice without discarding throws', () {
      final hand = pureSetsHand()..draw(drawnCard);

      expect(() => hand.draw(drawnCard), throwsStateError);
    });

    test('discarding removes one copy and ends the turn', () {
      final hand = pureSetsHand()
        ..draw(drawnCard)
        ..discard(kingTunnella.first);

      expect(hand.cards.length, 21);
      expect(hand.cards.where((card) => card == kingTunnella.first).length, 2);
      expect(hand.hasDrawn, isFalse);
    });

    test('discarding before drawing throws', () {
      final hand = pureSetsHand();

      expect(() => hand.discard(fillers.first), throwsStateError);
    });

    test('discarding a card not in the hand throws and keeps the turn', () {
      final hand = pureSetsHand()..draw(drawnCard);

      expect(
        () => hand.discard(c(Suit.hearts, Rank.king)),
        throwsArgumentError,
      );
      expect(hand.hasDrawn, isTrue);
      expect(hand.cards.length, 22);
    });
  });

  group('PlayerHand.showPureSets', () {
    test('showing 3 pure sets after drawing sees the joker', () {
      final hand = pureSetsHand()..draw(drawnCard);

      hand.showPureSets([heartsRun, spadesRun, kingTunnella]);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.showKind, ShowKind.pureSets);
      expect(hand.shownSets, [heartsRun, spadesRun, kingTunnella]);
      expect(hand.cards.length, 22 - 10);
      expect(hand.visibleJokers(jokers), same(jokers));
    });

    test('after showing, the player still discards to end the turn', () {
      final hand = pureSetsHand()
        ..draw(drawnCard)
        ..showPureSets([heartsRun, spadesRun, kingTunnella]);

      expect(hand.hasDrawn, isTrue);
      expect(() => hand.draw(fillers.first), throwsStateError);

      hand.discard(drawnCard);
      expect(hand.hasDrawn, isFalse);
      expect(hand.cards.length, 11);
    });

    test('a 5-card pure sequence can be shown', () {
      final longRun = [...spadesRun, c(Suit.spades, Rank.king)];
      final hand = PlayerHand([...heartsRun, ...longRun, ...kingTunnella])
        ..draw(drawnCard);

      hand.showPureSets([heartsRun, longRun, kingTunnella]);

      expect(hand.hasSeenJoker, isTrue);
    });

    test('showing before drawing throws', () {
      final hand = pureSetsHand();

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, kingTunnella]),
        throwsStateError,
      );
    });

    test('showing fewer or more than 3 sets throws', () {
      final hand = pureSetsHand()..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun]),
        throwsArgumentError,
      );
      expect(
        () =>
            hand.showPureSets([heartsRun, spadesRun, kingTunnella, heartsRun]),
        throwsArgumentError,
      );
    });

    test('a trial does not count as a pure set', () {
      final trial = [
        c(Suit.clubs, Rank.ace),
        c(Suit.spades, Rank.ace),
        c(Suit.diamonds, Rank.ace),
      ];
      final hand = PlayerHand([...heartsRun, ...spadesRun, ...trial])
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
      final hand = PlayerHand([...heartsRun, ...spadesRun, ...jokerRun])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, jokerRun]),
        throwsArgumentError,
      );
    });

    test('showing cards that are not in the hand throws', () {
      final hand = PlayerHand([...heartsRun, ...spadesRun, ...fillers])
        ..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, spadesRun, kingTunnella]),
        throwsArgumentError,
      );
    });

    test('the same card cannot be used in two sets', () {
      // Only one copy of 3♥-4♥-5♥ is held, so it can't be shown twice.
      final hand = pureSetsHand()..draw(drawnCard);

      expect(
        () => hand.showPureSets([heartsRun, heartsRun, kingTunnella]),
        throwsArgumentError,
      );
    });

    test('a rejected show leaves the hand unchanged', () {
      final hand = pureSetsHand()..draw(drawnCard);
      final before = hand.cards;

      expect(
        () => hand.showPureSets([heartsRun, heartsRun, kingTunnella]),
        throwsArgumentError,
      );
      expect(hand.cards, before);
      expect(hand.shownSets, isEmpty);
      expect(hand.hasSeenJoker, isFalse);
    });

    test('a show that would leave nothing to discard throws', () {
      final hand = PlayerHand([
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
      final hand = pureSetsHand()
        ..draw(drawnCard)
        ..showPureSets([heartsRun, spadesRun, kingTunnella])
        ..discard(drawnCard)
        ..draw(drawnCard);

      expect(() => hand.showDoublees(doublees), throwsStateError);
      expect(
        () => hand.showPureSets([heartsRun, spadesRun, kingTunnella]),
        throwsStateError,
      );
    });
  });

  group('PlayerHand.showDoublees', () {
    test('showing 7 doublees after drawing sees the joker', () {
      final hand = doubleesHand()..draw(drawnCard);

      hand.showDoublees(doublees);

      expect(hand.hasSeenJoker, isTrue);
      expect(hand.showKind, ShowKind.doublees);
      expect(hand.shownSets, doublees);
      expect(hand.cards.length, 22 - 14);
      expect(hand.visibleJokers(jokers), same(jokers));
    });

    test('showing fewer than 7 doublees throws', () {
      final hand = doubleesHand()..draw(drawnCard);

      expect(
        () => hand.showDoublees(doublees.take(6).toList()),
        throwsArgumentError,
      );
    });

    test('a pair of the same rank in different suits is not a doublee', () {
      final mixedPair = [c(Suit.hearts, Rank.nine), c(Suit.spades, Rank.nine)];
      final hand = PlayerHand([
        ...doublees.take(6).expand((pair) => pair),
        ...mixedPair,
      ])..draw(drawnCard);

      expect(
        () => hand.showDoublees([...doublees.take(6), mixedPair]),
        throwsArgumentError,
      );
    });

    test('showing before drawing throws', () {
      final hand = doubleesHand();

      expect(() => hand.showDoublees(doublees), throwsStateError);
    });
  });
}
