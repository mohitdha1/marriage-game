import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/data/player_data_repository.dart';
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
  Future<PlayerData> recordGameResult({
    required bool won,
    required int points,
  }) async {
    calls.add('recordGameResult $won $points');
    return data = data.withGameResult(won: won, points: points);
  }
}

ProviderContainer containerWith(PlayerDataRepository repository) {
  final container = ProviderContainer(
    overrides: [playerDataRepositoryProvider.overrideWithValue(repository)],
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
    expect(container.read(playerDataProvider).value?.coins, 1010);
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

  test('on the device by default, saved between launches', () async {
    final store = InMemoryPreferences();
    final first = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);
    await first.read(playerDataProvider.future);
    await first.read(playerDataProvider.notifier).addCoins(50);

    final next = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(store)],
    );
    addTearDown(next.dispose);
    expect((await next.read(playerDataProvider.future)).coins, 1050);
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
