import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/data/avatar_look.dart';
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

const steady = BotPersonality(name: 'Test', tagline: 'For tests');

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
  group('Taking over a turn already under way', () {
    test('a bot finishes the turn without drawing again', () {
      final round = roundFor(run(Suit.clubs, [Rank.two, Rank.five, Rank.nine]))
        ..draw(DrawSource.stock);

      final turn = bot(BotDifficulty.medium).takeTurn(round);

      expect(turn.drewFrom, isNull);
      expect(turn.drawn, isNull);
      expect(turn.discarded, isNotNull);
      expect(round.currentSeat, 1);
      expect(round.hands[0].cards, hasLength(3));
    });

    test('and keeps the card the player took from the discard pile', () {
      final kept = c(Suit.spades, Rank.ace);
      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 10; seed++) {
          final round = roundFor(
            run(Suit.clubs, [Rank.two, Rank.five, Rank.nine]),
            topDiscard: kept,
          )..draw(DrawSource.discardPile);

          bot(difficulty, seed: seed).takeTurn(round);

          expect(round.hands[0].cards, contains(kept), reason: '$difficulty');
        }
      }
    });
  });

  final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
  final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
  final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);

  // After drawing Q♦, this hand can show 3 pure sets, pick 7♥ (the only
  // stock card left) as the tiplu, and win.
  /// Seat 0 holds three runs to show, then K♠ K♦ 7♣ 10♦ J♦ 8♥ 2♦; Q♦ is
  /// on top of the stock, 7♥ under it.
  Round showableRound() => roundFor(
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

  /// Seat 0 has drawn Q♦, shown, discarded 2♦ and picked 7♥ as the tiplu;
  /// seat 1 has drawn an ace and discarded it. Seat 0 holds K♠ K♦ 7♣ 10♦
  /// J♦ Q♦ 8♥ (a trial and a sequence, each with a joker), so whatever it
  /// draws next, it can win.
  Round winnableRound() =>
      roundFor(
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
          stock: [
            c(Suit.hearts, Rank.ace),
            c(Suit.hearts, Rank.ace),
            c(Suit.hearts, Rank.seven),
            c(Suit.diamonds, Rank.queen),
          ],
        )
        ..draw(DrawSource.stock)
        ..showPureSets([heartsRun, spadesRun, clubsRun])
        ..discard(c(Suit.diamonds, Rank.two))
        ..pickTiplu(0)
        ..draw(DrawSource.stock)
        ..discard(c(Suit.hearts, Rank.ace));

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
      test('${difficulty.name} shows, then picks the tiplu after its '
          'discard, and doesn\'t win that turn', () {
        final round = showableRound();

        final turn = bot(difficulty).takeTurn(round);

        expect(turn.shown, hasLength(3));
        expect(turn.won, isFalse);
        expect(turn.discarded, isNotNull);
        expect(turn.pickedTiplu, isTrue);
        expect(round.jokersFor(0)!.tiplu, c(Suit.hearts, Rank.seven));
        expect(round.isOver, isFalse);
        expect(round.currentSeat, 1);
      });

      test('${difficulty.name} wins on a later turn when it can', () {
        final round = winnableRound();

        final turn = bot(difficulty).takeTurn(round);

        expect(turn.won, isTrue);
        expect(turn.pickedTiplu, isFalse);
        expect(round.winner, 0);
      });
    }

    test('every bot shows a pure set the Superman completes', () {
      for (final difficulty in BotDifficulty.values) {
        final round = roundFor([
          ...run(Suit.spades, [Rank.two, Rank.three, Rank.four]),
          ...run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]),
          c(Suit.diamonds, Rank.five),
          const PlayingCard.superman(),
          c(Suit.diamonds, Rank.seven),
          c(Suit.hearts, Rank.king),
          c(Suit.clubs, Rank.four),
        ]);

        final turn = bot(difficulty).takeTurn(round);

        expect(turn.shown, hasLength(3), reason: '$difficulty');
        expect(
          turn.shown.expand((set) => set),
          contains(const PlayingCard.superman()),
          reason: '$difficulty',
        );
      }
    });

    test('a bot that picks a man card keeps it aside and picks again', () {
      for (final difficulty in BotDifficulty.values) {
        var keptAny = false;
        for (var seed = 0; seed < 10; seed++) {
          // Three of the five stock cards are man cards, so the bot often
          // picks one and has to pick again.
          final round = roundFor(
            showableRound().hands[0].cards,
            stock: [
              const PlayingCard.man(),
              c(Suit.hearts, Rank.seven),
              const PlayingCard.man(),
              const PlayingCard.man(),
              c(Suit.diamonds, Rank.queen),
            ],
          );

          bot(difficulty, seed: seed).takeTurn(round);

          final reason = '$difficulty, seed $seed';
          expect(round.needsTipluPick, isFalse, reason: reason);
          expect(round.jokersFor(0)!.tiplu.isMan, isFalse, reason: reason);
          final aside = round.hands[0].keptAside;
          expect(aside, everyElement(const PlayingCard.man()), reason: reason);
          keptAny |= aside.isNotEmpty;
        }
        expect(keptAny, isTrue, reason: '$difficulty never picked a man card');
      }
    });

    test('having shown, medium and hard keep a natural trial together '
        'before the joker is seen', () {
      for (final difficulty in [BotDifficulty.medium, BotDifficulty.hard]) {
        final queens = [
          c(Suit.clubs, Rank.queen),
          c(Suit.diamonds, Rank.queen),
          c(Suit.hearts, Rank.queen),
        ];
        final round = roundFor(
          [...heartsRun, ...spadesRun, ...clubsRun, ...queens],
          stock: [c(Suit.hearts, Rank.ten), c(Suit.hearts, Rank.jack)],
          // Nothing worth taking from the pile, so the bot draws J♥.
          topDiscard: c(Suit.diamonds, Rank.eight),
        );

        final turn = bot(difficulty).takeTurn(round);

        expect(turn.shown, hasLength(3), reason: '$difficulty');
        expect(
          turn.discarded,
          c(Suit.hearts, Rank.jack),
          reason: '$difficulty',
        );
        expect(
          round.hands[0].cards,
          containsAll(queens),
          reason: '$difficulty',
        );
      }
    });

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

    test('every bot keeps the Superman, even before seeing the joker', () {
      for (final difficulty in [BotDifficulty.medium, BotDifficulty.hard]) {
        expect(
          bot(difficulty).chooseDiscard([
            ...heartsRun,
            const PlayingCard.superman(),
            loner,
          ], null),
          loner,
          reason: '$difficulty',
        );
      }
    });

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

  group('Easy', () {
    test(
      'throws away a joker more often than not, valuing it as a plain card',
      () {
        // K♥ is the tiplu, so K♣ is wild. As a plain card it is as useless as
        // 4♦, and higher, so a bot blind to jokers throws it first.
        final jokers = Jokers(c(Suit.hearts, Rank.king));
        final wild = c(Suit.clubs, Rank.king);
        final loner = c(Suit.diamonds, Rank.four);
        final discards = [
          for (var seed = 0; seed < 60; seed++)
            bot(
              BotDifficulty.easy,
              seed: seed,
            ).chooseDiscard([...heartsRun, wild, loner], jokers),
        ];

        expect(discards.where((card) => card == wild).length, greaterThan(30));
        expect(
          bot(
            BotDifficulty.medium,
          ).chooseDiscard([...heartsRun, wild, loner], jokers),
          loner,
        );
      },
    );

    test('sometimes breaks up a set it was building', () {
      final loner = c(Suit.diamonds, Rank.king);
      final discards = [
        for (var seed = 0; seed < 60; seed++)
          bot(
            BotDifficulty.easy,
            seed: seed,
          ).chooseDiscard([...heartsRun, ...spadesRun, loner], null),
      ];

      expect(discards, contains(loner));
      expect(discards.where((card) => card != loner), isNotEmpty);
    });

    test('sometimes takes a useless discard without thinking', () {
      // K♦ goes with nothing in the hand.
      List<PlayingCard> hand() =>
          run(Suit.clubs, [Rank.two, Rank.five, Rank.nine]);
      final sources = [
        for (var seed = 0; seed < 60; seed++)
          bot(BotDifficulty.easy, seed: seed)
              .takeTurn(
                roundFor(hand(), topDiscard: c(Suit.diamonds, Rank.king)),
              )
              .drewFrom,
      ];

      expect(sources, contains(DrawSource.discardPile));
      expect(sources, contains(DrawSource.stock));
      expect(
        bot(BotDifficulty.medium)
            .takeTurn(roundFor(hand(), topDiscard: c(Suit.diamonds, Rank.king)))
            .drewFrom,
        DrawSource.stock,
      );
    });

    test('only ever makes legal moves, playing whole rounds to the end', () {
      for (var game = 0; game < 20; game++) {
        final random = Random(game);
        final bots = [
          for (var seat = 0; seat < 4; seat++)
            BotPlayer(
              difficulty: BotDifficulty.easy,
              personality: steady,
              random: random,
            ),
        ];
        final round = Round.deal(
          config: GameConfig(playerCount: 4),
          random: random,
        );
        for (var seat = 0; seat < 4; seat++) {
          round.showOpeningTunnellas(
            seat,
            bots[seat].openingTunnellas(round.hands[seat].cards),
          );
        }
        // The round itself throws on any illegal move.
        for (var turn = 0; turn < 2000 && !round.isOver; turn++) {
          bots[round.currentSeat].takeTurn(round);
        }
        expect(round.isOver, isTrue, reason: 'game $game never ended');
      }
    });
  });

  group('Medium', () {
    test('keeps a finished pure sequence over cards that only look close', () {
      // 9♣ 9♣ 10♣ each sit next to two partners, so card by card they look
      // more useful than the ends of 3♥ 4♥ 5♥; but only the hearts are a set.
      final nines = [
        c(Suit.clubs, Rank.nine),
        c(Suit.clubs, Rank.nine),
        c(Suit.clubs, Rank.ten),
      ];

      final discard = bot(
        BotDifficulty.medium,
      ).chooseDiscard([...heartsRun, ...nines], null);

      expect(heartsRun, isNot(contains(discard)));
    });

    test('throws its highest deadwood first', () {
      final deadwood = [c(Suit.diamonds, Rank.four), c(Suit.spades, Rank.king)];

      expect(
        bot(
          BotDifficulty.medium,
        ).chooseDiscard([...heartsRun, ...deadwood], null),
        c(Suit.spades, Rank.king),
      );
    });

    test('keeps a joker over a high card it has no use for', () {
      final jokers = Jokers(c(Suit.hearts, Rank.seven));
      final wild = c(Suit.clubs, Rank.seven);

      for (var seed = 0; seed < 20; seed++) {
        expect(
          bot(BotDifficulty.medium, seed: seed).chooseDiscard([
            ...heartsRun,
            wild,
            c(Suit.spades, Rank.ace),
          ], jokers),
          c(Suit.spades, Rank.ace),
        );
      }
    });

    test('never misses a win', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(
          bot(BotDifficulty.medium, seed: seed).takeTurn(winnableRound()).won,
          isTrue,
        );
      }
    });
  });

  group('Hard: the dublee route', () {
    List<PlayingCard> pairsOf(Suit suit, List<Rank> ranks) => [
      for (final rank in ranks) ...[c(suit, rank), c(suit, rank)],
    ];
    // Four doublees and nothing close to a pure set.
    final pairs = pairsOf(Suit.clubs, [
      Rank.two,
      Rank.five,
      Rank.eight,
      Rank.jack,
    ]);
    final singles = [
      c(Suit.hearts, Rank.ace),
      c(Suit.diamonds, Rank.six),
      c(Suit.spades, Rank.ten),
    ];

    PlayerHand handOf(List<PlayingCard> cards) => roundFor(cards).hands[0];

    test('a hand rich in pairs and far from pure sets plays for doublees', () {
      expect(
        bot(
          BotDifficulty.hard,
        ).playsForDoublees(handOf([...pairs, ...singles])),
        isTrue,
      );
    });

    test('a hand close to its pure sets does not', () {
      expect(
        bot(
          BotDifficulty.hard,
        ).playsForDoublees(handOf([...pairs, ...heartsRun, ...spadesRun])),
        isFalse,
      );
    });

    test('Medium never chooses the route', () {
      expect(
        bot(
          BotDifficulty.medium,
        ).playsForDoublees(handOf([...pairs, ...singles])),
        isFalse,
      );
    });

    test('keeps its pairs and throws a single', () {
      final discard = bot(
        BotDifficulty.hard,
      ).chooseDiscard([...pairs, ...singles], null, keepPairs: true);

      expect(singles, contains(discard));
    });

    test('takes a discard that makes a pair, and only that', () {
      final pairing = bot(BotDifficulty.hard).takeTurn(
        roundFor([...pairs, ...singles], topDiscard: c(Suit.spades, Rank.ten)),
      );
      expect(pairing.drewFrom, DrawSource.discardPile);

      // 7♦ sits next to 6♦, which would tempt a bot building runs.
      final near = bot(BotDifficulty.hard).takeTurn(
        roundFor([
          ...pairs,
          ...singles,
        ], topDiscard: c(Suit.diamonds, Rank.seven)),
      );
      expect(near.drewFrom, DrawSource.stock);
    });

    test('shows 7 doublees once it has them', () {
      final turn = bot(BotDifficulty.hard).takeTurn(
        roundFor([
          ...pairs,
          ...pairsOf(Suit.hearts, [Rank.four, Rank.nine, Rank.king]),
          c(Suit.spades, Rank.ten),
        ]),
      );

      expect(turn.shown, hasLength(PlayerHand.doubleesToShow));
      expect(turn.shown, everyElement(hasLength(2)));
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
    test('the cast is fifteen Nepali names, all different', () {
      final names = BotPersonality.all.map((p) => p.name).toList();

      expect(names, hasLength(15));
      expect(names.toSet(), hasLength(names.length));
      expect(names, containsAll(['Bishal', 'Priya', 'Kiran', 'Sabina']));
    });

    test('none borrows a name from another game', () {
      final names = BotPersonality.all.map((p) => p.name.toLowerCase());

      for (final taken in [
        'shikshak',
        'nauty nurse',
        'tarikpetarik',
        'chitralekha',
      ]) {
        expect(names, isNot(contains(taken)));
      }
    });

    test('every level has five bots, enough for a full table', () {
      for (final difficulty in BotDifficulty.values) {
        final bots = BotPersonality.at(difficulty);

        expect(bots, hasLength(5), reason: difficulty.name);
        expect(bots.every((b) => b.difficulty == difficulty), isTrue);
      }
    });

    test('every bot has its own avatar look', () {
      final looks = BotPersonality.all.map((p) => p.look).toList();

      expect(looks.toSet(), hasLength(looks.length));
      expect(
        looks.every((l) => l >= 0 && l < AvatarLook.presets.length),
        isTrue,
      );
    });

    test('picking gives different bots, all of the table\'s level', () {
      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 20; seed++) {
          final picked = BotPersonality.pick(4, Random(seed), difficulty);

          expect(picked.map((p) => p.name).toSet(), hasLength(4));
          expect(picked.every((p) => p.difficulty == difficulty), isTrue);
        }
      }
    });

    test('picking is random: different seeds seat different bots', () {
      final tables = {
        for (var seed = 0; seed < 20; seed++)
          BotPersonality.pick(
            4,
            Random(seed),
            BotDifficulty.easy,
          ).map((p) => p.name).join(','),
      };

      expect(tables.length, greaterThan(1));
    });

    test('a bot already seated is never picked again', () {
      final picked = BotPersonality.pick(
        1,
        Random(0),
        BotDifficulty.medium,
        seated: ['Kiran', 'Sunita', 'Anjali', 'Suman'],
      );

      expect(picked.single.name, 'Dipak');
    });

    test('cannot pick more bots than a level has free', () {
      expect(
        () => BotPersonality.pick(6, Random(0), BotDifficulty.hard),
        throwsArgumentError,
      );
      expect(
        () => BotPersonality.pick(
          2,
          Random(0),
          BotDifficulty.hard,
          seated: ['Priya', 'Sabina', 'Arjun', 'Nabin'],
        ),
        throwsArgumentError,
      );
    });

    test('a bot is found by name, for picking a saved match up again', () {
      expect(BotPersonality.named('Sarita')?.difficulty, BotDifficulty.hard);
      expect(BotPersonality.named('Nobody'), isNull);
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
