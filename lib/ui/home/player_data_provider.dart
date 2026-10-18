import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_player_data_repository.dart';
import '../../data/player_data.dart';
import '../../data/player_data_repository.dart';
import '../settings/preferences.dart';
import 'economy_config_provider.dart';

/// Where the player's coins, gems and stats are kept: on the device for
/// now. A cloud-backed repository for signed-in players replaces it here and
/// nowhere else.
final playerDataRepositoryProvider = Provider<PlayerDataRepository>(
  (ref) => LocalPlayerDataRepository(ref.watch(preferencesProvider)),
);

/// The player's coins, gems and stats, loaded from [playerDataRepositoryProvider].
/// Screens watch it; changes go through [PlayerDataController], which passes
/// them to the repository.
final playerDataProvider =
    AsyncNotifierProvider<PlayerDataController, PlayerData>(
      PlayerDataController.new,
    );

class PlayerDataController extends AsyncNotifier<PlayerData> {
  /// The last change asked for, so the next waits its turn and the shown
  /// data always ends on the newest.
  Future<void> _pending = Future.value();

  @override
  Future<PlayerData> build() {
    final loading = ref.watch(playerDataRepositoryProvider).load();
    // A change asked for while loading waits until the load is in.
    _pending = loading.then((_) {}, onError: (_) {});
    // A new player's gems follow once the economy's amounts are read. The
    // data doesn't wait for them, so the economy never holds up the app.
    unawaited(
      ref
          .read(economyConfigProvider.future)
          .then((economy) => giveStartingGems(economy.startingGems))
          .catchError((Object e) => debugPrint('No starting gems: $e')),
    );
    return loading;
  }

  /// Gives a new player their starting gems; a player who has had them
  /// keeps the gems they have.
  Future<void> giveStartingGems(int gems) =>
      _update((repository) => repository.giveStartingGems(gems));

  /// Adds [amount] coins, or takes them away when it's negative.
  Future<void> addCoins(int amount) =>
      _update((repository) => repository.addCoins(amount));

  /// Adds [amount] gems, or takes them away when it's negative.
  Future<void> addGems(int amount) =>
      _update((repository) => repository.addGems(amount));

  /// Counts a finished round: whether the player [won] it, the [points] it
  /// won or lost them, and the [stake] of the table, if it was played at
  /// one.
  Future<void> recordGameResult({
    required bool won,
    required int points,
    int? stake,
  }) => _update(
    (repository) =>
        repository.recordGameResult(won: won, points: points, stake: stake),
  );

  Future<void> _update(
    Future<PlayerData> Function(PlayerDataRepository) change,
  ) {
    final repository = ref.read(playerDataRepositoryProvider);
    final done = _pending.then((_) async {
      final data = await change(repository);
      if (ref.mounted) state = AsyncData(data);
    });
    // One failed change doesn't hold up the ones after it.
    _pending = done.then((_) {}, onError: (_) {});
    return done;
  }
}
