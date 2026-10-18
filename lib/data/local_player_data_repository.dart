import 'dart:convert';

import '../ui/settings/preferences.dart';
import 'economy_config.dart';
import 'gift_session.dart';
import 'player_data.dart';
import 'player_data_repository.dart';

/// Keeps the player's coins, gems and stats on the device, among the app's
/// saved preferences.
class LocalPlayerDataRepository implements PlayerDataRepository {
  LocalPlayerDataRepository(this._store);

  final PreferencesStore _store;

  static const _coins = 'coins.balance';
  static const _gems = 'gems.balance';
  static const _startingGemsGiven = 'gems.startingGiven';
  static const _giftCollectedAt = 'gift.collectedAt';
  static const _giftsCollected = 'gift.count';
  static const _giftSession = 'gift.session';
  static const _adDay = 'ads.day';
  static const _adsWatched = 'ads.watched';
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
      _store.setInt(_gems, data.gems),
      if (data.giftCollectedAt case final at?)
        _store.setInt(_giftCollectedAt, at.millisecondsSinceEpoch),
      _store.setInt(_giftsCollected, data.giftsCollected),
      if (data.giftSession case final session?)
        _store.setString(_giftSession, jsonEncode(session.toJson())),
      if (data.adDay case final day?) _store.setString(_adDay, day),
      _store.setInt(_adsWatched, data.adsWatched),
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
  Future<PlayerData> addGems(int amount) =>
      _change((data) => data.withGemsAdded(amount));

  @override
  Future<PlayerData> spendGems(int amount) =>
      _change((data) => data.withGemsSpent(amount));

  @override
  Future<PlayerData> collectGift(
    HourlyGift gift,
    DateTime now,
    GiftPick pick,
  ) => _change((data) => data.withGiftCollected(gift, now, pick));

  @override
  Future<PlayerData> doubleGift(HourlyGift gift, RewardedAd ad, DateTime now) =>
      _change((data) => data.withGiftDoubled(gift, ad, now));

  @override
  Future<PlayerData> pickExtraGiftCard(
    HourlyGift gift,
    RewardedAd ad,
    DateTime now,
    GiftPick pick,
  ) => _change((data) => data.withGiftExtraPick(gift, ad, now, pick));

  @override
  Future<PlayerData> claimGiftBonus(
    HourlyGift gift,
    RewardedAd ad,
    DateTime now,
  ) => _change((data) => data.withGiftBonus(gift, ad, now));

  @override
  Future<PlayerData> claimAdReward(
    RewardedAd ad,
    DateTime now, [
    Currency currency = Currency.coins,
  ]) => _change((data) => data.withAdReward(ad, now, currency));

  @override
  Future<PlayerData> addPurchase(ShopPack pack) =>
      _change((data) => data.withPurchase(pack));

  @override
  Future<PlayerData> claimAdEntry(RewardedAd ad, DateTime now) =>
      _change((data) => data.withAdWatched(ad, now));

  @override
  Future<PlayerData> giveStartingGems(int gems) async {
    if (_store.getBool(_startingGemsGiven) ?? false) return _read();
    final data = _read().withGemsAdded(gems);
    await Future.wait([_store.setBool(_startingGemsGiven, true), save(data)]);
    return data;
  }

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
    gems: _store.getInt(_gems) ?? 0,
    giftCollectedAt: switch (_store.getInt(_giftCollectedAt)) {
      final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
      null => null,
    },
    giftsCollected: _store.getInt(_giftsCollected) ?? 0,
    giftSession: _readGiftSession(),
    adDay: _store.getString(_adDay),
    adsWatched: _store.getInt(_adsWatched) ?? 0,
    stats: PlayerStats(
      roundsPlayed: _store.getInt(_played) ?? 0,
      roundsWon: _store.getInt(_won) ?? 0,
      bestRound: _store.getInt(_best),
    ),
    gamesAtStake: _readGamesAtStake(),
  );

  /// The last gift's session; `null` if there's none, or it can't be read,
  /// when the extras on offer are lost but nothing already given is.
  GiftSession? _readGiftSession() {
    final saved = _store.getString(_giftSession);
    if (saved == null) return null;
    try {
      return GiftSession.fromJson(jsonDecode(saved) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

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
