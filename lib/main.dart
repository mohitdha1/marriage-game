import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/home/home_screen.dart';
import 'ui/settings/about.dart';
import 'ui/settings/preferences.dart';
import 'ui/settings/settings.dart';
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
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const MarriageApp(),
    ),
  );
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: table.seed),
        extensions: [table],
      ),
      home: home,
    );
  }
}
