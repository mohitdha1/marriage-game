import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/round_log.dart';
import 'package:marriage_game/engine/table_event.dart';

import 'round_test.dart'
    show c, firstDiscard, runA, runB, runC, seat0Cards, stock, table;

/// Everything about [round] that a player could act on, written out so two
/// rounds can be compared.
String describe(Round round) => [
  for (final (seat, hand) in round.hands.indexed)
    'seat $seat: ${hand.cards} opened ${hand.openingTunnellas} '
        'shown ${hand.shownSets} aside ${hand.keptAside} '
        '${hand.hasOpened} ${hand.hasDrawn} ${hand.showKind} '
        'seen ${hand.hasSeenJoker} shown now ${hand.shownThisTurn} '
        'jokers ${round.jokersFor(seat)?.tiplu}',
  'stock ${round.stockCount}, discards ${round.discardPileCount} '
      'top ${round.topDiscard}',
  'turn ${round.currentSeat}, pick again ${round.needsTipluPick}, '
      'kept ${round.takenFromDiscardPile}, winner ${round.winner}',
  'joker discards ${round.jokerDiscards}',
  'events ${[for (final e in round.events) '${e.runtimeType}:${e.seat}']}',
].join('\n');

Round replayOf(Round round, {Random? random}) => Round.replay(
  config: round.config,
  random: random ?? Random(99),
  start: round.start,
  log: round.log,
);

/// Bots play [round] on, one turn at a time, until it's over or [turns]
/// turns have been played.
void playOn(Round round, Random random, {int turns = 1000}) {
  final bots = [
    for (final personality in BotPersonality.all.take(round.hands.length))
      BotPlayer(
        difficulty: BotDifficulty.hard,
        personality: personality,
        random: random,
      ),
  ];
  for (var turn = 0; turn < turns && !round.isOver; turn++) {
    bots[round.currentSeat].takeTurn(round);
  }
}

/// A round dealt from [seed], every seat opened by a bot.
Round dealt(int seed, {GameConfig? config}) {
  final round = Round.deal(
    config: config ?? GameConfig(playerCount: 4),
    random: Random(seed),
  );
  final bot = BotPlayer(
    difficulty: BotDifficulty.hard,
    personality: BotPersonality.all.first,
    random: Random(seed),
  );
  for (var seat = 0; seat < round.hands.length; seat++) {
    round.showOpeningTunnellas(
      seat,
      bot.openingTunnellas(round.hands[seat].cards),
    );
  }
  return round;
}

