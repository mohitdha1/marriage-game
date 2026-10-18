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
/// coins and gems, their stats, and how many games they've played at each
/// stake.
class PlayerData {
  const PlayerData({
    this.coins = startingCoins,
    this.gems = 0,
    this.stats = const PlayerStats(),
    this.gamesAtStake = const {},
  });

  /// What a new player starts with.
  static const startingCoins = 10000;

  /// The most coins a player can hold.
  static const maxCoins = 1 << 31;

  final int coins;

  /// The second, scarcer currency. A new player's gems come from the
  /// economy's data file.
  final int gems;

  final PlayerStats stats;

  /// Games played at each stake table, by its stake. Stakes not played
  /// yet are left out.
  final Map<int, int> gamesAtStake;

  /// Games played at the table with [stake].
  int gamesAt(int stake) => gamesAtStake[stake] ?? 0;

  /// This data with [amount] coins added, or taken away when [amount] is
  /// negative. The balance never goes below zero.
  PlayerData withCoinsAdded(int amount) =>
      _copyWith(coins: (coins + amount).clamp(0, maxCoins));

  /// This data with [amount] gems added, or taken away when [amount] is
  /// negative. The balance never goes below zero.
  PlayerData withGemsAdded(int amount) =>
      _copyWith(gems: (gems + amount).clamp(0, maxCoins));

  /// This data with a finished round counted in the stats, and, when it
  /// was played at a stake table, as a game at that [stake].
  PlayerData withGameResult({
    required bool won,
    required int points,
    int? stake,
  }) => _copyWith(
    stats: stats.withRound(won: won, points: points),
    gamesAtStake: stake == null
        ? gamesAtStake
        : Map.unmodifiable({...gamesAtStake, stake: gamesAt(stake) + 1}),
  );

  PlayerData _copyWith({
    int? coins,
    int? gems,
    PlayerStats? stats,
    Map<int, int>? gamesAtStake,
  }) => PlayerData(
    coins: coins ?? this.coins,
    gems: gems ?? this.gems,
    stats: stats ?? this.stats,
    gamesAtStake: gamesAtStake ?? this.gamesAtStake,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerData &&
      other.coins == coins &&
      other.gems == gems &&
      other.stats == stats &&
      other.gamesAtStake.length == gamesAtStake.length &&
      gamesAtStake.entries.every((e) => other.gamesAtStake[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    coins,
    gems,
    stats,
    Object.hashAllUnordered(gamesAtStake.entries.map((e) => (e.key, e.value))),
  );
}
