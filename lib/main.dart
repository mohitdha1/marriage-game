import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'ui/home/home_screen.dart';
import 'ui/settings/about.dart';
import 'ui/settings/preferences.dart';
import 'ui/settings/settings.dart';
import 'ui/telemetry/analytics.dart';
import 'ui/telemetry/crash_reports.dart';
import 'ui/theme/table_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerArtLicence();
  final preferences = DevicePreferences(await SharedPreferences.getInstance());
  // The table is designed for landscape only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        ...await _startFirebase(),
      ],
      child: const MarriageApp(),
    ),
  );
}

/// Starts Firebase, sending crashes to Crashlytics and events to Analytics,
/// and returns the overrides that put them to use. Only Android is set up
/// with Firebase so far; elsewhere the app runs without it.
Future<List<Override>> _startFirebase() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final crashlytics = FirebaseCrashlytics.instance;
  reportCrashes(crashlytics);
  return [
    analyticsProvider.overrideWithValue(
      FirebaseGameAnalytics(FirebaseAnalytics.instance),
    ),
    testCrashProvider.overrideWithValue(crashlytics.crash),
  ];
}

/// Root widget of the application, styled with the chosen [TableTheme].
class MarriageApp extends ConsumerWidget {
  const MarriageApp({super.key, this.home = const HomeScreen()});

  /// The first screen. Tests start straight at [singlePlayerTable].
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(settingsProvider.select((s) => s.tableTheme)).theme;
    return MaterialApp(
      title: 'Marriage',
      debugShowCheckedModeBanner: false,
      navigatorObservers: ref.watch(analyticsProvider).navigatorObservers,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: table.seed),
        extensions: [table],
      ),
      home: home,
    );
  }
}
