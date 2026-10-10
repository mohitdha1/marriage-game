import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

/// The player's preferences and profile.
class Settings {
  const Settings({
    this.sound = true,
    this.vibration = true,
    this.handHelper = true,
    this.playerName = defaultName,
    this.avatarColor = 0xFF90CAF9, // the first of [avatarColors]
  });

  static const defaultName = 'Player';

  /// The avatar colours a player can pick from, as 0xAARRGGBB.
  static const avatarColors = [
    0xFF90CAF9,
    0xFFA5D6A7,
    0xFFFFCC80,
    0xFFCE93D8,
    0xFFEF9A9A,
    0xFF80CBC4,
  ];

  /// Whether the game plays sound effects.
  final bool sound;

  /// Whether the game may vibrate. Saved now; haptics arrive in Phase 3.
  final bool vibration;

  /// Whether the table shows the hand helper badge: progress toward showing
  /// sets, and later toward winning.
  final bool handHelper;

  final String playerName;

  /// The player's avatar background, as 0xAARRGGBB.
  final int avatarColor;

  Settings copyWith({
    bool? sound,
    bool? vibration,
    bool? handHelper,
    String? playerName,
    int? avatarColor,
  }) => Settings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    handHelper: handHelper ?? this.handHelper,
    playerName: playerName ?? this.playerName,
    avatarColor: avatarColor ?? this.avatarColor,
  );
}

/// The player's preferences and profile, saved between launches.
final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  static const _sound = 'settings.sound';
  static const _vibration = 'settings.vibration';
  static const _handHelper = 'settings.handHelper';
  static const _playerName = 'profile.name';
  static const _avatarColor = 'profile.avatarColor';

  PreferencesStore get _store => ref.read(preferencesProvider);

  @override
  Settings build() {
    final store = ref.watch(preferencesProvider);
    const defaults = Settings();
    return Settings(
      sound: store.getBool(_sound) ?? defaults.sound,
      vibration: store.getBool(_vibration) ?? defaults.vibration,
      handHelper: store.getBool(_handHelper) ?? defaults.handHelper,
      playerName: store.getString(_playerName) ?? defaults.playerName,
      avatarColor: store.getInt(_avatarColor) ?? defaults.avatarColor,
    );
  }

  void setSound(bool on) {
    state = state.copyWith(sound: on);
    _store.setBool(_sound, on);
  }

  void setVibration(bool on) {
    state = state.copyWith(vibration: on);
    _store.setBool(_vibration, on);
  }

  void setHandHelper(bool on) {
    state = state.copyWith(handHelper: on);
    _store.setBool(_handHelper, on);
  }

  /// Changes the player's name; blank names fall back to the default.
  void setPlayerName(String name) {
    final trimmed = name.trim();
    final chosen = trimmed.isEmpty ? Settings.defaultName : trimmed;
    state = state.copyWith(playerName: chosen);
    _store.setString(_playerName, chosen);
  }

  void setAvatarColor(int color) {
    state = state.copyWith(avatarColor: color);
    _store.setInt(_avatarColor, color);
  }
}
