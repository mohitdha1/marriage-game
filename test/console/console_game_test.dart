import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/console/console_game.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

/// A console game fed from [input] line by line, collecting its output.
class ScriptedGame {
  ScriptedGame({
    List<String> input = const [],
    GameConfig? config,
    int? humanSeat = 0,
    int maxTurns = 500,
    RoundDealer? dealRound,
    int seed = 0,
  }) : _input = [...input] {
    game = ConsoleGame(
      config: config ?? GameConfig(playerCount: 2),
      random: Random(seed),
      readLine: () => _input.isEmpty ? null : _input.removeAt(0),
      writeLine: output.add,
      humanSeat: humanSeat,
      maxTurns: maxTurns,
      dealRound: dealRound,
    );
  }

  final List<String> _input;
  final output = <String>[];
  late final ConsoleGame game;

  String get text => output.join('\n');
}

/// The numbers the console would show for [cards] in [hand], which it lists
/// sorted by suit then rank. Duplicate cards get separate numbers.
String numbersOf(List<PlayingCard> hand, List<PlayingCard> cards) {
  final sorted = sortForDisplay(hand);
  final used = <int>{};
  final numbers = <int>[];
  for (final card in cards) {
    var i = 0;
    while (sorted[i] != card || used.contains(i)) {
      i++;
    }
    used.add(i);
    numbers.add(i + 1);
  }
  return numbers.join(' ');
}

