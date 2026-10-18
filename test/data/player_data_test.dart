import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/player_data.dart';

void main() {
  test('a new player starts with 10,000 coins and no record', () {
    const data = PlayerData();

    expect(data.coins, 10000);
    expect(data.stats.roundsPlayed, 0);
    expect(data.stats.winRate, 0);
    expect(data.stats.bestRound, isNull);
  });

  test('coins are added and taken away', () {
    expect(
      const PlayerData().withCoinsAdded(59).withCoinsAdded(-9).coins,
      PlayerData.startingCoins + 50,
    );
  });

  test('the balance never goes below zero', () {
    expect(const PlayerData(coins: 20).withCoinsAdded(-50).coins, 0);
  });

  test('gems are added and taken away, never below zero', () {
    final data = const PlayerData(gems: 3).withGemsAdded(4).withGemsAdded(-2);

    expect(data.gems, 5);
    expect(data.withGemsAdded(-9).gems, 0);
  });

  test('gems are spent only when there are enough', () {
    const data = PlayerData(coins: 700, gems: 2);

    expect(data.withGemsSpent(2).gems, 0);
    expect(data.withGemsSpent(1).coins, 700);
    expect(() => data.withGemsSpent(3), throwsStateError);
    expect(() => data.withGemsSpent(-1), throwsArgumentError);
  });

  test('changing one balance keeps everything else', () {
    const data = PlayerData(
      coins: 500,
      gems: 7,
      stats: PlayerStats(roundsPlayed: 2, roundsWon: 1, bestRound: 9),
      gamesAtStake: {5: 2},
    );

    expect(
      data.withGemsAdded(1),
      const PlayerData(
        coins: 500,
        gems: 8,
        stats: PlayerStats(roundsPlayed: 2, roundsWon: 1, bestRound: 9),
        gamesAtStake: {5: 2},
      ),
    );
    expect(data.withCoinsAdded(1).gems, 7);
    expect(data.withGameResult(won: true, points: 3).gems, 7);
  });

  test('gems count toward equality', () {
    expect(const PlayerData(gems: 1), isNot(const PlayerData(gems: 2)));
    expect(
      const PlayerData(gems: 2).hashCode,
      const PlayerData(gems: 2).hashCode,
    );
  });

  test('rounds are counted and the best kept', () {
    final stats = const PlayerData()
        .withGameResult(won: false, points: -5)
        .withGameResult(won: true, points: 31)
        .withGameResult(won: false, points: -12)
        .stats;

    expect(stats.roundsPlayed, 3);
    expect(stats.roundsWon, 1);
    expect(stats.bestRound, 31);
    expect(stats.winRate, closeTo(1 / 3, 1e-9));
  });

  test('a first round lost is still the best so far', () {
    expect(
      const PlayerData().withGameResult(won: false, points: -8).stats.bestRound,
      -8,
    );
  });

  test('a game result leaves the coins alone, and coins leave the stats', () {
    const data = PlayerData(coins: 500);

    expect(data.withGameResult(won: true, points: 20).coins, 500);
    expect(data.withCoinsAdded(20).stats, data.stats);
  });

  test('a game at a stake table counts toward that stake', () {
    final data = const PlayerData()
        .withGameResult(won: true, points: 10, stake: 5)
        .withGameResult(won: false, points: -4, stake: 5)
        .withGameResult(won: false, points: -9, stake: 10)
        .withGameResult(won: true, points: 12);

    expect(data.gamesAt(5), 2);
    expect(data.gamesAt(10), 1);
    expect(data.gamesAt(25), 0);
    expect(data.stats.roundsPlayed, 4);
  });

  test('adding coins keeps the games played at each stake', () {
    final data = const PlayerData().withGameResult(
      won: true,
      points: 10,
      stake: 5,
    );

    expect(data.withCoinsAdded(50).gamesAt(5), 1);
  });

  group('Hourly gift', () {
    const gift = HourlyGift(
      coins: 500,
      interval: Duration(hours: 1),
      gems: 1,
      gemEvery: 4,
    );
    final noon = DateTime(2026, 10, 17, 12);

    test('the first gift is ready straight away', () {
      expect(const PlayerData().giftWait(gift, noon), Duration.zero);
    });

    test('after collecting, the next is an interval away, counting from the '
        'collection', () {
      final data = const PlayerData().withGiftCollected(gift, noon);

      expect(data.giftWait(gift, noon), const Duration(hours: 1));
      expect(
        data.giftWait(gift, noon.add(const Duration(minutes: 20))),
        const Duration(minutes: 40),
      );
      expect(
        data.giftWait(gift, noon.add(const Duration(hours: 1))),
        Duration.zero,
      );
      expect(
        data.giftWait(gift, noon.add(const Duration(days: 3))),
        Duration.zero,
      );
    });

    test(
      'a clock turned back never makes the wait longer than one interval',
      () {
        final data = const PlayerData().withGiftCollected(gift, noon);

        expect(
          data.giftWait(gift, noon.subtract(const Duration(days: 1))),
          const Duration(hours: 1),
        );
      },
    );

    test('each collection pays the coins, and every 4th a gem', () {
      var data = const PlayerData(coins: 0);
      final gems = <int>[];
      for (var i = 0; i < 8; i++) {
        final before = data.gems;
        data = data.withGiftCollected(gift, noon.add(Duration(hours: i)));
        gems.add(data.gems - before);
      }

      expect(data.coins, 8 * 500);
      expect(gems, [0, 0, 0, 1, 0, 0, 0, 1]);
      expect(data.giftsCollected, 8);
      expect(data.giftCollectedAt, noon.add(const Duration(hours: 7)));
    });

    test('a gift that isn\'t ready can\'t be collected', () {
      final data = const PlayerData().withGiftCollected(gift, noon);

      expect(
        () =>
            data.withGiftCollected(gift, noon.add(const Duration(minutes: 59))),
        throwsStateError,
      );
    });

    test('collecting keeps everything else, and counts toward equality', () {
      const data = PlayerData(
        gems: 2,
        stats: PlayerStats(roundsPlayed: 1),
        gamesAtStake: {5: 1},
      );
      final collected = data.withGiftCollected(gift, noon);

      expect(collected.stats, data.stats);
      expect(collected.gamesAtStake, data.gamesAtStake);
      expect(collected.gems, 2);
      expect(collected, data.withGiftCollected(gift, noon));
      expect(collected.hashCode, data.withGiftCollected(gift, noon).hashCode);
      expect(collected, isNot(data.withGiftCollected(gift, DateTime(2027))));
      expect(
        PlayerData(giftCollectedAt: noon, giftsCollected: 1),
        isNot(PlayerData(giftCollectedAt: noon, giftsCollected: 2)),
      );
    });
  });

  group('Rewarded ads', () {
    const ad = RewardedAd(
      coins: 1000,
      perDay: 5,
      length: Duration(seconds: 30),
    );
    final morning = DateTime(2026, 10, 17, 9);

    test('the day is written as year, month and day', () {
      expect(PlayerData.dayOf(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('each ad pays its coins, up to 5 a day', () {
      var data = const PlayerData(coins: 0);
      expect(data.adsLeft(ad, morning), 5);
      for (var i = 0; i < 5; i++) {
        data = data.withAdReward(ad, morning.add(Duration(minutes: i)));
      }

      expect(data.coins, 5000);
      expect(data.adsLeft(ad, morning), 0);
      expect(() => data.withAdReward(ad, morning), throwsStateError);
    });

    test('the count starts again at midnight', () {
      var data = const PlayerData();
      for (var i = 0; i < 5; i++) {
        data = data.withAdReward(ad, morning);
      }
      final lateNight = DateTime(2026, 10, 17, 23, 59);
      final justAfter = DateTime(2026, 10, 18, 0, 1);

      expect(data.adsLeft(ad, lateNight), 0);
      expect(data.adsLeft(ad, justAfter), 5);
      final next = data.withAdReward(ad, justAfter);
      expect(next.adsWatched, 1);
      expect(next.adDay, '2026-10-18');
      expect(next.adsLeft(ad, justAfter), 4);
    });

    test('an ad keeps everything else, and counts toward equality', () {
      const data = PlayerData(gems: 4, giftsCollected: 2);
      final watched = data.withAdReward(ad, morning);

      expect(watched.gems, 4);
      expect(watched.giftsCollected, 2);
      expect(watched, data.withAdReward(ad, morning));
      expect(watched, isNot(watched.withAdReward(ad, morning)));
    });

    test('an ad in place of an entry fee counts toward the limit, unpaid', () {
      var data = const PlayerData(coins: 0, gems: 0);
      data = data.withAdWatched(ad, morning).withAdReward(ad, morning);

      expect(data.coins, 1000);
      expect(data.gems, 0);
      expect(data.adsLeft(ad, morning), 3);
      for (var i = 0; i < 3; i++) {
        data = data.withAdWatched(ad, morning);
      }
      expect(() => data.withAdWatched(ad, morning), throwsStateError);
    });
  });
}
