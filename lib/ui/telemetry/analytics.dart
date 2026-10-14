import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_player.dart';
import '../../engine/game_config.dart';

/// The few events the app reports about how it's played. Nothing in them
/// identifies the player: no names, no room codes, only choices and
/// outcomes. An interface so tests can swap in a silent or recording
/// version.
abstract interface class Analytics {
  /// A match has started. [stake] is the stake table's coins per point,
  /// `null` away from the stake tables; [difficulty] is `null` when no
  /// bots are at the table.
  void gameStarted({
    required GameMode mode,
    required int? stake,
    required BotDifficulty? difficulty,
  });

  /// A round this device's player took part in has finished.
  void roundFinished({required bool won, required bool sawJoker});

  /// The player left the table while a round was still being played.
  void gameQuitEarly();

  /// Watches the app's navigator, reporting each screen as it opens.
  List<NavigatorObserver> get navigatorObservers;
}

/// Reports nothing; for tests and platforms without Firebase.
class SilentAnalytics implements Analytics {
  const SilentAnalytics();

  @override
  void gameStarted({
    required GameMode mode,
    required int? stake,
    required BotDifficulty? difficulty,
  }) {}

  @override
  void roundFinished({required bool won, required bool sawJoker}) {}

  @override
  void gameQuitEarly() {}

  @override
  List<NavigatorObserver> get navigatorObservers => const [];
}

/// Sends the events to Google Analytics for Firebase.
class FirebaseGameAnalytics implements Analytics {
  FirebaseGameAnalytics(this._firebase)
    : navigatorObservers = [
        FirebaseAnalyticsObserver(
          analytics: _firebase,
          // The first screen's route is called "/".
          nameExtractor: (settings) =>
              settings.name == Navigator.defaultRouteName
              ? 'home'
              : settings.name,
        ),
      ];

  final FirebaseAnalytics _firebase;

  @override
  final List<NavigatorObserver> navigatorObservers;

  @override
  void gameStarted({
    required GameMode mode,
    required int? stake,
    required BotDifficulty? difficulty,
  }) => _log('game_started', {
    'mode': mode.name,
    'stake_tier': stake?.toString() ?? 'none',
    'bot_difficulty': difficulty?.name ?? 'none',
  });

  @override
  void roundFinished({required bool won, required bool sawJoker}) => _log(
    'round_finished',
    {'result': won ? 'won' : 'lost', 'saw_joker': sawJoker ? 'yes' : 'no'},
  );

  @override
  void gameQuitEarly() => _log('game_quit_early');

  /// Logs in the background: a report that fails to send never holds up
  /// or breaks the game.
  void _log(String name, [Map<String, Object>? parameters]) {
    _firebase
        .logEvent(name: name, parameters: parameters)
        .catchError((Object _) {});
  }
}

/// The app's analytics. Silent unless the app is started with Firebase,
/// which overrides it.
final analyticsProvider = Provider<Analytics>((ref) => const SilentAnalytics());
