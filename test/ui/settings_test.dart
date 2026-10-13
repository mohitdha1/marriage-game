import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/house_rules.dart';

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
      expect(settings.rules, const HouseRules());
      expect(settings.playerName, 'Player');
      expect(settings.avatarColor, Settings.avatarColors.first);
    });

    test('changes are saved and read back on the next launch', () {
      final store = InMemoryPreferences();
      containerWith(store).read(settingsProvider.notifier)
        ..setSound(false)
        ..setVibration(false)
        ..setHandHelper(false)
        ..setMode(GameMode.kidnap)
        ..setManCards(true)
        ..setSuperman(true)
        ..setAlterIsMaal(false)
        ..setJokerPenalty(false)
        ..setPlayerName('  Mohit ')
        ..setAvatarColor(Settings.avatarColors[3]);

      final reloaded = containerWith(store).read(settingsProvider);

      expect(reloaded.sound, isFalse);
      expect(reloaded.vibration, isFalse);
      expect(reloaded.handHelper, isFalse);
      expect(
        reloaded.rules,
        const HouseRules(
          mode: GameMode.kidnap,
          manCards: true,
          superman: true,
          alterIsMaal: false,
          jokerPenalty: false,
        ),
      );
      expect(reloaded.playerName, 'Mohit');
      expect(reloaded.avatarColor, Settings.avatarColors[3]);
    });

    test('a blank name falls back to the default', () {
      final container = containerWith(InMemoryPreferences());
      container.read(settingsProvider.notifier).setPlayerName('   ');

      expect(container.read(settingsProvider).playerName, 'Player');
    });
  });

  group('HouseRules', () {
    test('defaults to Standard with only the usual rules', () {
      final config = const HouseRules().configFor(4);

      expect(config.playerCount, 4);
      expect(config.mode, GameMode.standard);
      expect(config.manCardsEnabled, isFalse);
      expect(config.supermanCardEnabled, isFalse);
      expect(config.alterIsMaal, isTrue);
      expect(config.jokerDiscardPenaltyEnabled, isTrue);
    });

    test('carries every rule into the game\'s settings', () {
      final config = const HouseRules(
        mode: GameMode.murder,
        manCards: true,
        superman: true,
        alterIsMaal: false,
        jokerPenalty: false,
      ).configFor(5);

      expect(config.mode, GameMode.murder);
      expect(config.manCardsEnabled, isTrue);
      expect(config.supermanCardEnabled, isTrue);
      expect(config.alterIsMaal, isFalse);
      expect(config.jokerDiscardPenaltyEnabled, isFalse);
    });

    test('rules are equal when every rule matches', () {
      expect(const HouseRules(), const HouseRules());
      expect(
        const HouseRules().copyWith(superman: true),
        const HouseRules(superman: true),
      );
      expect(const HouseRules(), isNot(const HouseRules(manCards: true)));
      expect(
        const HouseRules(superman: true).hashCode,
        const HouseRules(superman: true).hashCode,
      );
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
