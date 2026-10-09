import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The game's sound effects, each with its file in `assets/sounds/`.
enum Sfx {
  shuffle('shuffle.wav'),
  cardSnap('card_snap.wav'),
  select('select.wav'),
  win('win.wav'),
  roundOver('round_over.wav');

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

/// Real audio through the audioplayers package: one low-latency player per
/// sound, so a sound restarts if it's played again before it finishes.
class AudioPlayerSoundEffects implements SoundEffects {
  final _players = <Sfx, AudioPlayer>{};

  @override
  void play(Sfx sound) {
    final player = _players.putIfAbsent(
      sound,
      () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
    );
    // A sound that fails to play is not worth interrupting the game for.
    unawaited(
      player
          .play(AssetSource('sounds/${sound.file}'))
          .catchError((Object e) => debugPrint('Could not play $sound: $e')),
    );
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// The app's sound effects. Tests override this with [SilentSoundEffects].
final soundEffectsProvider = Provider<SoundEffects>((ref) {
  final sounds = AudioPlayerSoundEffects();
  ref.onDispose(sounds.dispose);
  return sounds;
});
