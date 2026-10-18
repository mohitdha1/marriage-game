import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/local_player_data_repository.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/ui/settings/preferences.dart';

void main() {
  test('a new device loads a new player', () async {
    final repository = LocalPlayerDataRepository(InMemoryPreferences());

    expect(await repository.load(), const PlayerData());
  });

  test('starting gems are given once, and never again', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);

    expect((await repository.giveStartingGems(3)).gems, 3);
    await repository.addGems(-3);
    expect((await repository.giveStartingGems(3)).gems, 0);
    expect(
      (await LocalPlayerDataRepository(store).giveStartingGems(3)).gems,
      0,
      reason: 'given on an earlier launch',
    );
  });

  test('starting gems add to gems earned before they arrived', () async {
    final repository = LocalPlayerDataRepository(InMemoryPreferences());
    await repository.addGems(2);

    expect((await repository.giveStartingGems(3)).gems, 5);
  });

  test('gems added are saved, and the new balance returned', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);

    expect((await repository.addGems(5)).gems, 5);
    expect((await repository.addGems(-2)).gems, 3);
    expect((await LocalPlayerDataRepository(store).load()).gems, 3);
  });

  test('what was saved is loaded on the next launch', () async {
    final store = InMemoryPreferences();
    const data = PlayerData(
      coins: 2400,
      gems: 12,
      stats: PlayerStats(roundsPlayed: 9, roundsWon: 4, bestRound: 57),
    );
    await LocalPlayerDataRepository(store).save(data);

    expect(await LocalPlayerDataRepository(store).load(), data);
  });

  test('coins added are saved, and the new balance returned', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);

    const start = PlayerData.startingCoins;
    expect((await repository.addCoins(59)).coins, start + 59);
    expect((await repository.addCoins(-9)).coins, start + 50);
    expect((await LocalPlayerDataRepository(store).load()).coins, start + 50);
  });

  test('a game result is saved, and the new stats returned', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);

    await repository.recordGameResult(won: false, points: -5);
    final returned = await repository.recordGameResult(won: true, points: 31);

    expect(returned.stats.roundsPlayed, 2);
    expect(await LocalPlayerDataRepository(store).load(), returned);
  });

  test('changes made without waiting for each other are all kept', () async {
    final repository = LocalPlayerDataRepository(InMemoryPreferences());

    await Future.wait([
      repository.addCoins(40),
      repository.recordGameResult(won: true, points: 40),
      repository.addCoins(-10),
    ]);

    final data = await repository.load();
    expect(data.coins, PlayerData.startingCoins + 30);
    expect(data.stats.roundsWon, 1);
  });

  test('coins and stats saved before gems existed still load, '
      'and get the starting gems', () async {
    final store = InMemoryPreferences({
      'coins.balance': 12345,
      'stats.roundsPlayed': 3,
      'stats.roundsWon': 1,
      'stats.bestRound': 31,
    });

    final repository = LocalPlayerDataRepository(store);
    const before = PlayerData(
      coins: 12345,
      stats: PlayerStats(roundsPlayed: 3, roundsWon: 1, bestRound: 31),
    );
    expect(await repository.load(), before);
    // A player from before gems existed gets the starting gems too.
    expect(await repository.giveStartingGems(3), before.withGemsAdded(3));
  });

  test('games at each stake are saved for the next launch', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);
    for (var i = 0; i < 3; i++) {
      await repository.recordGameResult(won: false, points: -5, stake: 5);
    }
    await repository.recordGameResult(won: true, points: 20, stake: 10);

    final loaded = await LocalPlayerDataRepository(store).load();
    expect(loaded.gamesAtStake, {5: 3, 10: 1});
  });

  group('Hourly gift', () {
    const gift = HourlyGift(
      coins: 500,
      interval: Duration(hours: 1),
      gems: 1,
      gemEvery: 4,
    );
    final noon = DateTime(2026, 10, 17, 12);

    test('a collection is saved, so the wait carries on after the app is '
        'closed', () async {
      final store = InMemoryPreferences();
      final collected = await LocalPlayerDataRepository(
        store,
      ).collectGift(gift, noon);
      expect(collected.coins, PlayerData.startingCoins + 500);

      // The app is opened again 45 minutes later: 15 to go.
      final reopened = await LocalPlayerDataRepository(store).load();
      expect(reopened, collected);
      expect(
        reopened.giftWait(gift, noon.add(const Duration(minutes: 45))),
        const Duration(minutes: 15),
      );
    });

    test('a gift that isn\'t ready changes nothing', () async {
      final store = InMemoryPreferences();
      final repository = LocalPlayerDataRepository(store);
      final first = await repository.collectGift(gift, noon);

      await expectLater(
        repository.collectGift(gift, noon.add(const Duration(minutes: 5))),
        throwsStateError,
      );
      expect(await LocalPlayerDataRepository(store).load(), first);
    });

    test('the count of collections is kept, for the gem every 4th', () async {
      final repository = LocalPlayerDataRepository(InMemoryPreferences());
      for (var i = 0; i < 3; i++) {
        await repository.collectGift(gift, noon.add(Duration(hours: i)));
      }
      final fourth = await repository.collectGift(
        gift,
        noon.add(const Duration(hours: 3)),
      );

      expect(fourth.giftsCollected, 4);
      expect(fourth.gems, 1);
    });
  });
}
