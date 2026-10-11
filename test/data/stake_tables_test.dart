import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/data/stake_tables.dart';
import 'package:marriage_game/ui/home/stake_tables_provider.dart';

/// The app's own data file.
StakeTables appStakeTables() =>
    StakeTables.fromJson(File(StakeTables.asset).readAsStringSync());

String tablesJson(List<String> rows) => '{"tables": [${rows.join(',')}]}';

String row(int stake, int minBalance, int games, String difficulty) =>
    '{"stake": $stake, "minBalance": $minBalance, '
    '"gamesToUnlock": $games, "difficulty": "$difficulty"}';

void main() {
  group("The app's data file", () {
    testWidgets('is bundled with the app and loads', (tester) async {
      final tables = await loadStakeTables();

      expect(tables.tiers, hasLength(appStakeTables().tiers.length));
    });

    test('has the 14 tiers from 5 to 100K coins a point', () {
      expect(appStakeTables().tiers.map((t) => t.stake), [
        5,
        10,
        25,
        50,
        100,
        250,
        500,
        1000,
        2500,
        5000,
        10000,
        25000,
        50000,
        100000,
      ]);
    });

    test('each tier after the first needs 100 × its stake to join', () {
      final tiers = appStakeTables().tiers;

      expect(tiers.first.minBalance, 0);
      for (final tier in tiers.skip(1)) {
        expect(tier.minBalance, 100 * tier.stake, reason: '$tier');
      }
    });

    test('unlocking takes more games the higher the tier', () {
      expect(appStakeTables().tiers.map((t) => t.gamesToUnlock), [
        0,
        50,
        50,
        75,
        75,
        100,
        100,
        125,
        125,
        150,
        150,
        175,
        200,
        250,
      ]);
    });

    test('bots are Easy up to 50, Medium up to 2.5K, and Hard above', () {
      for (final tier in appStakeTables().tiers) {
        final expected = tier.stake <= 50
            ? BotDifficulty.easy
            : tier.stake <= 2500
            ? BotDifficulty.medium
            : BotDifficulty.hard;
        expect(tier.difficulty, expected, reason: '$tier');
      }
    });
  });

  group('Looking up tiers', () {
    final tables = StakeTables.fromJson(
      tablesJson([row(5, 0, 0, 'easy'), row(10, 1000, 50, 'easy')]),
    );

    test('by stake', () {
      expect(tables.withStake(10)?.minBalance, 1000);
      expect(tables.withStake(7), isNull);
    });

    test('the tier below', () {
      expect(tables.below(tables.tiers[1]), tables.tiers.first);
      expect(tables.below(tables.tiers.first), isNull);
    });
  });

  group('A data file that makes no sense is refused', () {
    void refuses(String source, String problem) => expect(
      () => StakeTables.fromJson(source),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(problem),
        ),
      ),
    );

    test('not JSON', () => refuses('{', 'not valid JSON'));

    test('no list of tables', () => refuses('{}', '"tables" list'));

    test('no tables at all', () => refuses(tablesJson([]), 'at least one'));

    test('a missing or mistyped value', () {
      refuses(tablesJson(['{"stake": 5}']), 'Stake table 1 needs');
      refuses(
        tablesJson([
          '{"stake": "5", "minBalance": 0, "gamesToUnlock": 0, '
              '"difficulty": "easy"}',
        ]),
        'Stake table 1 needs',
      );
    });

    test('an unknown difficulty', () {
      refuses(tablesJson([row(5, 0, 0, 'expert')]), 'unknown difficulty');
    });

    test('a first tier that has to be unlocked', () {
      refuses(tablesJson([row(5, 0, 10, 'easy')]), 'always open');
    });

    test('stakes that do not go up', () {
      refuses(
        tablesJson([row(10, 0, 0, 'easy'), row(5, 500, 50, 'easy')]),
        'must go up',
      );
    });

    test('a later tier that unlocks with no games', () {
      refuses(
        tablesJson([row(5, 0, 0, 'easy'), row(10, 1000, 0, 'easy')]),
        'at least 1 game',
      );
    });

    test('a zero stake or a negative minimum balance', () {
      refuses(tablesJson([row(0, 0, 0, 'easy')]), 'above 0');
      refuses(tablesJson([row(5, -1, 0, 'easy')]), 'not negative');
    });
  });
}
