import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/home/coins.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';

ProviderContainer containerWith(InMemoryPreferences store) {
  final container = ProviderContainer(
    overrides: [preferencesProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

class RecordingSoundEffects implements SoundEffects {
  final played = <Sfx>[];

  @override
  void play(Sfx sound) => played.add(sound);

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Settings', () {
    test('everything is on by default, with a default name', () {
      final settings = containerWith(
        InMemoryPreferences(),
      ).read(settingsProvider);

      expect(settings.sound, isTrue);
      expect(settings.vibration, isTrue);
      expect(settings.handHelper, isTrue);
      expect(settings.playerName, 'Player');
      expect(settings.avatarColor, Settings.avatarColors.first);
    });

    test('changes are saved and read back on the next launch', () {
      final store = InMemoryPreferences();
      containerWith(store).read(settingsProvider.notifier)
        ..setSound(false)
        ..setVibration(false)
        ..setHandHelper(false)
        ..setPlayerName('  Mohit ')
        ..setAvatarColor(Settings.avatarColors[3]);

      final reloaded = containerWith(store).read(settingsProvider);

      expect(reloaded.sound, isFalse);
      expect(reloaded.vibration, isFalse);
      expect(reloaded.handHelper, isFalse);
      expect(reloaded.playerName, 'Mohit');
      expect(reloaded.avatarColor, Settings.avatarColors[3]);
    });

    test('a blank name falls back to the default', () {
      final container = containerWith(InMemoryPreferences());
      container.read(settingsProvider.notifier).setPlayerName('   ');

      expect(container.read(settingsProvider).playerName, 'Player');
    });
  });

  group('Coins', () {
    test('a new player starts with 1,000', () {
      expect(containerWith(InMemoryPreferences()).read(coinsProvider), 1000);
    });

    test('round results add or take away coins, and are saved', () {
      final store = InMemoryPreferences();
      containerWith(store).read(coinsProvider.notifier)
        ..addRoundResult(59)
        ..addRoundResult(-9);

      expect(containerWith(store).read(coinsProvider), 1050);
    });

    test('the balance never goes below zero', () {
      final container = containerWith(
        InMemoryPreferences({'coins.balance': 20}),
      );
      container.read(coinsProvider.notifier).addRoundResult(-50);

      expect(container.read(coinsProvider), 0);
    });
  });

  group('GatedSoundEffects', () {
    test('plays only while sound is switched on', () {
      final inner = RecordingSoundEffects();
      var on = true;
      final gated = GatedSoundEffects(inner, isOn: () => on);

      gated.play(Sfx.select);
      on = false;
      gated.play(Sfx.cardSnap);
      on = true;
      gated.play(Sfx.win);

      expect(inner.played, [Sfx.select, Sfx.win]);
    });
  });
}
