import 'dart:convert';

/// The free gift a player can collect once every [interval]: [coins] each
/// time, plus [gems] on every [gemEvery]th collection, so players who don't
/// buy anything still earn gems.
class HourlyGift {
  const HourlyGift({
    required this.coins,
    required this.interval,
    required this.gems,
    required this.gemEvery,
  });

  final int coins;
  final Duration interval;
  final int gems;
  final int gemEvery;

  /// What the [collection]th collection gives, counting from 1.
  ({int coins, int gems}) rewardFor(int collection) =>
      (coins: coins, gems: collection % gemEvery == 0 ? gems : 0);
}

/// Every amount in the game's coin and gem economy, read from the data file
/// `assets/config/economy.json`, so the amounts can be tuned there without
/// touching the code.
class EconomyConfig {
  const EconomyConfig({required this.startingGems, required this.hourlyGift});

  /// Reads the amounts from the data file's JSON:
  ///
  /// ```json
  /// {
  ///   "startingGems": 3,
  ///   "hourlyGift": {"coins": 500, "minutes": 60, "gems": 1, "gemEvery": 4}
  /// }
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
    final gift = decoded['hourlyGift'];
    if (gift is! Map<String, Object?>) {
      throw const FormatException('The economy needs an "hourlyGift" object');
    }
    return EconomyConfig(
      startingGems: _count(decoded, 'startingGems'),
      hourlyGift: HourlyGift(
        coins: _count(gift, 'coins', within: 'hourlyGift'),
        interval: Duration(
          minutes: _count(gift, 'minutes', within: 'hourlyGift', least: 1),
        ),
        gems: _count(gift, 'gems', within: 'hourlyGift'),
        gemEvery: _count(gift, 'gemEvery', within: 'hourlyGift', least: 1),
      ),
    );
  }

  /// The data file, as listed in pubspec.yaml.
  static const asset = 'assets/config/economy.json';

  /// The gems a new player starts with.
  final int startingGems;

  final HourlyGift hourlyGift;

  /// The whole number, [least] or more, under [key] in [json], which is the
  /// object named [within] if given.
  static int _count(
    Map<String, Object?> json,
    String key, {
    String? within,
    int least = 0,
  }) {
    if (json[key] case final int value when value >= least) return value;
    final name = within == null ? '"$key"' : '"$within.$key"';
    throw FormatException(
      'The economy needs $name, a whole number from $least',
    );
  }
}
