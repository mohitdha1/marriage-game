import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/bots/table_memory.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

const steady = BotPersonality(
  name: 'Test',
  tagline: 'For tests',
  avatarColor: 0xFFFFFFFF,
);

BotPlayer bot(
  BotDifficulty difficulty, {
  BotPersonality personality = steady,
  int seed = 0,
}) => BotPlayer(
  difficulty: difficulty,
  personality: personality,
  random: Random(seed),
);

/// A 2-player round where seat 0 (the bot under test) plays first.
Round roundFor(
  List<PlayingCard> botHand, {
  List<PlayingCard>? stock,
  PlayingCard? topDiscard,
  List<PlayingCard>? otherHand,
}) =>
    Round.fromCards(
        config: GameConfig(playerCount: 2),
        random: Random(0),
        hands: [
          botHand,
          otherHand ?? run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
        ],
        stock: stock ?? [for (var i = 0; i < 5; i++) c(Suit.hearts, Rank.ace)],
        discardPile: [topDiscard ?? c(Suit.clubs, Rank.king)],
      )
      ..showOpeningTunnellas(0, [])
      ..showOpeningTunnellas(1, []);

void main() {
  final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
  final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
  final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);

  // After drawing Q♦, this hand can show 3 pure sets, pick 7♥ (the only
  // stock card left) as the tiplu, and win.
  Round winnableRound() => roundFor(
    [
      ...heartsRun,
      ...spadesRun,
      ...clubsRun,
      c(Suit.spades, Rank.king),
      c(Suit.diamonds, Rank.king),
      c(Suit.clubs, Rank.seven),
      c(Suit.diamonds, Rank.ten),
      c(Suit.diamonds, Rank.jack),
      c(Suit.hearts, Rank.eight),
      c(Suit.diamonds, Rank.two),
    ],
    stock: [c(Suit.hearts, Rank.seven), c(Suit.diamonds, Rank.queen)],
  );

  group('Opening', () {
    test('shows every tunnella, up to 3', () {
      final four = [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          for (var i = 0; i < 3; i++) c(Suit.clubs, rank),
      ];

      expect(bot(BotDifficulty.medium).openingTunnellas(four), hasLength(3));
      expect(bot(BotDifficulty.medium).openingTunnellas(heartsRun), isEmpty);
    });
  });

  group('Showing and winning', () {
    for (final difficulty in [BotDifficulty.medium, BotDifficulty.hard]) {
      test(
        '${difficulty.name} shows, picks the tiplu and wins when it can',
        () {
          final round = winnableRound();

          final turn = bot(difficulty).takeTurn(round);

          expect(turn.shown, hasLength(3));
          expect(turn.pickedTiplu, isTrue);
          expect(round.jokersFor(0)!.tiplu, c(Suit.hearts, Rank.seven));
          expect(turn.won, isTrue);
          expect(round.winner, 0);
        },
      );
    }

    test('easy sometimes misses a win it could have taken', () {
      final outcomes = [
        for (var seed = 0; seed < 40; seed++)
          bot(BotDifficulty.easy, seed: seed).takeTurn(winnableRound()).won,
      ];

      expect(outcomes, contains(true));
      expect(outcomes, contains(false));
    });

    test('medium shows 7 doublees when it has no pure sets; easy does not', () {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.four,
          Rank.six,
          Rank.eight,
          Rank.ten,
          Rank.queen,
          Rank.ace,
        ])
          c(Suit.clubs, rank),
      ];
      List<PlayingCard> hand() => [
        ...pairs,
        ...pairs,
        c(Suit.hearts, Rank.nine),
      ];

      final medium = bot(BotDifficulty.medium).takeTurn(roundFor(hand()));
      expect(medium.shown, hasLength(PlayerHand.doubleesToShow));

      final easy = bot(BotDifficulty.easy).takeTurn(roundFor(hand()));
      expect(easy.shown, isEmpty);
    });

    test('hard shows the sets that leave its hand most flexible', () {
      // Clubs 3-4-5-6 hold two runs; showing 4-5-6 keeps 3♣ next to A♣,
      // while showing 3-4-5 strands 6♣.
      final clubs = run(Suit.clubs, [
        Rank.ace,
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]);
      List<PlayingCard> hand() => [
        ...heartsRun,
        ...spadesRun,
        ...clubs,
        c(Suit.diamonds, Rank.queen),
      ];
      final fourFiveSix = run(Suit.clubs, [Rank.four, Rank.five, Rank.six]);

      final hard = bot(BotDifficulty.hard).takeTurn(roundFor(hand()));
      expect(hard.shown, contains(equals(fourFiveSix)));

      final medium = bot(BotDifficulty.medium).takeTurn(roundFor(hand()));
      expect(medium.shown, isNot(contains(equals(fourFiveSix))));
    });
  });

  group('Discarding', () {
    final jokers = Jokers(c(Suit.hearts, Rank.seven));
    final wild = c(Suit.clubs, Rank.seven);
    final loner = c(Suit.diamonds, Rank.king);

    test('medium throws away the least useful card and keeps jokers', () {
      expect(
        bot(
          BotDifficulty.medium,
        ).chooseDiscard([...heartsRun, wild, loner], jokers),
        loner,
      );
    });

    test('easy is sloppy: over many games it throws away a joker', () {
      final discards = [
        for (var seed = 0; seed < 60; seed++)
          bot(
            BotDifficulty.easy,
            seed: seed,
          ).chooseDiscard([...heartsRun, wild, loner], jokers),
      ];

      expect(discards, contains(wild));
    });

    test('never discards a card it must keep', () {
      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 20; seed++) {
          expect(
            bot(
              difficulty,
              seed: seed,
            ).chooseDiscard([...heartsRun, loner], null, mustKeep: loner),
            isNot(loner),
          );
        }
      }
    });

    test('hard avoids feeding the next player', () {
      // The next player took J♥ from the discard pile, so Q♥ would help
      // them. Q♥ and 4♣ are equally useless to the bot itself.
      final queenOfHearts = c(Suit.hearts, Rank.queen);
      final fourOfClubs = c(Suit.clubs, Rank.four);
      final memory = memoryWhereNextTook(c(Suit.hearts, Rank.jack));
      final cards = [queenOfHearts, fourOfClubs, ...spadesRun];

      // Medium breaks the tie by rank and throws Q♥.
      expect(
        bot(BotDifficulty.medium).chooseDiscard(cards, null),
        queenOfHearts,
      );
      // Hard remembers what the next player took and throws 4♣ instead.
      expect(
        bot(BotDifficulty.hard).chooseDiscard(cards, null, memory: memory),
        fourOfClubs,
      );
    });
  });

  group('Drawing', () {
    // 7♣ is two ranks from 5♣: usefulness 1.
    List<PlayingCard> hand() => [
      c(Suit.clubs, Rank.five),
      c(Suit.hearts, Rank.king),
      c(Suit.spades, Rank.nine),
    ];
    final sevenOfClubs = c(Suit.clubs, Rank.seven);

    test('a keen personality takes a discard a steady one would not', () {
      final keen = BotPersonality.all.firstWhere((p) => p.name == 'Bishal');

      final keenTurn = bot(
        BotDifficulty.medium,
        personality: keen,
      ).takeTurn(roundFor(hand(), topDiscard: sevenOfClubs));
      final steadyTurn = bot(
        BotDifficulty.medium,
      ).takeTurn(roundFor(hand(), topDiscard: sevenOfClubs));

      expect(keenTurn.drewFrom, DrawSource.discardPile);
      expect(keenTurn.drawn, sevenOfClubs);
      expect(steadyTurn.drewFrom, DrawSource.stock);
    });

    test('a useful discard is taken', () {
      final turn = bot(
        BotDifficulty.medium,
      ).takeTurn(roundFor(hand(), topDiscard: c(Suit.clubs, Rank.six)));

      expect(turn.drewFrom, DrawSource.discardPile);
    });
  });

  group('Strength', () {
    /// Wins for [a] and [b] over [games] 2-player rounds, swapping seats
    /// every round so going first evens out.
    (int, int) playOff(BotDifficulty a, BotDifficulty b, int games) {
      var winsA = 0;
      var winsB = 0;
      for (var game = 0; game < games; game++) {
        final random = Random(game);
        final seatA = game % 2;
        final bots = [
          for (var seat = 0; seat < 2; seat++)
            BotPlayer(
              difficulty: seat == seatA ? a : b,
              personality: steady,
              random: random,
            ),
        ];
        final round = Round.deal(
          config: GameConfig(playerCount: 2),
          random: random,
        );
        for (var seat = 0; seat < 2; seat++) {
          round.showOpeningTunnellas(
            seat,
            bots[seat].openingTunnellas(round.hands[seat].cards),
          );
        }
        for (var turn = 0; turn < 500 && !round.isOver; turn++) {
          bots[round.currentSeat].takeTurn(round);
        }
        if (round.winner == seatA) winsA++;
        if (round.winner == 1 - seatA) winsB++;
      }
      return (winsA, winsB);
    }

    test('medium clearly beats easy', () {
      final (medium, easy) = playOff(
        BotDifficulty.medium,
        BotDifficulty.easy,
        30,
      );

      expect(medium, greaterThan(easy * 2));
    });

    test('hard clearly beats easy', () {
      final (hard, easy) = playOff(BotDifficulty.hard, BotDifficulty.easy, 30);

      expect(hard, greaterThan(easy * 2));
    });
  });

  group('BotPersonality', () {
    test('the cast mixes Nepali, Hindi and English names, all different', () {
      final names = BotPersonality.all.map((p) => p.name).toList();

      expect(names.toSet(), hasLength(names.length));
      expect(names, containsAll(['Bishal', 'Priya', 'Jack']));
    });

    test('picking gives different personalities', () {
      final picked = BotPersonality.pick(4, Random(3));

      expect(picked.map((p) => p.name).toSet(), hasLength(4));
    });

    test('cannot pick more personalities than there are', () {
      expect(
        () => BotPersonality.pick(BotPersonality.all.length + 1, Random(0)),
        throwsArgumentError,
      );
    });
  });
}

/// Seat 0's memory of a round where it discarded [card] and seat 1 (the
/// next player) took it from the discard pile.
TableMemory memoryWhereNextTook(PlayingCard card) {
  final round =
      roundFor([
          card,
          c(Suit.diamonds, Rank.nine),
        ], otherHand: run(Suit.diamonds, [Rank.two, Rank.three, Rank.four]))
        ..draw(DrawSource.stock)
        ..discard(card)
        ..draw(DrawSource.discardPile)
        ..discard(c(Suit.diamonds, Rank.two));
  return TableMemory.read(round, 0);
}
