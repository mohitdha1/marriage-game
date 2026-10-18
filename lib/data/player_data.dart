import 'economy_config.dart';
import 'gift_session.dart';

/// The player's record over every round they've finished.
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

  /// These stats with one more finished round: whether the player [won] it,
  /// and the [points] it won or lost them.
  PlayerStats withRound({required bool won, required int points}) {
    final best = bestRound;
    return PlayerStats(
      roundsPlayed: roundsPlayed + 1,
      roundsWon: roundsWon + (won ? 1 : 0),
      bestRound: best == null || points > best ? points : best,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerStats &&
      other.roundsPlayed == roundsPlayed &&
      other.roundsWon == roundsWon &&
      other.bestRound == bestRound;

  @override
  int get hashCode => Object.hash(roundsPlayed, roundsWon, bestRound);
}

/// Everything the app keeps about the player's progress: their play-money
/// coins and gems, their stats, how many games they've played at each
/// stake, their hourly gifts and today's rewarded ads.
class PlayerData {
  const PlayerData({
    this.coins = startingCoins,
    this.gems = 0,
    this.stats = const PlayerStats(),
    this.gamesAtStake = const {},
    this.giftCollectedAt,
    this.giftsCollected = 0,
    this.giftSession,
    this.adDay,
    this.adsWatched = 0,
  });

  /// What a new player starts with.
  static const startingCoins = 10000;

  /// The most coins a player can hold.
  static const maxCoins = 1 << 31;

  final int coins;

  /// The second, scarcer currency. A new player's gems come from the
  /// economy's data file.
  final int gems;

  final PlayerStats stats;

  /// Games played at each stake table, by its stake. Stakes not played
  /// yet are left out.
  final Map<int, int> gamesAtStake;

  /// When the hourly gift was last collected, or `null` if it never has
  /// been, when the first one is ready straight away.
  final DateTime? giftCollectedAt;

  /// How many hourly gifts have been collected.
  final int giftsCollected;

  /// What became of the last hourly gift collected, or `null` before the
  /// first.
  final GiftSession? giftSession;

  /// The local day of the last rewarded ad, as [dayOf] writes it, or
  /// `null` before the first.
  final String? adDay;

  /// Rewarded ads watched on [adDay].
  final int adsWatched;

  /// The local day [time] falls on, as "2026-10-07". A new day starts at
  /// midnight on the device's clock.
  static String dayOf(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }

  /// How many more rewarded [ad]s can pay out on the day of [now].
  int adsLeft(RewardedAd ad, DateTime now) {
    final watched = adDay == dayOf(now) ? adsWatched : 0;
    return (ad.perDay - watched).clamp(0, ad.perDay);
  }

  /// This data with the reward for watching [ad] at [now] added, and the
  /// ad counted toward that day's limit. Throws a [StateError] once the
  /// day's ads are used up.
  PlayerData withAdReward(RewardedAd ad, DateTime now) =>
      withAdWatched(ad, now).withCoinsAdded(ad.coins);

  /// This data with [ad], watched at [now] in place of a match's entry fee,
  /// counted toward that day's limit; it pays no coins. Throws a
  /// [StateError] once the day's ads are used up.
  PlayerData withAdWatched(RewardedAd ad, DateTime now) {
    if (adsLeft(ad, now) == 0) {
      throw StateError('No more rewarded ads today');
    }
    final today = dayOf(now);
    return _copyWith(
      adDay: today,
      adsWatched: (adDay == today ? adsWatched : 0) + 1,
    );
  }

  /// How long until the next [gift] can be collected at [now]: zero once
  /// it's ready. The wait counts from the last collection, so it carries on
  /// while the app is closed. If the device's clock was turned back, the
  /// wait is never longer than one [HourlyGift.interval].
  Duration giftWait(HourlyGift gift, DateTime now) {
    final last = giftCollectedAt;
    if (last == null) return Duration.zero;
    final left = gift.interval - now.difference(last);
    if (left <= Duration.zero) return Duration.zero;
    return left > gift.interval ? gift.interval : left;
  }

  /// The last gift's session while its extras can still be taken: from
  /// its collection until the next [gift] is ready.
  GiftSession? openGiftSession(HourlyGift gift, DateTime now) =>
      giftWait(gift, now) > Duration.zero ? giftSession : null;

  /// This data with [gift] collected at [now] by picking a card: [pick]'s
  /// reward added, a new session begun and the wait started again. Throws
  /// a [StateError] if the gift isn't ready yet.
  PlayerData withGiftCollected(HourlyGift gift, DateTime now, GiftPick pick) {
    if (giftWait(gift, now) > Duration.zero) {
      throw StateError('The gift isn\'t ready yet');
    }
    _checkOnBoard(pick);
    return _withReward(pick.reward)._copyWith(
      giftCollectedAt: now,
      giftsCollected: giftsCollected + 1,
      giftSession: GiftSession(pick: pick),
    );
  }

  /// This data with the free pick of the open gift session given again,
  /// for [ad] watched at [now]. Throws a [StateError] if there's no open
  /// session, it has already been doubled, or the day's ads are used up.
  PlayerData withGiftDoubled(HourlyGift gift, RewardedAd ad, DateTime now) {
    final session = _openSession(gift, now);
    if (session.doubled) throw StateError('The gift is already doubled');
    return withAdWatched(ad, now)
        ._withReward(session.pick.reward)
        ._copyWith(giftSession: session.copyWith(doubled: true));
  }

  /// This data with a second card, [pick], taken in the open gift session
  /// for [ad] watched at [now]. Throws a [StateError] if there's no open
  /// session, a second card has been taken already, [pick] is the card
  /// picked first, or the day's ads are used up.
  PlayerData withGiftExtraPick(
    HourlyGift gift,
    RewardedAd ad,
    DateTime now,
    GiftPick pick,
  ) {
    final session = _openSession(gift, now);
    if (session.extraPick != null) {
      throw StateError('Another card was already picked');
    }
    _checkOnBoard(pick);
    if (pick.card == session.pick.card) {
      throw StateError('That card was already picked');
    }
    return withAdWatched(ad, now)
        ._withReward(pick.reward)
        ._copyWith(giftSession: session.copyWith(extraPick: pick));
  }

  /// This data with [gift]'s bonus added in the open gift session, for
  /// [ad] watched at [now]. Throws a [StateError] if there's no open
  /// session, the bonus was taken already, or the day's ads are used up.
  PlayerData withGiftBonus(HourlyGift gift, RewardedAd ad, DateTime now) {
    final session = _openSession(gift, now);
    if (session.bonusTaken) throw StateError('The bonus was already taken');
    return withAdWatched(ad, now)
        ._withReward(gift.bonus)
        ._copyWith(giftSession: session.copyWith(bonusTaken: true));
  }

  static void _checkOnBoard(GiftPick pick) {
    if (pick.card < 0 || pick.card >= HourlyGift.boardSize) {
      throw RangeError.range(pick.card, 0, HourlyGift.boardSize - 1, 'card');
    }
  }

  GiftSession _openSession(HourlyGift gift, DateTime now) =>
      openGiftSession(gift, now) ??
      (throw StateError('No gift is open to add to'));

  PlayerData _withReward(Reward reward) =>
      withCoinsAdded(reward.coins).withGemsAdded(reward.gems);

  /// Games played at the table with [stake].
  int gamesAt(int stake) => gamesAtStake[stake] ?? 0;

  /// This data with [amount] coins added, or taken away when [amount] is
  /// negative. The balance never goes below zero.
  PlayerData withCoinsAdded(int amount) =>
      _copyWith(coins: (coins + amount).clamp(0, maxCoins));

  /// This data with [amount] gems added, or taken away when [amount] is
  /// negative. The balance never goes below zero.
  PlayerData withGemsAdded(int amount) =>
      _copyWith(gems: (gems + amount).clamp(0, maxCoins));

  /// This data with [amount] gems spent. Throws a [StateError] if there
  /// aren't that many, leaving the balance as it was.
  PlayerData withGemsSpent(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    if (gems < amount) throw StateError('Not enough gems');
    return _copyWith(gems: gems - amount);
  }

  /// This data with a finished round counted in the stats, and, when it
  /// was played at a stake table, as a game at that [stake].
  PlayerData withGameResult({
    required bool won,
    required int points,
    int? stake,
  }) => _copyWith(
    stats: stats.withRound(won: won, points: points),
    gamesAtStake: stake == null
        ? gamesAtStake
        : Map.unmodifiable({...gamesAtStake, stake: gamesAt(stake) + 1}),
  );

  PlayerData _copyWith({
    int? coins,
    int? gems,
    PlayerStats? stats,
    Map<int, int>? gamesAtStake,
    DateTime? giftCollectedAt,
    int? giftsCollected,
    GiftSession? giftSession,
    String? adDay,
    int? adsWatched,
  }) => PlayerData(
    coins: coins ?? this.coins,
    gems: gems ?? this.gems,
    stats: stats ?? this.stats,
    gamesAtStake: gamesAtStake ?? this.gamesAtStake,
    giftCollectedAt: giftCollectedAt ?? this.giftCollectedAt,
    giftsCollected: giftsCollected ?? this.giftsCollected,
    giftSession: giftSession ?? this.giftSession,
    adDay: adDay ?? this.adDay,
    adsWatched: adsWatched ?? this.adsWatched,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerData &&
      other.coins == coins &&
      other.gems == gems &&
      other.giftCollectedAt == giftCollectedAt &&
      other.giftsCollected == giftsCollected &&
      other.giftSession == giftSession &&
      other.adDay == adDay &&
      other.adsWatched == adsWatched &&
      other.stats == stats &&
      other.gamesAtStake.length == gamesAtStake.length &&
      gamesAtStake.entries.every((e) => other.gamesAtStake[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    coins,
    gems,
    giftCollectedAt,
    giftsCollected,
    giftSession,
    adDay,
    adsWatched,
    stats,
    Object.hashAllUnordered(gamesAtStake.entries.map((e) => (e.key, e.value))),
  );
}
