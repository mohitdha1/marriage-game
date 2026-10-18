import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/data/player_data_repository.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/profile_dialog.dart';

/// A repository that keeps the data in memory and records what it's asked,
/// standing in for any other place the data could live.
class RecordingRepository implements PlayerDataRepository {
  RecordingRepository([this.data = const PlayerData()]);

  PlayerData data;
  final calls = <String>[];

  /// Holds back the load until completed, when set.
  Completer<void>? loadGate;

  @override
  Future<PlayerData> load() async {
    calls.add('load');
    await loadGate?.future;
    return data;
  }

  @override
  Future<void> save(PlayerData data) async {
    calls.add('save');
    this.data = data;
  }

  @override
  Future<PlayerData> addCoins(int amount) async {
    calls.add('addCoins $amount');
    return data = data.withCoinsAdded(amount);
  }

  @override
  Future<PlayerData> addGems(int amount) async {
    calls.add('addGems $amount');
    return data = data.withGemsAdded(amount);
  }

  @override
  Future<PlayerData> claimAdReward(RewardedAd ad, DateTime now) async {
    calls.add('claimAdReward');
    return data = data.withAdReward(ad, now);
  }

  @override
  Future<PlayerData> spendGems(int amount) async {
    calls.add('spendGems $amount');
    return data = data.withGemsSpent(amount);
  }

  @override
  Future<PlayerData> claimAdEntry(RewardedAd ad, DateTime now) async {
    calls.add('claimAdEntry');
    return data = data.withAdWatched(ad, now);
  }

  @override
  Future<PlayerData> collectGift(HourlyGift gift, DateTime now) async {
    calls.add('collectGift');
    return data = data.withGiftCollected(gift, now);
  }

  var startingGemsGiven = false;

  @override
  Future<PlayerData> giveStartingGems(int gems) async {
    calls.add('giveStartingGems $gems');
    if (startingGemsGiven) return data;
    startingGemsGiven = true;
    return data = data.withGemsAdded(gems);
  }

  @override
  Future<PlayerData> recordGameResult({
    required bool won,
    required int points,
    int? stake,
  }) async {
    calls.add(
      'recordGameResult $won $points${stake == null ? '' : ' at $stake'}',
    );
    return data = data.withGameResult(won: won, points: points, stake: stake);
  }
}

const testEconomy = EconomyConfig(
  startingGems: 3,
  hourlyGift: HourlyGift(
    coins: 500,
    interval: Duration(hours: 1),
    gems: 1,
    gemEvery: 4,
  ),
  rewardedAd: RewardedAd(coins: 1000, perDay: 2, length: Duration(seconds: 30)),
  entryFee: EntryFee(gems: 1, aboveStake: 100),
);

