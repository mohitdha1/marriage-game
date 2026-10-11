import 'dart:convert';

import '../ui/settings/preferences.dart';
import 'player_data.dart';
import 'player_data_repository.dart';

/// Keeps the player's coins and stats on the device, among the app's saved
/// preferences.
class LocalPlayerDataRepository implements PlayerDataRepository {
  LocalPlayerDataRepository(this._store);

  final PreferencesStore _store;

  static const _coins = 'coins.balance';
  static const _played = 'stats.roundsPlayed';
  static const _won = 'stats.roundsWon';
  static const _best = 'stats.bestRound';
  static const _gamesAtStake = 'stakes.gamesPlayed';

  @override
  Future<PlayerData> load() async => _read();

  @override
  Future<void> save(PlayerData data) async {
    final best = data.stats.bestRound;
    await Future.wait([
      _store.setInt(_coins, data.coins),
      _store.setInt(_played, data.stats.roundsPlayed),
      _store.setInt(_won, data.stats.roundsWon),
      if (best != null) _store.setInt(_best, best),
      _store.setString(
        _gamesAtStake,
        jsonEncode({
          for (final MapEntry(:key, :value) in data.gamesAtStake.entries)
            '$key': value,
        }),
      ),
    ]);
  }

  @override
  Future<PlayerData> addCoins(int amount) =>
      _change((data) => data.withCoinsAdded(amount));

  @override
  Future<PlayerData> recordGameResult({
    required bool won,
    required int points,
    int? stake,
  }) => _change(
    (data) => data.withGameResult(won: won, points: points, stake: stake),
  );

  /// Reads, changes and saves the data. The read and the start of the save
  /// happen together, before anything else can run, so changes made one
  /// after another without waiting are all kept.
  Future<PlayerData> _change(PlayerData Function(PlayerData) change) async {
    final data = change(_read());
    await save(data);
    return data;
  }

  PlayerData _read() => PlayerData(
    coins: _store.getInt(_coins) ?? PlayerData.startingCoins,
    stats: PlayerStats(
      roundsPlayed: _store.getInt(_played) ?? 0,
      roundsWon: _store.getInt(_won) ?? 0,
      bestRound: _store.getInt(_best),
    ),
    gamesAtStake: _readGamesAtStake(),
  );

  Map<int, int> _readGamesAtStake() {
    final saved = _store.getString(_gamesAtStake);
    if (saved == null) return const {};
    final decoded = jsonDecode(saved) as Map<String, Object?>;
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in decoded.entries)
        int.parse(key): value as int,
    });
  }
}
