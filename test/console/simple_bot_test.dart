import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/console/simple_bot.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/round.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

void main() {
  final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
  final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
  final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);

  group('findPureSets', () {
    test('finds separate pure sets in a mixed hand', () {
      final cards = [
        c(Suit.diamonds, Rank.king),
        ...clubsRun,
        c(Suit.hearts, Rank.ace),
        ...spadesRun,
        ...heartsRun,
      ];

      final sets = SimpleBot.findPureSets(cards, 3)!;

      expect(sets, unorderedEquals([heartsRun, spadesRun, clubsRun]));
    });

    test('counts a tunnella as a pure set', () {
      final kings = tunnellaOf(c(Suit.diamonds, Rank.king));
      final sets = SimpleBot.findPureSets([...kings, ...heartsRun], 2)!;

      expect(sets, unorderedEquals([kings, heartsRun]));
    });

    test('never uses one card in two sets', () {
      // 3♥ 4♥ 5♥ 6♥ holds two overlapping runs, but only one fits.
      final cards = run(Suit.hearts, [
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]);

      expect(SimpleBot.findPureSets(cards, 1), isNotNull);
      expect(SimpleBot.findPureSets(cards, 2), isNull);
    });

    test('finds ace-low and ace-high runs', () {
      final aceLow = run(Suit.clubs, [Rank.ace, Rank.two, Rank.three]);
      final aceHigh = run(Suit.spades, [Rank.queen, Rank.king, Rank.ace]);

      expect(
        SimpleBot.findPureSets([...aceLow, ...aceHigh], 2),
        unorderedEquals([aceLow, aceHigh]),
      );
    });

    test('asking for no sets always succeeds', () {
      expect(SimpleBot.findPureSets([], 0), isEmpty);
    });
  });

  group('openingTunnellas', () {
    test('shows every tunnella, up to 3', () {
      final bot = SimpleBot(Random(0));
      final four = [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          ...tunnellaOf(c(Suit.clubs, rank)),
      ];

      expect(bot.openingTunnellas(heartsRun), isEmpty);
      expect(
        bot.openingTunnellas([...tunnellaOf(c(Suit.clubs, Rank.two))]),
        hasLength(1),
      );
      expect(bot.openingTunnellas(four), hasLength(3));
    });
  });

  group('chooseDiscard', () {
    final bot = SimpleBot(Random(0));

    test('throws away the card with no neighbours', () {
      final loner = c(Suit.diamonds, Rank.king);

      expect(bot.chooseDiscard([...heartsRun, loner], null), loner);
    });

    test('never discards the card it must keep', () {
      final loner = c(Suit.diamonds, Rank.king);

      expect(
        bot.chooseDiscard([...heartsRun, loner], null, mustKeep: loner),
        isNot(loner),
      );
    });

    test('keeps wild cards once the joker is known', () {
      final jokers = Jokers(c(Suit.hearts, Rank.seven));
      final wild = c(Suit.clubs, Rank.seven); // no neighbours, but wild
      final loner = c(Suit.diamonds, Rank.king);

      expect(bot.chooseDiscard([...heartsRun, wild, loner], jokers), loner);
    });
  });

  group('takeTurn', () {
    // The bot holds 3 pure runs plus K♠ K♦ 7♣ 10♦ J♦ 8♥ 2♦. After it draws
    // Q♦, the only stock card left is 7♥, so that must become the tiplu,
    // and the hand can then win by discarding 2♦.
    Round botTable() =>
        Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
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
              run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
            ],
            stock: [c(Suit.hearts, Rank.seven), c(Suit.diamonds, Rank.queen)],
            discardPile: [c(Suit.clubs, Rank.king)],
          )
          ..showOpeningTunnellas(0, [])
          ..showOpeningTunnellas(1, []);

    test('shows as soon as it can, picks the tiplu, and wins', () {
      final round = botTable();

      final turn = SimpleBot(Random(0)).takeTurn(round);

      expect(turn.drewFrom, DrawSource.stock);
      expect(turn.shown, hasLength(3));
      expect(turn.pickedTiplu, isTrue);
      expect(round.jokersFor(0)!.tiplu, c(Suit.hearts, Rank.seven));
      expect(turn.won, isTrue);
      expect(round.winner, 0);
    });

    test('without a show or a win, it just draws and discards', () {
      final round = botTable()
        ..draw(DrawSource.stock)
        ..discard(c(Suit.diamonds, Rank.two));
      // Seat 1 has no sets, so it can only draw and discard.

      final turn = SimpleBot(Random(0)).takeTurn(round);

      expect(turn.shown, isEmpty);
      expect(turn.won, isFalse);
      expect(turn.discarded, isNotNull);
      expect(round.currentSeat, 0);
    });
  });
}