/// A container using [repository]. The economy's amounts arrive when
/// [economy] completes, or never, so the starting gems stay out of the way.
ProviderContainer containerWith(
  PlayerDataRepository repository, {
  Future<EconomyConfig>? economy,
  DateTime Function()? clock,
}) {
  final container = ProviderContainer(
    overrides: [
      if (clock != null) clockProvider.overrideWithValue(clock),
      playerDataRepositoryProvider.overrideWithValue(repository),
      economyConfigProvider.overrideWith(
        (ref) => economy ?? Completer<EconomyConfig>().future,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the data comes from the repository', () async {
    final repository = RecordingRepository(const PlayerData(coins: 777));

    final data = await containerWith(
      repository,
    ).read(playerDataProvider.future);

    expect(data.coins, 777);
    expect(repository.calls, ['load']);
  });

  test('changes go through the repository and show what it returns', () async {
    final repository = RecordingRepository();
    final container = containerWith(repository);
    await container.read(playerDataProvider.future);

    final controller = container.read(playerDataProvider.notifier);
    await controller.addCoins(25);
    await controller.recordGameResult(won: true, points: 25);

    expect(repository.calls, [
      'load',
      'addCoins 25',
      'recordGameResult true 25',
    ]);
    expect(container.read(playerDataProvider).value, repository.data);
  });

  test('a change asked for while loading waits for the load', () async {
    final repository = RecordingRepository()..loadGate = Completer();
    final container = containerWith(repository);
    container.read(playerDataProvider);

    final adding = container.read(playerDataProvider.notifier).addCoins(10);
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, ['load']);

    repository.loadGate!.complete();
    await adding;
    expect(repository.calls, ['load', 'addCoins 10']);
    expect(
      container.read(playerDataProvider).value?.coins,
      PlayerData.startingCoins + 10,
    );
  });

  test('changes asked for together are made in order', () async {
    final repository = RecordingRepository();
    final container = containerWith(repository);
    await container.read(playerDataProvider.future);
    final controller = container.read(playerDataProvider.notifier);

    await Future.wait([
      controller.addCoins(5),
      controller.recordGameResult(won: false, points: -5),
      controller.addCoins(-5),
    ]);

    expect(repository.calls.skip(1), [
      'addCoins 5',
      'recordGameResult false -5',
      'addCoins -5',
    ]);
    expect(container.read(playerDataProvider).value, repository.data);
  });

  test('gems change through the repository too', () async {
    final repository = RecordingRepository();
    final container = containerWith(repository);
    await container.read(playerDataProvider.future);

    await container.read(playerDataProvider.notifier).addGems(2);

    expect(repository.calls, ['load', 'addGems 2']);
    expect(container.read(playerDataProvider).value?.gems, 2);
  });

  test("a new player's gems follow the economy's amounts, without the data "
      'waiting for them', () async {
    final economy = Completer<EconomyConfig>();
    final repository = RecordingRepository();
    final container = containerWith(repository, economy: economy.future);

    expect((await container.read(playerDataProvider.future)).gems, 0);

    economy.complete(testEconomy);
    await pumpEventQueue();
    expect(repository.calls, ['load', 'giveStartingGems 3']);
    expect(container.read(playerDataProvider).value?.gems, 3);
  });

  group('The hourly gift', () {
    test('is collected through the repository, at the clock\'s time, and '
        'says what it gave', () async {
      var now = DateTime(2026, 10, 17, 12);
      final repository = RecordingRepository();
      final container = containerWith(
        repository,
        economy: Future.value(testEconomy),
        clock: () => now,
      );
      await container.read(playerDataProvider.future);
      await container.read(economyConfigProvider.future);
      await pumpEventQueue();
      final controller = container.read(playerDataProvider.notifier);

      expect(await controller.collectGift(), (coins: 500, gems: 0));
      expect(repository.data.giftCollectedAt, now);
      expect(container.read(playerDataProvider).value, repository.data);

      // Not again until an hour has passed.
      now = now.add(const Duration(minutes: 59));
      expect(await controller.collectGift(), isNull);
      expect(repository.calls.where((c) => c == 'collectGift'), hasLength(1));

      now = now.add(const Duration(minutes: 1));
      expect(await controller.collectGift(), (coins: 500, gems: 0));
    });

    test('nothing is collected before the economy has loaded', () async {
      final repository = RecordingRepository();
      final container = containerWith(repository);
      await container.read(playerDataProvider.future);

      expect(
        await container.read(playerDataProvider.notifier).collectGift(),
        isNull,
      );
      expect(repository.calls, isNot(contains('collectGift')));
    });
  });

  test('rewarded ads pay through the repository, until the day\'s are '
      'used up', () async {
    final repository = RecordingRepository();
    final container = containerWith(
      repository,
      economy: Future.value(testEconomy),
      clock: () => DateTime(2026, 10, 17, 9),
    );
    await container.read(playerDataProvider.future);
    await container.read(economyConfigProvider.future);
    await pumpEventQueue();
    final controller = container.read(playerDataProvider.notifier);

    expect(controller.adsLeftToday(), 2);
    expect(await controller.claimAdReward(), 1000);
    expect(await controller.claimAdReward(), 1000);
    expect(controller.adsLeftToday(), 0);
    expect(await controller.claimAdReward(), isNull);
    expect(repository.calls.where((c) => c == 'claimAdReward'), hasLength(2));
  });

  group('The entry fee', () {
    Future<(RecordingRepository, PlayerDataController)> ready(
      PlayerData data,
    ) async {
      final repository = RecordingRepository(data)..startingGemsGiven = true;
      final container = containerWith(
        repository,
        economy: Future.value(testEconomy),
        clock: () => DateTime(2026, 10, 17, 9),
      );
      await container.read(playerDataProvider.future);
      await container.read(economyConfigProvider.future);
      await pumpEventQueue();
      return (repository, container.read(playerDataProvider.notifier));
    }

    test('is a gem above the 100 table, and nothing at or below it, or off '
        'a stake table', () async {
      final (repository, controller) = await ready(const PlayerData(gems: 2));

      expect(controller.entryFeeFor(250), 1);
      expect(await controller.payEntryFee(100), isTrue);
      expect(await controller.payEntryFee(null), isTrue);
      expect(repository.data.gems, 2, reason: 'free tables cost nothing');
      expect(await controller.payEntryFee(250), isTrue);
      expect(repository.data.gems, 1);
      expect(repository.calls, contains('spendGems 1'));
    });

    test(
      'without the gems, nothing is spent and the match is refused',
      () async {
        final (repository, controller) = await ready(const PlayerData(gems: 1));

        expect(await controller.payEntryFee(500), isTrue);
        expect(await controller.payEntryFee(500), isFalse);
        expect(repository.data.gems, 0);
        expect(repository.calls.where((c) => c.startsWith('spendGems')), [
          'spendGems 1',
        ]);
      },
    );

    test('an ad can stand in for it, within the day\'s ads', () async {
      final (repository, controller) = await ready(const PlayerData(gems: 0));

      expect(await controller.claimAdEntry(), isTrue);
      expect(await controller.claimAdEntry(), isTrue);
      expect(await controller.claimAdEntry(), isFalse);
      expect(repository.data.coins, PlayerData.startingCoins);
      expect(controller.adsLeftToday(), 0);
    });

    test('is free before the economy has loaded', () async {
      final repository = RecordingRepository(const PlayerData(gems: 0));
      final container = containerWith(repository);
      await container.read(playerDataProvider.future);

      expect(
        await container.read(playerDataProvider.notifier).payEntryFee(250),
        isTrue,
      );
    });
  });

  group('on the device by default', () {
    ProviderContainer onDevice(InMemoryPreferences store) {
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(store),
          economyConfigProvider.overrideWith((ref) => testEconomy),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('saved between launches, starting gems given only once', () async {
      final store = InMemoryPreferences();
      final first = onDevice(store);
      await first.read(playerDataProvider.future);
      await pumpEventQueue();
      expect(first.read(playerDataProvider).value?.gems, 3);
      await first.read(playerDataProvider.notifier).addCoins(50);
      await first.read(playerDataProvider.notifier).addGems(-1);

      final next = onDevice(store);
      await next.read(playerDataProvider.future);
      await pumpEventQueue();
      final data = next.read(playerDataProvider).requireValue;
      expect(data.coins, PlayerData.startingCoins + 50);
      expect(data.gems, 2);
    });
  });

  group('describeStats', () {
    test('before the first round', () {
      expect(
        describeStats(const PlayerStats()),
        'Your record starts with your first round.',
      );
    });

    test('rounds, wins with their share, and the best round', () {
      expect(
        describeStats(
          const PlayerStats(roundsPlayed: 3, roundsWon: 1, bestRound: 31),
        ),
        'Rounds 3 · Won 1 (33%) · Best +31',
      );
    });
  });
}
