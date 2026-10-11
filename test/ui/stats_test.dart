import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/home/stats.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/profile_dialog.dart';

ProviderContainer containerWith(InMemoryPreferences store) {
  final container = ProviderContainer(
    overrides: [preferencesProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a new player has no record yet', () {
    final stats = containerWith(InMemoryPreferences()).read(statsProvider);

    expect(stats.roundsPlayed, 0);
    expect(stats.winRate, 0);
    expect(stats.bestRound, isNull);
    expect(describeStats(stats), 'Your record starts with your first round.');
  });

  test('rounds are counted, the best kept, and saved for next launch', () {
    final store = InMemoryPreferences();
    containerWith(store).read(statsProvider.notifier)
      ..recordRound(won: false, points: -5)
      ..recordRound(won: true, points: 31)
      ..recordRound(won: false, points: -12);

    final stats = containerWith(store).read(statsProvider);
    expect(stats.roundsPlayed, 3);
    expect(stats.roundsWon, 1);
    expect(stats.bestRound, 31);
    expect(describeStats(stats), 'Rounds 3 · Won 1 (33%) · Best +31');
  });

  test('a first round lost is still the best so far', () {
    final container = containerWith(InMemoryPreferences());
    container.read(statsProvider.notifier).recordRound(won: false, points: -8);

    expect(container.read(statsProvider).bestRound, -8);
  });
}
