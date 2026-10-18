import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/shoe.dart';
import 'package:marriage_game/engine/table_event.dart';

const c = PlayingCard.new;

// --- A small two-player table where 7♥ will be picked as the tiplu. -------
// Once it is: every 7 plus 6♥ (jhiplu) and 8♥ (poplu) is wild.

final tiplu = c(Suit.hearts, Rank.seven);

// Seat 0: three pure sequences to show, then K♠ K♦ 7♣ (a trial with a
// joker), 10♦ J♦ 8♥ (a sequence with a joker, once Q♦ is drawn), and 2♦ to
// discard.
final runA = [
  c(Suit.hearts, Rank.three),
  c(Suit.hearts, Rank.four),
  c(Suit.hearts, Rank.five),
];
final runB = [
  c(Suit.spades, Rank.two),
  c(Suit.spades, Rank.three),
  c(Suit.spades, Rank.four),
];
final runC = [
  c(Suit.clubs, Rank.nine),
  c(Suit.clubs, Rank.ten),
  c(Suit.clubs, Rank.jack),
];
final seat0Cards = [
  ...runA,
  ...runB,
  ...runC,
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.ten),
  c(Suit.diamonds, Rank.jack),
  c(Suit.hearts, Rank.eight),
  c(Suit.diamonds, Rank.two),
];

// Seat 1: three pure sequences, then 8♥ Q♣ Q♦ (a trial with a joker).
final runD = [
  c(Suit.spades, Rank.jack),
  c(Suit.spades, Rank.queen),
  c(Suit.spades, Rank.king),
];
final runE = [
  c(Suit.clubs, Rank.four),
  c(Suit.clubs, Rank.five),
  c(Suit.clubs, Rank.six),
];
final runF = [
  c(Suit.diamonds, Rank.ace),
  c(Suit.diamonds, Rank.two),
  c(Suit.diamonds, Rank.three),
];
final seat1Cards = [
  ...runD,
  ...runE,
  ...runF,
  c(Suit.hearts, Rank.eight),
  c(Suit.clubs, Rank.queen),
  c(Suit.diamonds, Rank.queen),
];

// Stock, bottom first. From the top: Q♦ (0), 2♣ (1), 7♥ (2), 5♣ (3).
final stock = [
  c(Suit.clubs, Rank.five),
  tiplu,
  c(Suit.clubs, Rank.two),
  c(Suit.diamonds, Rank.queen),
];
final firstDiscard = c(Suit.clubs, Rank.king);

Round table({
  GameConfig? config,
  List<PlayingCard>? stockCards,
  List<PlayingCard>? discardPile,
  List<PlayingCard>? seat0,
  bool open = true,
}) {
  final round = Round.fromCards(
    config: config ?? GameConfig(playerCount: 2),
    random: Random(0),
    hands: [seat0 ?? seat0Cards, seat1Cards],
    stock: stockCards ?? stock,
    discardPile: discardPile ?? [firstDiscard],
  );
  if (open) {
    round
      ..showOpeningTunnellas(0, [])
      ..showOpeningTunnellas(1, []);
  }
  return round;
}

/// Seat 0 draws Q♦ and shows, picking 7♥ (now at position 1) as the tiplu.
Round seat0HasShown({GameConfig? config}) => table(config: config)
  ..draw(DrawSource.stock)
  ..showPureSets([runA, runB, runC], tipluPosition: 1);

int cardsHeldBy(PlayerHand hand) =>
    hand.cards.length +
    hand.shownSets.expand((set) => set).length +
    hand.openingTunnellas.expand((set) => set).length;

