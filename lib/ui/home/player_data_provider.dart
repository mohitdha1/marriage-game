import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../../data/gift_session.dart';
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

/// The time now. Tests replace it to move time on without waiting.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Draws the hourly gift's cards. Tests replace it with a seeded one.
final giftRandomProvider = Provider<Random>((ref) => Random());

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

  /// Collects the hourly gift by picking the [card] at that place on the
  /// board, and returns what it turned up, drawn by the weights; `null` if
  /// the gift wasn't ready (or the economy's amounts haven't loaded). The
  /// reward is saved before this returns, so nothing shown afterwards can
  /// lose or repeat it.
  Future<Reward?> collectGift(int card) async {
    final gift = ref.read(economyConfigProvider).value?.hourlyGift;
    final data = state.value;
    if (gift == null || data == null) return null;
    final now = ref.read(clockProvider)();
    if (data.giftWait(gift, now) > Duration.zero) return null;
    final pick = GiftPick(
      card: card,
      reward: gift.draw(ref.read(giftRandomProvider)),
    );
    return _giftChange(
      (repository) => repository.collectGift(gift, now, pick),
      pick.reward,
    );
  }

  /// The last gift's session while its extras can still be taken, or
  /// `null` if there isn't one.
  GiftSession? openGiftSession() {
    final gift = ref.read(economyConfigProvider).value?.hourlyGift;
    if (gift == null) return null;
    return state.value?.openGiftSession(gift, ref.read(clockProvider)());
  }

  /// Doubles the open gift's free pick, for a rewarded ad just watched, and
  /// returns what was added; `null` if it can't be (see
  /// [PlayerData.withGiftDoubled]).
  Future<Reward?> doubleGift() async {
    final economy = ref.read(economyConfigProvider).value;
    final session = openGiftSession();
    if (economy == null || session == null || session.doubled) return null;
    final now = ref.read(clockProvider)();
    return _giftChange(
      (repository) =>
          repository.doubleGift(economy.hourlyGift, economy.rewardedAd, now),
      session.pick.reward,
    );
  }

  /// Picks the [card] at that place as well, for a rewarded ad just
  /// watched, and returns what it turned up; `null` if it can't be picked
  /// (see [PlayerData.withGiftExtraPick]).
  Future<Reward?> pickExtraGiftCard(int card) async {
    final economy = ref.read(economyConfigProvider).value;
    final session = openGiftSession();
    if (economy == null || session == null || session.extraPick != null) {
      return null;
    }
    final gift = economy.hourlyGift;
    final pick = GiftPick(
      card: card,
      reward: gift.draw(ref.read(giftRandomProvider)),
    );
    final now = ref.read(clockProvider)();
    return _giftChange(
      (repository) =>
          repository.pickExtraGiftCard(gift, economy.rewardedAd, now, pick),
      pick.reward,
    );
  }

  /// Adds the open gift's bonus, for a rewarded ad just watched, and
  /// returns it; `null` if it can't be (see [PlayerData.withGiftBonus]).
  Future<Reward?> claimGiftBonus() async {
    final economy = ref.read(economyConfigProvider).value;
    final session = openGiftSession();
    if (economy == null || session == null || session.bonusTaken) return null;
    final now = ref.read(clockProvider)();
    return _giftChange(
      (repository) => repository.claimGiftBonus(
        economy.hourlyGift,
        economy.rewardedAd,
        now,
      ),
      economy.hourlyGift.bonus,
    );
  }

  /// Makes a gift [change] and returns its [reward], or `null` if the
  /// repository refused it.
  Future<Reward?> _giftChange(
    Future<PlayerData> Function(PlayerDataRepository) change,
    Reward reward,
  ) async {
    try {
      await _update(change);
    } on StateError {
      return null;
    }
    return reward;
  }

  /// How many more rewarded ads can pay out today, or 0 before the
  /// economy's amounts have loaded.
  int adsLeftToday() {
    final economy = ref.read(economyConfigProvider).value;
    final data = state.value;
    if (economy == null || data == null) return 0;
    return data.adsLeft(economy.rewardedAd, ref.read(clockProvider)());
  }

  /// Pays the reward for a rewarded ad just watched, and returns the coins
  /// it gave, or `null` if the day's ads were already used up.
  Future<int?> claimAdReward() async {
    final economy = ref.read(economyConfigProvider).value;
    if (economy == null || adsLeftToday() == 0) return null;
    final ad = economy.rewardedAd;
    final now = ref.read(clockProvider)();
    try {
      await _update((repository) => repository.claimAdReward(ad, now));
    } on StateError {
      return null;
    }
    return ad.coins;
  }

  /// The gems a match at [stake] costs to start, or 0 before the economy's
  /// amounts have loaded.
  int entryFeeFor(int? stake) =>
      ref.read(economyConfigProvider).value?.entryFee.gemsFor(stake) ?? 0;

  /// Pays the gems a match at [stake] costs to start, and returns whether
  /// it's paid: `true` straight away when it's free, `false`, spending
  /// nothing, when there aren't enough gems.
  Future<bool> payEntryFee(int? stake) async {
    final gems = entryFeeFor(stake);
    if (gems == 0) return true;
    if ((state.value?.gems ?? 0) < gems) return false;
    try {
      await _update((repository) => repository.spendGems(gems));
    } on StateError {
      return false;
    }
    return true;
  }

  /// Counts a rewarded ad just watched in place of a match's entry fee,
  /// and returns whether it counted: `false` if the day's ads were already
  /// used up.
  Future<bool> claimAdEntry() async {
    final economy = ref.read(economyConfigProvider).value;
    if (economy == null || adsLeftToday() == 0) return false;
    final now = ref.read(clockProvider)();
    try {
      await _update(
        (repository) => repository.claimAdEntry(economy.rewardedAd, now),
      );
    } on StateError {
      return false;
    }
    return true;
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
