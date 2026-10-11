import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/local_player_data_repository.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/ui/settings/preferences.dart';

void main() {
  test('a new device loads a new player', () async {
    final repository = LocalPlayerDataRepository(InMemoryPreferences());

    expect(await repository.load(), const PlayerData());
  });

  test('what was saved is loaded on the next launch', () async {
    final store = InMemoryPreferences();
    const data = PlayerData(
      coins: 2400,
      stats: PlayerStats(roundsPlayed: 9, roundsWon: 4, bestRound: 57),
    );
    await LocalPlayerDataRepository(store).save(data);

    expect(await LocalPlayerDataRepository(store).load(), data);
  });

  test('coins added are saved, and the new balance returned', () async {
    final store = InMemoryPreferences();
    final repository = LocalPlayerDataRepository(store);

    expect((await repository.addCoins(59)).coins, 1059);
    expect((await repository.addCoins(-9)).coins, 1050);
    expect((await LocalPlayerDataRepository(store).load()).coins, 1050);
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
    expect(data.coins, 1030);
    expect(data.stats.roundsWon, 1);
  });

  test(
    'coins and stats saved by earlier versions of the app still load',
    () async {
      final store = InMemoryPreferences({
        'coins.balance': 12345,
        'stats.roundsPlayed': 3,
        'stats.roundsWon': 1,
        'stats.bestRound': 31,
      });

      expect(
        await LocalPlayerDataRepository(store).load(),
        const PlayerData(
          coins: 12345,
          stats: PlayerStats(roundsPlayed: 3, roundsWon: 1, bestRound: 31),
        ),
      );
    },
  );
}