void main() {
  group('Round.deal', () {
    test('deals every hand and turns up one card to start the discards', () {
      final round = Round.deal(config: GameConfig(), random: Random(1));

      expect(round.hands.length, 5);
      expect(round.hands.every((hand) => hand.cards.length == 21), isTrue);
      expect(round.topDiscard, isNotNull);
      expect(round.discardPileCount, 1);
      expect(round.stockCount, 156 - 5 * 21 - 1);
      expect(round.currentSeat, 0);
    });

    test('no joker is chosen at the deal', () {
      final round = Round.deal(config: GameConfig(), random: Random(1));

      expect(round.isJokerChosen, isFalse);
      expect(round.jokersFor(0), isNull);
    });

    test('the same seed deals the same round', () {
      final a = Round.deal(config: GameConfig(), random: Random(9));
      final b = Round.deal(config: GameConfig(), random: Random(9));

      expect(a.hands.map((h) => h.cards), b.hands.map((h) => h.cards));
      expect(a.topDiscard, b.topDiscard);
    });

    test('play starts at firstSeat', () {
      final round = Round.deal(
        config: GameConfig(),
        random: Random(1),
        firstSeat: 3,
      );

      expect(round.currentSeat, 3);
    });

    test('firstSeat must be a seat at the table', () {
      expect(
        () => Round.deal(config: GameConfig(), random: Random(1), firstSeat: 5),
        throwsArgumentError,
      );
    });

    test('fromCards needs one hand per player', () {
      expect(
        () => Round.fromCards(
          config: GameConfig(playerCount: 3),
          random: Random(0),
          hands: [seat0Cards, seat1Cards],
          stock: stock,
          discardPile: [firstDiscard],
        ),
        throwsArgumentError,
      );
    });
  });

  group('Opening shows', () {
    test('nobody can draw until every player has opened', () {
      final round = table(open: false)..showOpeningTunnellas(0, []);

      expect(() => round.draw(DrawSource.stock), throwsStateError);

      round.showOpeningTunnellas(1, []);
      expect(() => round.draw(DrawSource.stock), returnsNormally);
    });

    test('nobody can show until every player has opened', () {
      final round = table(open: false)..showOpeningTunnellas(0, []);

      expect(
        () => round.showPureSets([runA, runB, runC], tipluPosition: 0),
        throwsStateError,
      );
    });
  });

  group('Turns', () {
    test(
      'the card taken from the discard pile is known until the turn ends',
      () {
        final round = table();
        expect(round.takenFromDiscardPile, isNull);

        round.draw(DrawSource.discardPile);
        expect(round.takenFromDiscardPile, firstDiscard);

        round.discard(
          round.hands[0].cards.firstWhere((c) => c != firstDiscard),
        );
        expect(round.takenFromDiscardPile, isNull);

        round.draw(DrawSource.stock);
        expect(
          round.takenFromDiscardPile,
          isNull,
          reason: 'drew from the stock',
        );
      },
    );

    test('drawing from the stock takes its top card', () {
      final round = table();

      expect(round.draw(DrawSource.stock), c(Suit.diamonds, Rank.queen));
      expect(round.stockCount, 3);
      expect(round.hands[0].hasDrawn, isTrue);
    });

    test('discarding passes the turn on, wrapping round the table', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..discard(c(Suit.diamonds, Rank.two));

      expect(round.currentSeat, 1);
      expect(round.topDiscard, c(Suit.diamonds, Rank.two));

      round
        ..draw(DrawSource.stock)
        ..discard(c(Suit.clubs, Rank.queen));
      expect(round.currentSeat, 0);
    });

    test('a player can take the top discard instead of drawing', () {
      final round = table();

      expect(round.draw(DrawSource.discardPile), firstDiscard);
      expect(round.topDiscard, isNull);
      expect(round.hands[0].cards, contains(firstDiscard));
    });

    test('the first player may take the turned-up card', () {
      final round = table()..draw(DrawSource.discardPile);

      expect(round.hands[0].cards.length, seat0Cards.length + 1);
    });

    test(
      'a card taken from the discard pile cannot be discarded that turn',
      () {
        final round = table()..draw(DrawSource.discardPile);

        expect(() => round.discard(firstDiscard), throwsArgumentError);
        expect(round.currentSeat, 0, reason: 'still seat 0\'s turn');

        round.discard(c(Suit.diamonds, Rank.two));
        expect(round.currentSeat, 1);
      },
    );

    test('a card drawn from the stock can be discarded straight away', () {
      final round = table();
      final drawn = round.draw(DrawSource.stock);

      expect(() => round.discard(drawn), returnsNormally);
    });

    test('drawing from an empty discard pile throws', () {
      final round = table(discardPile: []);

      expect(() => round.draw(DrawSource.discardPile), throwsStateError);
    });

    test('a player cannot draw twice in one turn', () {
      final round = table()..draw(DrawSource.stock);

      expect(() => round.draw(DrawSource.stock), throwsStateError);
    });
  });

  group('Empty stock', () {
    test('the discards, except the top card, are reshuffled as the stock', () {
      final a = c(Suit.clubs, Rank.ace);
      final b = c(Suit.spades, Rank.nine);
      final top = c(Suit.spades, Rank.eight);
      final round = table(stockCards: [], discardPile: [a, b, top]);

      final drawn = round.draw(DrawSource.stock);

      expect([a, b], contains(drawn));
      expect(round.topDiscard, top);
      expect(round.stockCount, 1);
      expect(round.discardPileCount, 1);
    });

    test('with nothing left to reshuffle, drawing from the stock throws', () {
      final round = table(stockCards: [], discardPile: [firstDiscard]);

      expect(() => round.draw(DrawSource.stock), throwsStateError);
    });
  });

  group('Picking the tiplu', () {
    test('the first player to show picks it from the stock', () {
      final round = seat0HasShown();

      expect(round.isJokerChosen, isTrue);
      expect(round.jokersFor(0)!.tiplu, tiplu);
      expect(round.stockCount, 2, reason: 'Q♦ drawn, 7♥ taken out');
    });

    test('players who have not shown cannot see it', () {
      final round = seat0HasShown();

      expect(round.jokersFor(1), isNull);
    });

    test('sets ready from the deal can be shown, and the tiplu picked, '
        'before the first draw', () {
      final round = table()..showPureSets([runA, runB, runC], tipluPosition: 2);

      expect(round.jokersFor(0)!.tiplu, tiplu);
      expect(round.hands[0].hasDrawn, isFalse);
    });

    test('the first player to show must pick a position', () {
      final round = table()..draw(DrawSource.stock);

      expect(() => round.showPureSets([runA, runB, runC]), throwsArgumentError);
      expect(
        () => round.showPureSets([runA, runB, runC], tipluPosition: 3),
        throwsArgumentError,
        reason: 'only 3 cards left in the stock',
      );
      expect(round.hands[0].hasSeenJoker, isFalse);
      expect(round.isJokerChosen, isFalse);
    });

    test('a rejected show does not use up the tiplu', () {
      final round = table()..draw(DrawSource.stock);

      expect(
        () => round.showPureSets([runA, runB, runD], tipluPosition: 1),
        throwsArgumentError,
      );
      expect(round.isJokerChosen, isFalse);
      expect(round.stockCount, 3);
    });

    test('later players see the same tiplu and must not pick another', () {
      final round = seat0HasShown()
        ..discard(c(Suit.diamonds, Rank.ten))
        ..draw(DrawSource.stock);

      expect(
        () => round.showPureSets([runD, runE, runF], tipluPosition: 0),
        throwsArgumentError,
      );

      round.showPureSets([runD, runE, runF]);
      expect(round.jokersFor(1)!.tiplu, tiplu);
    });

    test('the tiplu is out of play: it is never drawn, even after the stock '
        'is reshuffled many times', () {
      // With a single deck every card is unique, so "never drawn" is exact.
      final config = GameConfig(deckCount: 1, playerCount: 2);
      final rest = [...Shoe(1).cards];
      for (final card in [...runA, ...runB, ...runC]) {
        rest.remove(card);
      }
      fisherYatesShuffle(rest, Random(3));
      // Two loose cards keep seat 0 from ever holding a winning hand.
      final loose = rest.sublist(0, 2);
      final seat1 = rest.sublist(2, 12);
      final pile = [rest[12]];
      final stockCards = rest.sublist(13);
      final round =
          Round.fromCards(
              config: config,
              random: Random(3),
              hands: [
                [...runA, ...runB, ...runC, ...loose],
                seat1,
              ],
              stock: stockCards,
              discardPile: pile,
            )
            ..showOpeningTunnellas(0, [])
            ..showOpeningTunnellas(1, [])
            ..showPureSets([runA, runB, runC], tipluPosition: 5);
      final chosen = round.jokersFor(0)!.tiplu;

      for (var turn = 0; turn < 300; turn++) {
        final drawn = round.draw(DrawSource.stock);
        expect(drawn, isNot(chosen), reason: 'turn $turn');
        round.discard(drawn);

        final inPlay =
            round.hands.fold(0, (n, h) => n + cardsHeldBy(h)) +
            round.stockCount +
            round.discardPileCount;
        expect(inPlay, 51, reason: 'one card of 52 is out of play');
      }
    });
  });

  group('Winning', () {
    test('draw, show and win all in the same turn', () {
      final round = seat0HasShown()..declareWin(c(Suit.diamonds, Rank.two));

      expect(round.isOver, isTrue);
      expect(round.winner, 0);
      expect(round.topDiscard, c(Suit.diamonds, Rank.two));
    });

    test('a discard that leaves a winning hand wins the round', () {
      final round = seat0HasShown();
      // 2♦ wins, and so does K♠: K♦ with 10♦ J♦ Q♦, and 2♦ 7♣ 8♥ a trial.
      expect(
        round.currentWinningDiscards,
        unorderedEquals([
          c(Suit.diamonds, Rank.two),
          c(Suit.spades, Rank.king),
        ]),
      );

      round.discard(c(Suit.diamonds, Rank.two));

      expect(round.isOver, isTrue);
      expect(round.winner, 0);
      expect(round.topDiscard, c(Suit.diamonds, Rank.two));
      expect(round.events.last, isA<WonRound>());
      expect(round.currentWinningDiscards, isEmpty);
      // Saved and played again, it's the same win.
      final replayed = Round.replay(
        config: round.config,
        random: Random(0),
        start: round.start,
        log: round.log,
      );
      expect(replayed.winner, 0);
    });

    test('any other discard passes the turn as usual', () {
      final round = seat0HasShown()..discard(c(Suit.diamonds, Rank.ten));

      expect(round.isOver, isFalse);
      expect(round.currentSeat, 1);
      expect(round.events.last, isA<DiscardedCard>());
    });

    test('no winning discards before drawing or seeing the joker', () {
      expect(table().currentWinningDiscards, isEmpty);
      expect((table()..draw(DrawSource.stock)).currentWinningDiscards, isEmpty);
    });

    test('the card just taken from the discard pile is never a winning '
        'discard, so discarding it is refused rather than winning', () {
      // Seat 0 takes a second 2♦; discarding a 2♦ would win, but a card
      // matching the one just taken must be kept this turn.
      final round = table(discardPile: [c(Suit.diamonds, Rank.two)])
        ..draw(DrawSource.discardPile)
        ..showPureSets([runA, runB, runC], tipluPosition: 2);

      expect(round.currentWinningDiscards, isEmpty);
      expect(
        () => round.discard(c(Suit.diamonds, Rank.two)),
        throwsArgumentError,
      );
      expect(round.isOver, isFalse);
    });

    test('a discard that leaves an unsplittable hand is rejected', () {
      final round = seat0HasShown();

      // Discarding 10♦ instead leaves K♠ K♦ 7♣ J♦ Q♦ 8♥ 2♦, which can't
      // all be made into sets.
      expect(
        () => round.declareWin(c(Suit.diamonds, Rank.ten)),
        throwsArgumentError,
      );
      expect(round.isOver, isFalse);
      expect(round.currentSeat, 0);
      expect(round.hands[0].cards, contains(c(Suit.diamonds, Rank.ten)));
    });

    test('a card that is not in the hand cannot be the final discard', () {
      final round = seat0HasShown();

      expect(
        () => round.declareWin(c(Suit.hearts, Rank.ace)),
        throwsArgumentError,
      );
    });

    test('a player who has not seen the joker cannot win', () {
      final round = table()..draw(DrawSource.stock);

      expect(
        () => round.declareWin(c(Suit.diamonds, Rank.two)),
        throwsStateError,
      );
    });

    test('a player must draw before winning', () {
      final round = table()..showPureSets([runA, runB, runC], tipluPosition: 2);

      expect(
        () => round.declareWin(c(Suit.diamonds, Rank.two)),
        throwsStateError,
      );
    });

    test('the card just taken from the discard pile cannot be the final '
        'discard', () {
      final round = table(discardPile: [c(Suit.diamonds, Rank.two)])
        ..draw(DrawSource.discardPile)
        ..showPureSets([runA, runB, runC], tipluPosition: 2);

      expect(
        () => round.declareWin(c(Suit.diamonds, Rank.two)),
        throwsArgumentError,
      );
    });

    test('a dublee player wins with an 8th doublee, jokers allowed', () {
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
      Round dubleeTable(List<PlayingCard> extras) =>
          table(seat0: [...pairs.expand((pair) => pair), ...extras])
            ..draw(DrawSource.stock) // Q♦
            ..showDoublees(pairs, tipluPosition: 1);

      // A joker (7♣) pairs with K♠.
      final withJoker = dubleeTable([
        c(Suit.clubs, Rank.seven),
        c(Suit.spades, Rank.king),
      ])..declareWin(c(Suit.diamonds, Rank.queen));
      expect(withJoker.winner, 0);

      // Two jokers (7♣ and 8♥) also make the 8th doublee.
      final twoJokers = dubleeTable([
        c(Suit.clubs, Rank.seven),
        c(Suit.hearts, Rank.eight),
      ])..declareWin(c(Suit.diamonds, Rank.queen));
      expect(twoJokers.winner, 0);

      // K♠ and A♥: no pair, no joker.
      final noPair = dubleeTable([
        c(Suit.spades, Rank.king),
        c(Suit.hearts, Rank.ace),
      ]);
      expect(
        () => noPair.declareWin(c(Suit.diamonds, Rank.queen)),
        throwsArgumentError,
      );
    });

    test('nothing can happen once the round is over', () {
      final round = seat0HasShown()..declareWin(c(Suit.diamonds, Rank.two));

      expect(() => round.draw(DrawSource.stock), throwsStateError);
      expect(() => round.discard(c(Suit.spades, Rank.king)), throwsStateError);
    });
  });

  group('Joker-discard penalty', () {
    test('a seen player discarding a joker is counted', () {
      final round = seat0HasShown()..discard(c(Suit.clubs, Rank.seven));

      expect(round.jokerDiscards, [1, 0]);
    });

    test('an unseen player discarding a joker is not counted', () {
      final round = seat0HasShown()
        ..discard(c(Suit.diamonds, Rank.ten))
        ..draw(DrawSource.stock)
        ..discard(c(Suit.hearts, Rank.eight));

      expect(round.jokerDiscards, [0, 0]);
    });

    test('nothing is counted when the house rule is off', () {
      final round = seat0HasShown(
        config: GameConfig(playerCount: 2, jokerDiscardPenaltyEnabled: false),
      )..discard(c(Suit.clubs, Rank.seven));

      expect(round.jokerDiscards, [0, 0]);
    });
  });

  group('Man cards', () {
    const man = PlayingCard.man();

    test('discarding one after seeing counts toward the penalty', () {
      final round =
          table(
              seat0: [
                for (final card in seat0Cards)
                  card == c(Suit.diamonds, Rank.two) ? man : card,
              ],
            )
            ..draw(DrawSource.stock)
            ..showPureSets([runA, runB, runC], tipluPosition: 1)
            ..discard(man);

      expect(round.jokerDiscards, [1, 0]);
    });

    // From the top after drawing Q♦: 2♣ (0), a man card (1), another (2),
    // then 5♣ (3).
    Round manInTheStock() => table(
      stockCards: [
        c(Suit.clubs, Rank.five),
        man,
        man,
        c(Suit.clubs, Rank.two),
        c(Suit.diamonds, Rank.queen),
      ],
    )..draw(DrawSource.stock);

    test('one picked as the tiplu is kept aside, and the picker picks '
        'again', () {
      final round = manInTheStock()
        ..showPureSets([runA, runB, runC], tipluPosition: 1);

      expect(round.hands[0].hasSeenJoker, isTrue);
      expect(round.hands[0].keptAside, [man]);
      expect(round.hands[0].cards, isNot(contains(man)));
      expect(round.isJokerChosen, isFalse);
      expect(round.jokersFor(0), isNull);
      expect(round.needsTipluPick, isTrue);
      expect(round.stockCount, 3);
      expect(round.events.last, isA<KeptAside>());

      round.pickTiplu(0);

      expect(round.needsTipluPick, isFalse);
      expect(round.jokersFor(0)!.tiplu, c(Suit.clubs, Rank.two));
      expect(round.hands[0].keptAside, [man]);
    });

    test('nothing else can happen until the tiplu is picked', () {
      final round = manInTheStock()
        ..showPureSets([runA, runB, runC], tipluPosition: 1);

      expect(() => round.discard(c(Suit.diamonds, Rank.two)), throwsStateError);
      expect(
        () => round.declareWin(c(Suit.diamonds, Rank.two)),
        throwsStateError,
      );
      expect(() => round.pickTiplu(9), throwsArgumentError);
      expect(round.needsTipluPick, isTrue);
    });

    test('another man card is kept aside too, and the pick goes on', () {
      final round = manInTheStock()
        ..showPureSets([runA, runB, runC], tipluPosition: 1)
        ..pickTiplu(1);

      expect(round.hands[0].keptAside, [man, man]);
      expect(round.needsTipluPick, isTrue);

      round.pickTiplu(1);
      expect(round.jokersFor(0)!.tiplu, c(Suit.clubs, Rank.five));
    });

    test('there is no picking again without a man card', () {
      expect(() => seat0HasShown().pickTiplu(0), throwsStateError);
    });
  });

  group('The Superman', () {
    const superman = PlayingCard.superman();
    final withSuperman = [
      for (final card in seat0Cards)
        card == c(Suit.diamonds, Rank.two) ? superman : card,
    ];

    test('discarding it costs the penalty even before seeing', () {
      final round = table(seat0: withSuperman)
        ..draw(DrawSource.stock)
        ..discard(superman);

      expect(round.hands[0].hasSeenJoker, isFalse);
      expect(round.jokerDiscards, [1, 0]);
    });

    test('discarding it costs nothing when the house rule is off', () {
      final round =
          table(
              seat0: withSuperman,
              config: GameConfig(
                playerCount: 2,
                jokerDiscardPenaltyEnabled: false,
              ),
            )
            ..draw(DrawSource.stock)
            ..discard(superman);

      expect(round.jokerDiscards, [0, 0]);
    });

    test('picked as the tiplu, it is kept aside and the picker picks '
        'again', () {
      // From the top after drawing Q♦: 2♣ (0), the Superman (1), 5♣ (2).
      final round =
          table(
              stockCards: [
                c(Suit.clubs, Rank.five),
                superman,
                c(Suit.clubs, Rank.two),
                c(Suit.diamonds, Rank.queen),
              ],
            )
            ..draw(DrawSource.stock)
            ..showPureSets([runA, runB, runC], tipluPosition: 1);

      expect(round.hands[0].keptAside, [superman]);
      expect(round.needsTipluPick, isTrue);
      expect(round.events.last, isA<KeptAside>());

      round.pickTiplu(0);
      expect(round.jokersFor(0)!.tiplu, c(Suit.clubs, Rank.two));
    });
  });

  group('Round.score', () {
    test('cannot score a round that is still being played', () {
      expect(() => table().score(), throwsStateError);
    });

    test('settles the round, including joker-discard penalties', () {
      // Seat 0 shows and discards a joker; seat 1 then shows and wins.
      final round = seat0HasShown()
        ..discard(c(Suit.clubs, Rank.seven))
        ..draw(DrawSource.stock) // 2♣
        ..showPureSets([runD, runE, runF])
        ..declareWin(c(Suit.clubs, Rank.two));

      final score = round.score();

      // Both hold one poplu (8♥): maal 2 each, so maal nets to 0. Seat 0
      // pays 3 (seen) + 15 (joker discard).
      expect(score.winner, 1);
      expect(score.maal.map((m) => m.total), [2, 2]);
      expect(score.penalties, [15, 0]);
      expect(score.net, [-18, 18]);
    });

    test('scores alters as ordinary jokers when they are not maal', () {
      // Seat 0 keeps an alter (7♦) in place of 2♦ and wins with it in a
      // trial: K♠ K♦ 7♦.
      Round wonWith(GameConfig config) {
        final round = table(
          config: config,
          seat0: [
            for (final card in seat0Cards)
              card == c(Suit.clubs, Rank.seven)
                  ? c(Suit.diamonds, Rank.seven)
                  : card,
          ],
        )..draw(DrawSource.stock);
        return round
          ..showPureSets([runA, runB, runC], tipluPosition: 1)
          ..declareWin(c(Suit.diamonds, Rank.two));
      }

      final withAlter = wonWith(GameConfig(playerCount: 2)).score();
      final without = wonWith(
        GameConfig(playerCount: 2, alterIsMaal: false),
      ).score();

      // The poplu (8♥) is 2 either way; the alter adds 5 only when on.
      expect(withAlter.maal.first.total, 2 + 5);
      expect(without.maal.first.total, 2);
    });
  });

  group('Round.events', () {
    test('opening tunnellas are recorded; an empty opening is not', () {
      final kings = [for (var i = 0; i < 3; i++) c(Suit.spades, Rank.king)];
      final round =
          Round.fromCards(
              config: GameConfig(playerCount: 2),
              random: Random(0),
              hands: [
                [...kings, ...runA],
                seat1Cards,
              ],
              stock: stock,
              discardPile: [firstDiscard],
            )
            ..showOpeningTunnellas(0, [kings])
            ..showOpeningTunnellas(1, []);

      expect(round.events, hasLength(1));
      final opened = round.events.single as OpenedTunnellas;
      expect(opened.seat, 0);
      expect(opened.tunnellas, [kings]);
    });

    test('a stock draw hides the card; a discard-pile draw reveals it', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..discard(c(Suit.diamonds, Rank.two))
        ..draw(DrawSource.discardPile);

      final draws = round.events.whereType<DrewCard>().toList();
      expect(draws[0].seat, 0);
      expect(draws[0].source, DrawSource.stock);
      expect(draws[0].card, isNull);
      expect(draws[1].seat, 1);
      expect(draws[1].source, DrawSource.discardPile);
      expect(draws[1].card, c(Suit.diamonds, Rank.two));
    });

    test('shows, discards and wins are recorded in order', () {
      final round = seat0HasShown()..declareWin(c(Suit.diamonds, Rank.two));

      expect(round.events.map((e) => e.runtimeType), [
        DrewCard,
        ShowedSets,
        WonRound,
      ]);
      final shown = round.events[1] as ShowedSets;
      expect(shown.kind, ShowKind.pureSets);
      expect(shown.sets, [runA, runB, runC]);
      expect((round.events[2] as WonRound).card, c(Suit.diamonds, Rank.two));
    });

    test('a discard records who discarded what', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..discard(c(Suit.diamonds, Rank.two));

      final discard = round.events.last as DiscardedCard;
      expect(discard.seat, 0);
      expect(discard.card, c(Suit.diamonds, Rank.two));
    });

    test('a reshuffled stock is recorded', () {
      final round = table(
        stockCards: [],
        discardPile: [c(Suit.clubs, Rank.ace), firstDiscard],
      )..draw(DrawSource.stock);

      expect(round.events.first, isA<StockReshuffled>());
    });

    test('refused moves record nothing', () {
      final round = table();

      expect(() => round.discard(firstDiscard), throwsStateError);
      expect(
        () => round.showPureSets([runA, runB, runD], tipluPosition: 0),
        throwsArgumentError,
      );
      expect(round.events, isEmpty);
    });

    test('the event list cannot be changed from outside', () {
      final round = table()..draw(DrawSource.stock);

      expect(() => round.events.clear(), throwsUnsupportedError);
    });
  });
}
