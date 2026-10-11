import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/data/player_data.dart';
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

  group('Unlocking', () {
    final tables = appStakeTables();
    final five = tables.withStake(5)!;
    final ten = tables.withStake(10)!;
    final twentyFive = tables.withStake(25)!;

    /// A player with [games] played at each stake.
    PlayerData playerWith(Map<int, int> games, {int coins = 1000000}) =>
        PlayerData(coins: coins, gamesAtStake: games);

    test('the first tier is always open, with no progress to show', () {
      expect(tables.isUnlocked(five, const PlayerData()), isTrue);
      expect(tables.unlockProgress(five, const PlayerData()), isNull);
    });

    test('a new player has every other tier locked, at 0 games', () {
      for (final tier in tables.tiers.skip(1)) {
        expect(tables.isUnlocked(tier, const PlayerData()), isFalse);
        expect(tables.unlockProgress(tier, const PlayerData()), (
          played: 0,
          needed: tier.gamesToUnlock,
        ));
      }
    });

    test('progress counts games at the tier below', () {
      final player = playerWith({5: 32});

      expect(tables.unlockProgress(ten, player), (played: 32, needed: 50));
      expect(tables.isUnlocked(ten, player), isFalse);
    });

    test('the 10 tier unlocks on the 50th game at the 5 tier', () {
      expect(tables.isUnlocked(ten, playerWith({5: 49})), isFalse);
      expect(tables.isUnlocked(ten, playerWith({5: 50})), isTrue);
      expect(tables.unlockProgress(ten, playerWith({5: 50})), isNull);
    });

    test('games beyond the count still show as done, not more', () {
      // 60 games at 10, but 10 itself is still locked.
      final player = playerWith({5: 10, 10: 60});

      expect(tables.unlockProgress(twentyFive, player), (
        played: 50,
        needed: 50,
      ));
    });

    test('a tier stays locked until the tier below is unlocked too', () {
      expect(tables.isUnlocked(twentyFive, playerWith({10: 50})), isFalse);
      expect(
        tables.isUnlocked(twentyFive, playerWith({5: 50, 10: 50})),
        isTrue,
      );
    });

    test('every tier opens in turn after its games at the one below', () {
      final games = <int, int>{};
      for (final tier in tables.tiers.skip(1)) {
        final previous = tables.below(tier)!;
        games[previous.stake] = tier.gamesToUnlock - 1;
        expect(tables.isUnlocked(tier, playerWith(games)), isFalse);
        games[previous.stake] = tier.gamesToUnlock;
        expect(tables.isUnlocked(tier, playerWith(games)), isTrue);
      }
    });

    test('joining needs the tier unlocked and its minimum balance', () {
      final unlocked = {5: 50};

      expect(tables.canJoin(ten, playerWith(unlocked, coins: 1000)), isTrue);
      expect(tables.canJoin(ten, playerWith(unlocked, coins: 999)), isFalse);
      expect(tables.canJoin(ten, playerWith({5: 49}, coins: 5000)), isFalse);
    });

    test('the first tier can be joined even with no coins left', () {
      expect(tables.canJoin(five, const PlayerData(coins: 0)), isTrue);
    });

    test('an unlocked tier stays unlocked when the balance drops', () {
      final broke = playerWith({5: 50}, coins: 0);

      expect(tables.isUnlocked(ten, broke), isTrue);
      expect(tables.canJoin(ten, broke), isFalse);
    });
  });
}
