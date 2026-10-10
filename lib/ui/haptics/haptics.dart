import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';

/// The moments the game vibrates for.
enum Buzz {
  /// A single gentle tap: another player's move made it the player's turn.
  yourTurn,

  /// Two firm taps: the player won the round.
  win,
}

/// Vibrates the device. An interface so tests can swap in a silent or
/// recording version instead of the real thing.
abstract interface class Haptics {
  void buzz(Buzz kind);
}

/// Does nothing; for tests and any place vibration must stay off.
class SilentHaptics implements Haptics {
  const SilentHaptics();

  @override
  void buzz(Buzz kind) {}
}

/// Passes buzzes on to [inner] only while [isOn] says vibration is switched
/// on, so the Settings toggle stops it straight away.
class GatedHaptics implements Haptics {
  GatedHaptics(this.inner, {required this.isOn});

  final Haptics inner;
  final bool Function() isOn;

  @override
  void buzz(Buzz kind) {
    if (isOn()) inner.buzz(kind);
  }
}

/// The device's own haptic feedback, which also follows the phone's system
/// setting for touch vibration.
class DeviceHaptics implements Haptics {
  const DeviceHaptics();

  /// The pause between the two taps of a [Buzz.win].
  static const winGap = Duration(milliseconds: 140);

  @override
  void buzz(Buzz kind) {
    switch (kind) {
      case Buzz.yourTurn:
        unawaited(HapticFeedback.lightImpact());
      case Buzz.win:
        unawaited(HapticFeedback.heavyImpact());
        unawaited(Future.delayed(winGap, HapticFeedback.heavyImpact));
    }
  }
}

/// The app's haptics, silenced by the Vibration setting. Tests override
/// this with [SilentHaptics].
final hapticsProvider = Provider<Haptics>(
  (ref) => GatedHaptics(
    const DeviceHaptics(),
    isOn: () => ref.read(settingsProvider).vibration,
  ),
);
