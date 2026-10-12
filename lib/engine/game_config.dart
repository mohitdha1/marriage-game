import 'card.dart';

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
    this.alterIsMaal = true,
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

  /// House rule: one man card ([PlayingCard.man]) per deck in the shoe.
  final bool manCardsEnabled;

  /// House rule: one Superman ([PlayingCard.superman]) in the shoe.
  final bool supermanCardEnabled;

  /// House rule: the alter is maal. When off, it is scored exactly like an
  /// ordinary joker: still wild, but worth nothing loose, and an opening
  /// tunnella of alters is worth [ScoringTable.ordinaryTunnella].
  final bool alterIsMaal;

  /// House rule: a player who has seen the joker and then discards a wild
  /// card pays [ScoringTable.jokerDiscardPenalty] to the round's winner.
  /// Discarding the Superman costs it whether or not they've seen the
  /// joker.
  final bool jokerDiscardPenaltyEnabled;
}
