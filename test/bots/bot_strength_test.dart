/// Long match-ups between bot difficulties. Skipped in the normal run (see
/// dart_test.yaml); run them with:
///
///     flutter test --tags strength --run-skipped
@Tags(['strength'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';

const _steady = BotPersonality(
  name: 'Test',
  tagline: 'For tests',
  avatarColor: 0xFFFFFFFF,
);

/// How [a] did against [b] over 4-player rounds: rounds won by each, and
/// [a]'s net points over all of them.
///
/// Each of [deals] fixed deals is played twice, [a] in seats 0 and 2 and
/// then in seats 1 and 3, so luck of the deal falls on both sides equally.
/// Every bot draws on its own seeded random numbers, so the result is the
/// same on every run.
({int winsA, int winsB, int netA}) matchUp(
  BotDifficulty a,
  BotDifficulty b, {
  required int deals,
}) {
  var winsA = 0;
  var winsB = 0;
  var netA = 0;
  for (var deal = 0; deal < deals; deal++) {
    for (final aOnEven in [true, false]) {
      final difficulties = [
        for (var seat = 0; seat < 4; seat++) seat.isEven == aOnEven ? a : b,
      ];
      final bots = [
        for (var seat = 0; seat < 4; seat++)
          BotPlayer(
            difficulty: difficulties[seat],
            personality: _steady,
            random: Random(deal * 31 + seat),
          ),
      ];
      final round = Round.deal(
        config: GameConfig(playerCount: 4),
        random: Random(deal),
      );
      for (var seat = 0; seat < 4; seat++) {
        round.showOpeningTunnellas(
          seat,
          bots[seat].openingTunnellas(round.hands[seat].cards),
        );
      }
      for (var turn = 0; turn < 3000 && !round.isOver; turn++) {
        bots[round.currentSeat].takeTurn(round);
      }
      final winner = round.winner;
      if (winner == null) continue;
      if (difficulties[winner] == a) {
        winsA++;
      } else {
        winsB++;
      }
      final net = round.score().net;
      for (var seat = 0; seat < 4; seat++) {
        if (difficulties[seat] == a) netA += net[seat];
      }
    }
  }
  return (winsA: winsA, winsB: winsB, netA: netA);
}

void main() {
  test('Hard beats Medium over 200 rounds', () {
    final result = matchUp(
      BotDifficulty.hard,
      BotDifficulty.medium,
      deals: 100,
    );
    final summary =
        'Hard won ${result.winsA}, Medium ${result.winsB}; '
        'Hard net ${result.netA}';

    expect(
      result.winsA + result.winsB,
      greaterThanOrEqualTo(200),
      reason: summary,
    );
    expect(result.winsA, greaterThan(result.winsB), reason: summary);
    expect(result.netA, greaterThan(0), reason: summary);
  });
}
