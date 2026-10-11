import 'player_data.dart';

/// Where the player's coins and stats live. The rest of the app reads and
/// changes them only through this interface, so where they're kept (on the
/// device, or in the cloud for a signed-in player) can change without
/// touching it.
///
/// Every change goes through [addCoins] or [recordGameResult], which apply
/// the rules in [PlayerData] to the stored data and return the result, so a
/// store shared between devices can make each change in one step.
abstract interface class PlayerDataRepository {
  /// The player's data, or a new player's if nothing has been saved.
  Future<PlayerData> load();

  /// Replaces everything stored with [data].
  Future<void> save(PlayerData data);

  /// Adds [amount] coins, or takes them away when it's negative, and returns
  /// the data as it now stands.
  Future<PlayerData> addCoins(int amount);

  /// Counts a finished round: whether the player [won] it, the [points] it
  /// won or lost them, and the [stake] of the table, if it was played at
  /// one. Returns the data as it now stands.
  Future<PlayerData> recordGameResult({
    required bool won,
    required int points,
    int? stake,
  });
}
