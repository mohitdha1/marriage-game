import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';

/// The game's sound effects, each with its file in `assets/sounds/`.
enum Sfx {
  shuffle('shuffle.wav'),
  cardSnap('card_snap.wav'),
  select('select.wav'),
  win('win.wav'),
  roundOver('round_over.wav'),
  yourTurn('your_turn.wav');

  const Sfx(this.file);

  final String file;
}

/// Plays sound effects. An interface so tests can swap in a silent or
/// recording version instead of real audio.
abstract interface class SoundEffects {
  void play(Sfx sound);

  Future<void> dispose();
}

/// Plays nothing; for tests and any place sound must stay off.
class SilentSoundEffects implements SoundEffects {
  const SilentSoundEffects();

  @override
  void play(Sfx sound) {}

  @override
  Future<void> dispose() async {}
}

/// Passes sounds on to [inner] only while [isOn] says sound is switched on,
/// so the Settings toggle silences the game straight away.
class GatedSoundEffects implements SoundEffects {
  GatedSoundEffects(this.inner, {required this.isOn});

  final SoundEffects inner;
  final bool Function() isOn;

  @override
  void play(Sfx sound) {
    if (isOn()) inner.play(sound);
  }

  @override
  Future<void> dispose() => inner.dispose();
}

/// How the game's sounds share the device's audio with other apps.
///
/// Sound effects shouldn't interrupt anything: on Android they never ask
/// for audio focus, so music or a podcast keeps playing underneath; on iOS
/// the "ambient" category mixes with other audio and stays quiet when the
/// silent switch is on.
AudioContext soundEffectsAudioContext() => AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.game,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);

/// Real audio through the audioplayers package: one low-latency player per
/// sound, so a sound restarts if it's played again before it finishes.
class AudioPlayerSoundEffects implements SoundEffects {
  final _players = <Sfx, Future<AudioPlayer>>{};

  @override
  void play(Sfx sound) {
    // A sound that fails to play is not worth interrupting the game for.
    unawaited(
      _playerFor(sound)
          .then((player) => player.play(AssetSource('sounds/${sound.file}')))
          .catchError((Object e) => debugPrint('Could not play $sound: $e')),
    );
  }

  /// The player for [sound], set up once with [soundEffectsAudioContext]
  /// before it plays anything.
  Future<AudioPlayer> _playerFor(Sfx sound) => _players[sound] ??= () async {
    final player = AudioPlayer();
    await player.setAudioContext(soundEffectsAudioContext());
    await player.setPlayerMode(PlayerMode.lowLatency);
    return player;
  }();

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await (await player).dispose();
    }
    _players.clear();
  }
}

/// The app's sound effects. Tests override this with [SilentSoundEffects].
final soundEffectsProvider = Provider<SoundEffects>((ref) {
  final sounds = GatedSoundEffects(
    AudioPlayerSoundEffects(),
    isOn: () => ref.read(settingsProvider).sound,
  );
  ref.onDispose(sounds.dispose);
  return sounds;
});
