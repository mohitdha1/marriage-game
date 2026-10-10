import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_player.dart';
import '../theme/table_theme.dart';
import 'preferences.dart';

/// The player's preferences and profile.
class Settings {
  const Settings({
    this.sound = true,
    this.vibration = true,
    this.handHelper = true,
    this.playerName = defaultName,
    this.avatarColor = 0xFF90CAF9, // the first of [avatarColors]
    this.tableTheme = TableThemeId.classic,
    this.playerCount = 5,
    this.botDifficulty = BotDifficulty.medium,
  });

  /// The fewest and most players at a table, the human player included.
  static const minPlayers = 2;
  static const maxPlayers = 5;

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

  /// Whether the game may vibrate: on the player's turn and when they win.
  final bool vibration;

  /// Whether the table shows the hand helper badge: progress toward showing
  /// sets, and later toward winning.
  final bool handHelper;

  final String playerName;

  /// The player's avatar background, as 0xAARRGGBB.
  final int avatarColor;

  /// The look of the table and the cards' backs.
  final TableThemeId tableTheme;

  /// How many play in a game against bots, the human player included.
  final int playerCount;

  /// How well the bots play.
  final BotDifficulty botDifficulty;

  Settings copyWith({
    bool? sound,
    bool? vibration,
    bool? handHelper,
    String? playerName,
    int? avatarColor,
    TableThemeId? tableTheme,
    int? playerCount,
    BotDifficulty? botDifficulty,
  }) => Settings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    handHelper: handHelper ?? this.handHelper,
    playerName: playerName ?? this.playerName,
    avatarColor: avatarColor ?? this.avatarColor,
    tableTheme: tableTheme ?? this.tableTheme,
    playerCount: playerCount ?? this.playerCount,
    botDifficulty: botDifficulty ?? this.botDifficulty,
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
  static const _tableTheme = 'settings.tableTheme';
  static const _playerCount = 'lobby.playerCount';
  static const _botDifficulty = 'lobby.botDifficulty';

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
      // Saved by name; a name that's no longer a theme falls back to the
      // default.
      tableTheme:
          TableThemeId.values.asNameMap()[store.getString(_tableTheme)] ??
          defaults.tableTheme,
      playerCount: (store.getInt(_playerCount) ?? defaults.playerCount).clamp(
        Settings.minPlayers,
        Settings.maxPlayers,
      ),
      botDifficulty:
          BotDifficulty.values.asNameMap()[store.getString(_botDifficulty)] ??
          defaults.botDifficulty,
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

  void setTableTheme(TableThemeId theme) {
    state = state.copyWith(tableTheme: theme);
    _store.setString(_tableTheme, theme.name);
  }

  /// Sets how many play against bots, kept between [Settings.minPlayers]
  /// and [Settings.maxPlayers].
  void setPlayerCount(int count) {
    final kept = count.clamp(Settings.minPlayers, Settings.maxPlayers);
    state = state.copyWith(playerCount: kept);
    _store.setInt(_playerCount, kept);
  }

  void setBotDifficulty(BotDifficulty difficulty) {
    state = state.copyWith(botDifficulty: difficulty);
    _store.setString(_botDifficulty, difficulty.name);
  }
}
