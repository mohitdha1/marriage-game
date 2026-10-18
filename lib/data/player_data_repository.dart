import 'economy_config.dart';
import 'gift_session.dart';
import 'player_data.dart';

/// Where the player's coins, gems and stats live. The rest of the app reads and
/// changes them only through this interface, so where they're kept (on the
/// device, or in the cloud for a signed-in player) can change without
/// touching it.
///
/// Every change goes through [addCoins], [addGems], [giveStartingGems],
/// [spendGems], [collectGift], [doubleGift], [pickExtraGiftCard],
/// [claimGiftBonus], [claimAdReward], [claimAdEntry], [addPurchase] or
/// [recordGameResult], which apply
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

  /// Adds [amount] gems, or takes them away when it's negative, and returns
  /// the data as it now stands.
  Future<PlayerData> addGems(int amount);

  /// Spends [amount] gems (see [PlayerData.withGemsSpent]) and returns the
  /// data as it now stands. Throws a [StateError] if there aren't that
  /// many, spending none.
  Future<PlayerData> spendGems(int amount);

  /// Adds the [gems] every player starts with, the first time it's called
  /// for this player and never again, and returns the data as it now
  /// stands.
  Future<PlayerData> giveStartingGems(int gems);

  /// Collects the hourly [gift] at [now] with the card [pick] (see
  /// [PlayerData.withGiftCollected]) and returns the data as it now stands.
  /// Throws a [StateError] if it isn't ready yet.
  Future<PlayerData> collectGift(HourlyGift gift, DateTime now, GiftPick pick);

  /// Doubles the open gift's free pick, for [ad] watched at [now] (see
  /// [PlayerData.withGiftDoubled]), and returns the data as it now stands.
  Future<PlayerData> doubleGift(HourlyGift gift, RewardedAd ad, DateTime now);

  /// Takes a second card, [pick], from the open gift, for [ad] watched at
  /// [now] (see [PlayerData.withGiftExtraPick]), and returns the data as it
  /// now stands.
  Future<PlayerData> pickExtraGiftCard(
    HourlyGift gift,
    RewardedAd ad,
    DateTime now,
    GiftPick pick,
  );

  /// Adds the open gift's bonus, for [ad] watched at [now] (see
  /// [PlayerData.withGiftBonus]), and returns the data as it now stands.
  Future<PlayerData> claimGiftBonus(
    HourlyGift gift,
    RewardedAd ad,
    DateTime now,
  );

  /// Pays the reward for watching [ad] at [now], in [currency] (see
  /// [PlayerData.withAdReward]) and returns the data as it now stands.
  /// Throws a [StateError] once the day's ads are used up.
  Future<PlayerData> claimAdReward(
    RewardedAd ad,
    DateTime now, [
    Currency currency = Currency.coins,
  ]);

  /// Adds [pack], just bought (see [PlayerData.withPurchase]), and returns
  /// the data as it now stands.
  Future<PlayerData> addPurchase(ShopPack pack);

  /// Counts [ad], watched at [now] in place of a match's entry fee, toward
  /// the day's limit (see [PlayerData.withAdWatched]) and returns the data
  /// as it now stands. Throws a [StateError] once the day's ads are used up.
  Future<PlayerData> claimAdEntry(RewardedAd ad, DateTime now);

  /// Counts a finished round: whether the player [won] it, the [points] it
  /// won or lost them, and the [stake] of the table, if it was played at
  /// one. Returns the data as it now stands.
  Future<PlayerData> recordGameResult({
    required bool won,
    required int points,
    int? stake,
  });
}
