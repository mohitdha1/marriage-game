import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/player_data.dart';

void main() {
  test('a new player starts with 10,000 coins and no record', () {
    const data = PlayerData();

    expect(data.coins, 10000);
    expect(data.stats.roundsPlayed, 0);
    expect(data.stats.winRate, 0);
    expect(data.stats.bestRound, isNull);
  });

  test('coins are added and taken away', () {
    expect(
      const PlayerData().withCoinsAdded(59).withCoinsAdded(-9).coins,
      PlayerData.startingCoins + 50,
    );
  });

  test('the balance never goes below zero', () {
    expect(const PlayerData(coins: 20).withCoinsAdded(-50).coins, 0);
  });

  test('rounds are counted and the best kept', () {
    final stats = const PlayerData()
        .withGameResult(won: false, points: -5)
        .withGameResult(won: true, points: 31)
        .withGameResult(won: false, points: -12)
        .stats;

    expect(stats.roundsPlayed, 3);
    expect(stats.roundsWon, 1);
    expect(stats.bestRound, 31);
    expect(stats.winRate, closeTo(1 / 3, 1e-9));
  });

  test('a first round lost is still the best so far', () {
    expect(
      const PlayerData().withGameResult(won: false, points: -8).stats.bestRound,
      -8,
    );
  });

  test('a game result leaves the coins alone, and coins leave the stats', () {
    const data = PlayerData(coins: 500);

    expect(data.withGameResult(won: true, points: 20).coins, 500);
    expect(data.withCoinsAdded(20).stats, data.stats);
  });
}