void main() {
  // The human player (seat 0) holds 3 pure runs plus K♠ K♦ 7♣ 10♦ J♦ 8♥ 2♦.
  // Drawing Q♦ and picking 7♥ as the tiplu lets them show and then win by
  // discarding 2♦.
  final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
  final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
  final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
  final extras = [
    c(Suit.spades, Rank.king),
    c(Suit.diamonds, Rank.king),
    c(Suit.clubs, Rank.seven),
    c(Suit.diamonds, Rank.ten),
    c(Suit.diamonds, Rank.jack),
    c(Suit.hearts, Rank.eight),
    c(Suit.diamonds, Rank.two),
  ];
  final yourCards = [...heartsRun, ...spadesRun, ...clubsRun, ...extras];
  final queen = c(Suit.diamonds, Rank.queen);
  final two = c(Suit.diamonds, Rank.two);

  Round knownDeal(int firstSeat) => Round.fromCards(
    config: GameConfig(playerCount: 2),
    random: Random(0),
    hands: [
      yourCards,
      run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
    ],
    // From the top: Q♦, 2♣, 7♥, 5♣.
    stock: [
      c(Suit.clubs, Rank.five),
      c(Suit.hearts, Rank.seven),
      c(Suit.clubs, Rank.two),
      queen,
    ],
    discardPile: [c(Suit.clubs, Rank.king)],
    firstSeat: firstSeat,
  );

  group('You vs a bot', () {
    test('draw, show, pick the tiplu and win in one turn', () {
      final afterDraw = [...yourCards, queen];
      final afterShow = [...extras, queen];
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: [
          'draw',
          'show ${numbersOf(afterDraw, heartsRun)}, '
              '${numbersOf(afterDraw, spadesRun)}, '
              '${numbersOf(afterDraw, clubsRun)}',
          '2', // the tiplu: 7♥ is second from the top after Q♦ is drawn
          'win ${numbersOf(afterShow, [two])}',
          'n',
        ],
      );

      game.game.playMatch();

      expect(game.text, contains('You play first'));
      expect(game.text, contains('You drew Q♦.'));
      expect(game.text, contains('you pick the tiplu'));
      expect(game.text, contains('saw the joker'));
      expect(game.text, contains('Joker: tiplu 7♥, jhiplu 6♥, poplu 8♥'));
      expect(game.text, contains('You discard 2♦ and WIN the round!'));
      expect(game.text, contains('You won the round. The tiplu was 7♥.'));
      expect(game.text, contains('Match totals after 1 round'));
      expect(game.game.match.rounds.single.winner, 0);
    });

    test('engine errors are reported and the turn carries on', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: ['discard 1', 'win 1', 'draw', 'quit'],
      );

      game.game.playMatch();

      expect(game.text, contains('Not allowed: Must draw before discarding'));
      expect(
        game.text,
        contains('Not allowed: Must see the joker before winning'),
      );
      expect(game.text, contains('You drew Q♦.'));
      expect(game.text, contains('Game stopped.'));
    });

    test('an invalid show is rejected with the engine\'s reason', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: ['draw', 'show 1 2 3, 4 5 6', '2', 'quit'],
      );

      game.game.playMatch();

      expect(game.text, contains('Not allowed: must show exactly 3'));
      expect(game.text, isNot(contains('saw the joker')));
    });

    test('typos in card numbers are explained', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: ['draw', 'discard 99', 'discard x', 'show 1 1 2', 'quit'],
      );

      game.game.playMatch();

      expect(game.text, contains('There is no card 99 in your hand.'));
      expect(game.text, contains('Give one card number'));
      expect(game.text, contains('Card 1 is used more than once.'));
    });

    test('a card taken from the discard pile must be kept that turn', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: [
          'take',
          'discard ${numbersOf([...yourCards, c(Suit.clubs, Rank.king)], [c(Suit.clubs, Rank.king)])}',
          'quit',
        ],
      );

      game.game.playMatch();

      expect(game.text, contains('You took K♣ from the discard pile.'));
      expect(
        game.text,
        contains('Not allowed: K♣ was just taken from the discard pile'),
      );
    });

    test('unknown commands and help', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: ['dance', 'help', 'quit'],
      );

      game.game.playMatch();

      expect(game.text, contains('Unknown command "dance"'));
      expect(game.text, contains('draw | d'));
    });

    test('the bot takes its turn after yours', () {
      final game = ScriptedGame(
        dealRound: knownDeal,
        input: [
          'draw',
          'discard ${numbersOf([...yourCards, queen], [two])}',
        ],
      );

      game.game.playMatch();

      expect(game.text, contains('You discarded 2♦.'));
      expect(game.text, contains('Bot 2 draws from the stock'));
    });

    test('running out of input stops the game cleanly', () {
      final game = ScriptedGame(dealRound: knownDeal);

      game.game.playMatch();

      expect(game.text, contains('Game stopped.'));
    });

    test('with more than 3 dealt tunnellas, you pick which 3 to show', () {
      final tunnellas = [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          for (var i = 0; i < 3; i++) c(Suit.clubs, rank),
      ];
      final game = ScriptedGame(
        dealRound: (firstSeat) => Round.fromCards(
          config: GameConfig(playerCount: 2),
          random: Random(0),
          hands: [
            tunnellas,
            run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
          ],
          stock: [c(Suit.hearts, Rank.seven), queen],
          discardPile: [c(Suit.hearts, Rank.king)],
        ),
        input: ['1 1 2', '1 2 4', 'quit'],
      );

      game.game.playMatch();

      expect(game.text, contains('You were dealt 4 tunnellas'));
      expect(game.text, contains('Please pick 3 different numbers'));
      expect(game.text, contains('You opened with [2♣ 2♣ 2♣]'));
    });
  });

  group('Bots only', () {
    test('full games play to the end for many shuffles', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = ScriptedGame(
          config: GameConfig(),
          humanSeat: null,
          seed: seed,
        );

        game.game.playMatch(rounds: 2);

        final finished = RegExp(
          r'won the round|No winner after',
        ).allMatches(game.text).length;
        expect(finished, 2, reason: 'seed $seed');
      }
    });

    test('every finished round settles to zero', () {
      final game = ScriptedGame(config: GameConfig(), humanSeat: null, seed: 7);

      game.game.playMatch(rounds: 5);

      expect(game.game.match.totals.fold(0, (sum, n) => sum + n), 0);
    });

    test('a round with no winner by the turn limit scores nothing', () {
      final game = ScriptedGame(
        config: GameConfig(),
        humanSeat: null,
        maxTurns: 2,
      );

      game.game.playMatch();

      expect(game.text, contains('No winner after 2 turns'));
      expect(game.game.match.rounds, isEmpty);
    });

    test('who plays first rotates each round', () {
      final game = ScriptedGame(
        config: GameConfig(playerCount: 3),
        humanSeat: null,
        maxTurns: 1,
      );

      game.game.playMatch(rounds: 3);

      expect(game.text, contains('Bot 1 plays first'));
      expect(game.text, contains('Bot 2 plays first'));
      expect(game.text, contains('Bot 3 plays first'));
    });
  });
}
