import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/preferences.dart';

/// The player's record over every round they've finished on this device.
@immutable
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
}

/// The player's stats, saved between launches. Every round the device's
/// owner finishes counts: against bots, hosting, or joined to a friend's
/// game. Pass and play doesn't, as several people share the device.
final statsProvider = NotifierProvider<StatsController, PlayerStats>(
  StatsController.new,
);

class StatsController extends Notifier<PlayerStats> {
  static const _played = 'stats.roundsPlayed';
  static const _won = 'stats.roundsWon';
  static const _best = 'stats.bestRound';

  @override
  PlayerStats build() {
    final store = ref.watch(preferencesProvider);
    return PlayerStats(
      roundsPlayed: store.getInt(_played) ?? 0,
      roundsWon: store.getInt(_won) ?? 0,
      bestRound: store.getInt(_best),
    );
  }

  /// Counts a finished round: whether the player [won] it, and the
  /// [points] it won or lost them.
  void recordRound({required bool won, required int points}) {
    final best = state.bestRound;
    state = PlayerStats(
      roundsPlayed: state.roundsPlayed + 1,
      roundsWon: state.roundsWon + (won ? 1 : 0),
      bestRound: best == null || points > best ? points : best,
    );
    final store = ref.read(preferencesProvider);
    store
      ..setInt(_played, state.roundsPlayed)
      ..setInt(_won, state.roundsWon)
      ..setInt(_best, state.bestRound!);
  }
}
