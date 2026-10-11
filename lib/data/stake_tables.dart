import 'dart:convert';

import '../bots/bot_player.dart';

/// One tier of stake table: what each point is worth in coins, and what it
/// takes to sit down at it.
class StakeTable {
  const StakeTable({
    required this.stake,
    required this.minBalance,
    required this.gamesToUnlock,
    required this.difficulty,
  });

  /// Coins won or lost per point.
  final int stake;

  /// The coin balance needed to join.
  final int minBalance;

  /// Games to play at the tier below before this one unlocks; 0 for the
  /// first tier, which is always open.
  final int gamesToUnlock;

  /// How well the bots at this table play.
  final BotDifficulty difficulty;

  @override
  String toString() => 'StakeTable($stake)';
}

/// Every stake table, cheapest first, as read from the data file
/// `assets/config/stake_tables.json`. The values there can be tuned without
/// touching the code.
class StakeTables {
  StakeTables(List<StakeTable> tiers) : tiers = List.unmodifiable(tiers) {
    _check();
  }

  /// Reads the tiers from the data file's JSON:
  ///
  /// ```json
  /// {"tables": [
  ///   {"stake": 5, "minBalance": 0, "gamesToUnlock": 0, "difficulty": "easy"},
  ///   ...
  /// ]}
  /// ```
  ///
  /// Throws a [FormatException] naming the problem if the file is malformed
  /// or its values don't make sense together.
  factory StakeTables.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Stake tables are not valid JSON: ${e.message}');
    }
    if (decoded case {'tables': final List<Object?> rows}) {
      return StakeTables([
        for (final (i, row) in rows.indexed) _tierFrom(row, i),
      ]);
    }
    throw const FormatException('Stake tables need a "tables" list');
  }

  /// The data file, as listed in pubspec.yaml.
  static const asset = 'assets/config/stake_tables.json';

  final List<StakeTable> tiers;

  /// The tier with [stake], or `null` if there isn't one.
  StakeTable? withStake(int stake) {
    for (final tier in tiers) {
      if (tier.stake == stake) return tier;
    }
    return null;
  }

  /// The tier just below [tier], or `null` for the first.
  StakeTable? below(StakeTable tier) {
    final i = tiers.indexOf(tier);
    return i > 0 ? tiers[i - 1] : null;
  }

  static StakeTable _tierFrom(Object? row, int index) {
    if (row case {
      'stake': final int stake,
      'minBalance': final int minBalance,
      'gamesToUnlock': final int gamesToUnlock,
      'difficulty': final String difficulty,
    }) {
      final level = BotDifficulty.values.asNameMap()[difficulty];
      if (level == null) {
        throw FormatException(
          'Stake table ${index + 1}: unknown difficulty "$difficulty"',
        );
      }
      return StakeTable(
        stake: stake,
        minBalance: minBalance,
        gamesToUnlock: gamesToUnlock,
        difficulty: level,
      );
    }
    throw FormatException(
      'Stake table ${index + 1} needs a whole-number stake, minBalance and '
      'gamesToUnlock, and a difficulty',
    );
  }

  void _check() {
    if (tiers.isEmpty) {
      throw const FormatException('There must be at least one stake table');
    }
    if (tiers.first.gamesToUnlock != 0) {
      throw const FormatException(
        'The first stake table is always open, so needs 0 games to unlock',
      );
    }
    for (final (i, tier) in tiers.indexed) {
      final name = 'Stake table ${i + 1} (${tier.stake})';
      if (tier.stake <= 0 || tier.minBalance < 0) {
        throw FormatException(
          '$name: the stake must be above 0, and the minimum balance not '
          'negative',
        );
      }
      if (i == 0) continue;
      final previous = tiers[i - 1];
      if (tier.stake <= previous.stake) {
        throw FormatException('$name: stakes must go up from tier to tier');
      }
      if (tier.gamesToUnlock <= 0) {
        throw FormatException('$name: needs at least 1 game to unlock');
      }
    }
  }
}
