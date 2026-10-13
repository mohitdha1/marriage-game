import 'package:flutter/foundation.dart';

import '../../engine/game_config.dart';

/// The rules a match is played by, beyond who plays it: the [GameMode] and
/// the optional house rules. Equal when every rule matches.
@immutable
class HouseRules {
  const HouseRules({
    this.mode = GameMode.standard,
    this.manCards = false,
    this.superman = false,
    this.alterIsMaal = true,
    this.jokerPenalty = true,
  });

  /// See [GameConfig.mode].
  final GameMode mode;

  /// See [GameConfig.manCardsEnabled].
  final bool manCards;

  /// See [GameConfig.supermanCardEnabled].
  final bool superman;

  /// See [GameConfig.alterIsMaal].
  final bool alterIsMaal;

  /// See [GameConfig.jokerDiscardPenaltyEnabled].
  final bool jokerPenalty;

  /// The engine's settings for a game of [playerCount] under these rules.
  GameConfig configFor(int playerCount) => GameConfig(
    playerCount: playerCount,
    mode: mode,
    manCardsEnabled: manCards,
    supermanCardEnabled: superman,
    alterIsMaal: alterIsMaal,
    jokerDiscardPenaltyEnabled: jokerPenalty,
  );

  HouseRules copyWith({
    GameMode? mode,
    bool? manCards,
    bool? superman,
    bool? alterIsMaal,
    bool? jokerPenalty,
  }) => HouseRules(
    mode: mode ?? this.mode,
    manCards: manCards ?? this.manCards,
    superman: superman ?? this.superman,
    alterIsMaal: alterIsMaal ?? this.alterIsMaal,
    jokerPenalty: jokerPenalty ?? this.jokerPenalty,
  );

  @override
  bool operator ==(Object other) =>
      other is HouseRules &&
      other.mode == mode &&
      other.manCards == manCards &&
      other.superman == superman &&
      other.alterIsMaal == alterIsMaal &&
      other.jokerPenalty == jokerPenalty;

  @override
  int get hashCode =>
      Object.hash(mode, manCards, superman, alterIsMaal, jokerPenalty);
}
