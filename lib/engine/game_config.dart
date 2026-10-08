/// Settings for one match: how the shoe is built and dealt, plus which
/// optional house-rule variations are turned on. Variation toggles are plain
/// booleans for now — what each one actually changes during play is decided
/// when that rule gets implemented, not here.
class GameConfig {
  GameConfig({
    this.deckCount = 3,
    this.cardsPerPlayer = 21,
    this.playerCount = 5,
    this.murderEnabled = false,
    this.kidnapEnabled = false,
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
  final bool murderEnabled;
  final bool kidnapEnabled;
  final bool manCardsEnabled;
  final bool supermanCardEnabled;

  /// House rule: a player who has seen the joker and then discards a wild
  /// card pays [ScoringTable.jokerDiscardPenalty] to the round's winner.
  final bool jokerDiscardPenaltyEnabled;
}
