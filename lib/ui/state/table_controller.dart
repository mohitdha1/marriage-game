import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/game_config.dart';
import '../../engine/round.dart';
import 'table_view.dart';

/// Settings for the current game. Overridden in tests and, later, by the
/// lobby's custom-game options.
final gameConfigProvider = Provider<GameConfig>((ref) => GameConfig());

/// The random source for shuffling. Tests override it with a seeded
/// [Random] so deals are repeatable.
final randomProvider = Provider<Random>((ref) => Random());

/// The seat the person using this device plays.
const humanSeat = 0;

/// The table as the human player sees it.
final tableProvider = NotifierProvider<TableController, TableView>(
  TableController.new,
);

/// Owns the engine's [Round] and publishes a fresh [TableView] snapshot
/// whenever it changes. The engine stays the single source of truth; widgets
/// only ever read the snapshot.
class TableController extends Notifier<TableView> {
  late Round _round;

  @override
  TableView build() {
    _round = Round.deal(
      config: ref.watch(gameConfigProvider),
      random: ref.watch(randomProvider),
    );
    return _snapshot();
  }

  TableView _snapshot() =>
      TableView.fromRound(_round, humanSeat: humanSeat, nameOf: _nameOf);

  /// Placeholder names until the Phase 2 bots get their own.
  static String _nameOf(int seat) => seat == humanSeat ? 'You' : 'Bot $seat';
}
