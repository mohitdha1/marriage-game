import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/ui/state/table_view.dart';

const c = PlayingCard.new;

void main() {
  // Seat i holds i + 2 cards, so counts tell the seats apart.
  Round fourPlayerRound() => Round.fromCards(
    config: GameConfig(playerCount: 4),
    random: Random(0),
    hands: [
      for (var seat = 0; seat < 4; seat++)
        [for (var i = 0; i < seat + 2; i++) c(Suit.clubs, Rank.values[i])],
    ],
    stock: [c(Suit.hearts, Rank.two), c(Suit.hearts, Rank.three)],
    discardPile: [c(Suit.spades, Rank.king)],
  );

  String nameOf(int seat) => 'Seat $seat';

  group('TableView.fromRound', () {
    test('shows the human player their own cards, in order', () {
      final round = fourPlayerRound();

      final view = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);

      expect(view.hand, round.hands[0].cards);
      expect(view.you.name, 'Seat 0');
      expect(view.you.cardCount, 2);
    });

    test('lists opponents in turn order, starting after the human', () {
      final view = TableView.fromRound(
        fourPlayerRound(),
        humanSeat: 0,
        nameOf: nameOf,
      );

      expect(view.opponents.map((s) => s.seat), [1, 2, 3]);
      expect(view.opponents.map((s) => s.name), ['Seat 1', 'Seat 2', 'Seat 3']);
    });

    test('wraps round the table when the human is not seat 0', () {
      final view = TableView.fromRound(
        fourPlayerRound(),
        humanSeat: 2,
        nameOf: nameOf,
      );

      expect(view.opponents.map((s) => s.seat), [3, 0, 1]);
      expect(view.hand, hasLength(4));
    });

    test('opponents show only how many cards they hold', () {
      final view = TableView.fromRound(
        fourPlayerRound(),
        humanSeat: 0,
        nameOf: nameOf,
      );

      expect(view.opponents.map((s) => s.cardCount), [3, 4, 5]);
    });

    test('shows the stock size and the top discard', () {
      final view = TableView.fromRound(
        fourPlayerRound(),
        humanSeat: 0,
        nameOf: nameOf,
      );

      expect(view.stockCount, 2);
      expect(view.topDiscard, c(Suit.spades, Rank.king));
    });

    test('tracks whose turn it is and whether the human has drawn', () {
      final round = fourPlayerRound()
        ..showOpeningTunnellas(0, [])
        ..showOpeningTunnellas(1, [])
        ..showOpeningTunnellas(2, [])
        ..showOpeningTunnellas(3, []);

      final before = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);
      expect(before.currentSeat, 0);
      expect(before.isYourTurn, isTrue);
      expect(before.youHaveDrawn, isFalse);
      expect(before.winner, isNull);

      round.draw(DrawSource.stock);
      final after = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);
      expect(after.youHaveDrawn, isTrue);

      round.discard(c(Suit.clubs, Rank.two));
      final next = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);
      expect(next.currentSeat, 1);
      expect(next.isYourTurn, isFalse);
    });

    test('each seat shows its most recent discard', () {
      final round = fourPlayerRound()
        ..showOpeningTunnellas(0, [])
        ..showOpeningTunnellas(1, [])
        ..showOpeningTunnellas(2, [])
        ..showOpeningTunnellas(3, []);
      final before = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);
      expect(before.you.lastDiscard, isNull);

      round
        ..draw(DrawSource.stock)
        ..discard(c(Suit.clubs, Rank.two))
        ..draw(DrawSource.discardPile)
        ..discard(c(Suit.clubs, Rank.three));
      final after = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);

      expect(after.you.lastDiscard, c(Suit.clubs, Rank.two));
      expect(after.opponents.first.lastDiscard, c(Suit.clubs, Rank.three));
      expect(after.opponents[1].lastDiscard, isNull);
    });

    test('an empty discard pile shows as null', () {
      final round = Round.fromCards(
        config: GameConfig(playerCount: 2),
        random: Random(0),
        hands: [
          [c(Suit.clubs, Rank.two)],
          [c(Suit.clubs, Rank.three)],
        ],
        stock: [],
        discardPile: [],
      );

      final view = TableView.fromRound(round, humanSeat: 0, nameOf: nameOf);

      expect(view.topDiscard, isNull);
    });
  });
}
