import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/table_memory.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';

const c = PlayingCard.new;

void main() {
  final kingOfSpades = c(Suit.spades, Rank.king);
  final nineOfHearts = c(Suit.hearts, Rank.nine);
  final threeOfHearts = c(Suit.hearts, Rank.three);
  final twoOfClubs = c(Suit.clubs, Rank.two);

  /// Seat 0 discards 9♥, seat 1 takes it and discards 3♥, then seat 0
  /// draws and discards 2♣.
  Round playedRound({List<PlayingCard>? stock}) {
    final round =
        Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              [kingOfSpades, kingOfSpades, twoOfClubs, nineOfHearts],
              [
                c(Suit.diamonds, Rank.queen),
                c(Suit.clubs, Rank.four),
                threeOfHearts,
              ],
            ],
            stock:
                stock ??
                [for (var i = 0; i < 5; i++) c(Suit.diamonds, Rank.ace)],
            discardPile: [c(Suit.clubs, Rank.jack)],
          )
          ..showOpeningTunnellas(0, [])
          ..showOpeningTunnellas(1, []);
    round
      ..draw(DrawSource.stock)
      ..discard(nineOfHearts)
      ..draw(DrawSource.discardPile)
      ..discard(threeOfHearts)
      ..draw(DrawSource.stock)
      ..discard(twoOfClubs);
    return round;
  }

  group('stillAvailable', () {
    test('copies in your own hand are not coming back', () {
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.stillAvailable(kingOfSpades), 1);
    });

    test('a card buried in the discard pile is gone', () {
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.stillAvailable(threeOfHearts), 2);
    });

    test('the top discard can still be taken, so it counts as available', () {
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.stillAvailable(twoOfClubs), 3);
    });

    test('a card taken back out of the discard pile is not buried', () {
      // Seat 1 took 9♥, so it's in their hand: unknown, not gone.
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.stillAvailable(nineOfHearts), 3);
    });

    test('a reshuffle puts buried discards back into play', () {
      // Seat 0 draws both stock cards, so seat 1's next stock draw finds it
      // empty and reshuffles the discards.
      final round = playedRound(
        stock: [for (var i = 0; i < 2; i++) c(Suit.diamonds, Rank.ace)],
      )..draw(DrawSource.stock);

      final memory = TableMemory.read(round, 0);

      expect(memory.stillAvailable(threeOfHearts), 3);
    });
  });

  group('danger', () {
    test('cards close to what the next player took are dangerous', () {
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.danger(c(Suit.hearts, Rank.ten)), 2);
      expect(memory.danger(c(Suit.hearts, Rank.jack)), 1);
      expect(memory.danger(c(Suit.clubs, Rank.queen)), 0);
    });

    test('a card the next player threw away is safe', () {
      final memory = TableMemory.read(playedRound(), 0);

      expect(memory.danger(threeOfHearts), -2);
    });
  });
}
