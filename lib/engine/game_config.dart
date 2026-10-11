/// How a round treats players who haven't seen the joker when it ends.
enum GameMode {
  /// Their maal counts for nothing.
  standard,

  /// Their maal, apart from opening tunnellas, counts for the winner.
  kidnap,

  /// Their maal counts for nothing, and each pays the winner the winner's
  /// maal on top of the usual 10.
  murder,
}

/// Settings for one match: how the shoe is built and dealt, the [GameMode],
/// and which optional house rules are turned on.
class GameConfig {
  GameConfig({
    this.deckCount = 3,
    this.cardsPerPlayer = 21,
    this.playerCount = 5,
    this.mode = GameMode.standard,
    this.manCardsEnabled = false,
    this.supermanCardEnabled = false,
    this.jokerDiscardPenaltyEnabled = true,
  }) {
    if (playerCount < 2 || playerCount > 5) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'must be between 2 and 5',
      );
    }
  }

  final int deckCount;
  final int cardsPerPlayer;
  final int playerCount;
  final GameMode mode;
  final bool manCardsEnabled;
  final bool supermanCardEnabled;

  /// House rule: a player who has seen the joker and then discards a wild
  /// card pays [ScoringTable.jokerDiscardPenalty] to the round's winner.
  final bool jokerDiscardPenaltyEnabled;
}
