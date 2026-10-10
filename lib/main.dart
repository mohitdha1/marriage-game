import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/home/home_screen.dart';
import 'ui/settings/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

/// Root widget of the application.
class MarriageApp extends StatelessWidget {
  const MarriageApp({super.key, this.home = const HomeScreen()});

  /// The first screen. Tests start straight at [singlePlayerTable].
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marriage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
      ),
      home: home,
    );
  }
}
