import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small values the app keeps between launches: settings, profile and
/// coins. An interface so tests can use [InMemoryPreferences] instead of the
/// device's storage.
abstract interface class PreferencesStore {
  bool? getBool(String key);
  int? getInt(String key);
  String? getString(String key);

  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> setString(String key, String value);
}

/// Keeps values in memory only, forgetting them when the app closes.
class InMemoryPreferences implements PreferencesStore {
  InMemoryPreferences([Map<String, Object>? initial]) : _values = {...?initial};

  final Map<String, Object> _values;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}

/// Saves values on the device with the shared_preferences package.
class DevicePreferences implements PreferencesStore {
  DevicePreferences(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// Where the app keeps its saved values. The app overrides this with
/// [DevicePreferences] at start-up; on its own it forgets everything, which
/// is what tests want.
final preferencesProvider = Provider<PreferencesStore>(
  (ref) => InMemoryPreferences(),
);
