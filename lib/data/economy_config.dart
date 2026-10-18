import 'dart:convert';

/// Every amount in the game's coin and gem economy, read from the data file
/// `assets/config/economy.json`, so the amounts can be tuned there without
/// touching the code.
class EconomyConfig {
  const EconomyConfig({required this.startingGems});

  /// Reads the amounts from the data file's JSON:
  ///
  /// ```json
  /// {"startingGems": 3}
  /// ```
  ///
  /// Throws a [FormatException] naming the problem if the file is malformed
  /// or an amount doesn't make sense.
  factory EconomyConfig.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('The economy is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The economy needs a JSON object');
    }
    return EconomyConfig(startingGems: _count(decoded, 'startingGems'));
  }

  /// The data file, as listed in pubspec.yaml.
  static const asset = 'assets/config/economy.json';

  /// The gems a new player starts with.
  final int startingGems;

  /// The whole number, 0 or more, under [key] in [json].
  static int _count(Map<String, Object?> json, String key) {
    if (json[key] case final int value when value >= 0) return value;
    throw FormatException('The economy needs "$key", a whole number from 0');
  }
}
