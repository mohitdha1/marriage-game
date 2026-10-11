/// The player's record over every round they've finished.
class PlayerStats {
  const PlayerStats({
    this.roundsPlayed = 0,
    this.roundsWon = 0,
    this.bestRound,
  });

  final int roundsPlayed;
  final int roundsWon;

  /// The most points won in one round, or `null` before the first round.
  final int? bestRound;

  /// The share of rounds won, from 0 to 1; 0 before the first round.
  double get winRate => roundsPlayed == 0 ? 0 : roundsWon / roundsPlayed;

  /// These stats with one more finished round: whether the player [won] it,
  /// and the [points] it won or lost them.
  PlayerStats withRound({required bool won, required int points}) {
    final best = bestRound;
    return PlayerStats(
      roundsPlayed: roundsPlayed + 1,
      roundsWon: roundsWon + (won ? 1 : 0),
      bestRound: best == null || points > best ? points : best,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerStats &&
      other.roundsPlayed == roundsPlayed &&
      other.roundsWon == roundsWon &&
      other.bestRound == bestRound;

  @override
  int get hashCode => Object.hash(roundsPlayed, roundsWon, bestRound);
}

/// Everything the app keeps about the player's progress: their play-money
/// coins and their stats.
class PlayerData {
  const PlayerData({
    this.coins = startingCoins,
    this.stats = const PlayerStats(),
  });

  /// What a new player starts with.
  static const startingCoins = 10000;

  /// The most coins a player can hold.
  static const maxCoins = 1 << 31;

  final int coins;
  final PlayerStats stats;

  /// This data with [amount] coins added, or taken away when [amount] is
  /// negative. The balance never goes below zero.
  PlayerData withCoinsAdded(int amount) =>
      PlayerData(coins: (coins + amount).clamp(0, maxCoins), stats: stats);

  /// This data with a finished round counted in the stats.
  PlayerData withGameResult({required bool won, required int points}) =>
      PlayerData(
        coins: coins,
        stats: stats.withRound(won: won, points: points),
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerData && other.coins == coins && other.stats == stats;

  @override
  int get hashCode => Object.hash(coins, stats);
}