void main() {
  group('Round.start', () {
    test('is the cards the round was dealt from', () {
      final round = table(open: false);

      expect(round.start.hands, [seat0Cards, round.hands[1].cards]);
      expect(round.start.stock, stock);
      expect(round.start.discardPile, [firstDiscard]);
      expect(round.start.firstSeat, 0);
    });

    test('doesn\'t change as the round is played', () {
      final round = table()..draw(DrawSource.stock);

      expect(round.start.hands.first, seat0Cards);
      expect(round.start.stock, stock);
    });
  });

  group('Round.log', () {
    test('a fresh round has nothing in it', () {
      expect(table(open: false).log, isEmpty);
    });

    test('records each move with what it needs to be made again', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..showPureSets([runA, runB, runC])
        ..discard(c(Suit.diamonds, Rank.ten))
        ..pickTiplu(1)
        ..draw(DrawSource.discardPile);

      expect(round.log, [
        isA<OpeningMove>()
            .having((m) => m.seat, 'seat', 0)
            .having((m) => m.tunnellas, 'tunnellas', isEmpty),
        isA<OpeningMove>().having((m) => m.seat, 'seat', 1),
        isA<DrawMove>().having((m) => m.source, 'source', DrawSource.stock),
        isA<ShowMove>()
            .having((m) => m.kind, 'kind', ShowKind.pureSets)
            .having((m) => m.sets, 'sets', [runA, runB, runC])
            .having((m) => m.tipluPosition, 'tipluPosition', isNull),
        isA<DiscardMove>().having(
          (m) => m.card,
          'card',
          c(Suit.diamonds, Rank.ten),
        ),
        isA<PickTipluMove>().having((m) => m.position, 'position', 1),
        isA<DrawMove>().having(
          (m) => m.source,
          'source',
          DrawSource.discardPile,
        ),
      ]);
    });

    test('a move the engine refuses isn\'t recorded', () {
      final round = table();

      expect(() => round.discard(c(Suit.diamonds, Rank.two)), throwsStateError);
      expect(
        () => round.showPureSets([runA, runB, runC], tipluPosition: 99),
        throwsArgumentError,
      );

      expect(round.log, hasLength(2));
    });

    test('records the order a reshuffled stock came out in', () {
      final a = c(Suit.clubs, Rank.ace);
      final b = c(Suit.spades, Rank.nine);
      final top = c(Suit.spades, Rank.eight);
      final round = table(stockCards: [], discardPile: [a, b, top])
        ..draw(DrawSource.stock);

      final shuffle = round.log.whereType<StockShuffle>().single;
      expect(shuffle.stock, unorderedEquals([a, b]));
      expect(round.log.last, isA<DrawMove>());
    });

    test('records a second pick of the tiplu after a printed joker', () {
      const man = PlayingCard.man();
      final round =
          table(
              config: GameConfig(playerCount: 2, manCardsEnabled: true),
              stockCards: [
                c(Suit.clubs, Rank.five),
                man,
                c(Suit.clubs, Rank.two),
                c(Suit.diamonds, Rank.queen),
              ],
            )
            ..draw(DrawSource.stock)
            ..showPureSets([runA, runB, runC])
            ..discard(c(Suit.diamonds, Rank.two))
            ..pickTiplu(1)
            ..pickTiplu(0);

      expect(
        round.log.last,
        isA<PickTipluMove>().having((m) => m.position, 'position', 0),
      );
    });
  });

  group('Round.replay', () {
    test('brings a round back to where it was, mid-turn', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..showPureSets([runA, runB, runC]);

      expect(describe(replayOf(round)), describe(round));
    });

    test('brings back a pick owed after the discard, which then passes the '
        'turn', () {
      final round = table()
        ..draw(DrawSource.stock)
        ..showPureSets([runA, runB, runC])
        ..discard(c(Suit.diamonds, Rank.two));

      final replayed = replayOf(round);
      expect(replayed.needsTipluPick, isTrue);
      expect(describe(replayed), describe(round));

      replayed.pickTiplu(1);
      expect(replayed.currentSeat, 1);
    });

    test('brings back a tiplu picked again after a printed joker', () {
      const man = PlayingCard.man();
      final round =
          table(
              config: GameConfig(playerCount: 2, manCardsEnabled: true),
              stockCards: [
                c(Suit.clubs, Rank.five),
                man,
                man,
                c(Suit.clubs, Rank.two),
                c(Suit.diamonds, Rank.queen),
              ],
            )
            ..draw(DrawSource.stock)
            ..showPureSets([runA, runB, runC])
            ..discard(c(Suit.diamonds, Rank.two))
            ..pickTiplu(1);

      final replayed = replayOf(round);

      expect(replayed.needsTipluPick, isTrue);
      expect(describe(replayed), describe(round));
    });

    test('reshuffles the stock as it was reshuffled, whatever the random '
        'source', () {
      final round = table(
        stockCards: [],
        discardPile: [
          c(Suit.clubs, Rank.ace),
          c(Suit.spades, Rank.nine),
          c(Suit.hearts, Rank.queen),
          c(Suit.spades, Rank.eight),
        ],
      );
      final drawn = round.draw(DrawSource.stock);

      final replayed = replayOf(round, random: Random(12345));

      expect(replayed.hands[0].cards.last, drawn);
      expect(describe(replayed), describe(round));
    });

    test('brings back a finished round', () {
      final round = dealt(3);
      playOn(round, Random(3));

      final replayed = replayOf(round);

      expect(replayed.isOver, isTrue);
      expect(replayed.score().net, round.score().net);
      expect(describe(replayed), describe(round));
    });

    test('a replayed round plays on exactly as the original would', () {
      for (final seed in [1, 2, 5, 8]) {
        final config = GameConfig(
          playerCount: 5,
          manCardsEnabled: seed.isEven,
          supermanCardEnabled: seed > 4,
        );
        final round = dealt(seed, config: config);
        playOn(round, Random(seed), turns: 30);
        final replayed = replayOf(round);
        expect(describe(replayed), describe(round), reason: 'seed $seed');

        playOn(round, Random(seed + 100));
        playOn(replayed, Random(seed + 100));

        expect(describe(replayed), describe(round), reason: 'seed $seed');
        expect(replayed.log.length, round.log.length);
      }
    });

    test('a log that doesn\'t fit the cards is refused', () {
      final round = table()..draw(DrawSource.stock);

      expect(
        () => Round.replay(
          config: round.config,
          random: Random(0),
          start: round.start,
          log: [...round.log, const DiscardMove(PlayingCard.superman())],
        ),
        throwsArgumentError,
      );
    });

    test('a replayed round keeps logging', () {
      final round = table();
      final replayed = replayOf(round)..draw(DrawSource.stock);

      expect(replayed.log, hasLength(3));
      expect(replayed.events.last, isA<DrewCard>());
    });
  });
}
