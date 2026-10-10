import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The player's preferences.
class Settings {
  const Settings({this.handHelper = true});

  /// Whether the table shows the hand helper badge: progress toward showing
  /// sets, and later toward winning.
  final bool handHelper;

  Settings copyWith({bool? handHelper}) =>
      Settings(handHelper: handHelper ?? this.handHelper);
}

/// The player's preferences, changed from the Settings popover.
final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void setHandHelper(bool on) => state = state.copyWith(handHelper: on);
}
