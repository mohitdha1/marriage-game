import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';

/// The app's own data file.
EconomyConfig appEconomy() =>
    EconomyConfig.fromJson(File(EconomyConfig.asset).readAsStringSync());

void main() {
  group("The app's data file", () {
    testWidgets('is bundled with the app and loads', (tester) async {
      final economy = await loadEconomyConfig();

      expect(economy.startingGems, appEconomy().startingGems);
    });

    test('starts a new player with 3 gems', () {
      expect(appEconomy().startingGems, 3);
    });

    test('gives 500 coins an hour, and a gem every 4th time', () {
      final gift = appEconomy().hourlyGift;

      expect(gift.coins, 500);
      expect(gift.interval, const Duration(hours: 1));
      expect(gift.gems, 1);
      expect(gift.gemEvery, 4);
    });
  });

  group('The hourly gift', () {
    test('the gem comes on every gemEvery-th collection', () {
      const gift = HourlyGift(
        coins: 500,
        interval: Duration(hours: 1),
        gems: 2,
        gemEvery: 3,
      );

      expect(
        [for (var n = 1; n <= 6; n++) gift.rewardFor(n)],
        [
          (coins: 500, gems: 0),
          (coins: 500, gems: 0),
          (coins: 500, gems: 2),
          (coins: 500, gems: 0),
          (coins: 500, gems: 0),
          (coins: 500, gems: 2),
        ],
      );
    });

    test('a missing gift, or one with no wait or no gem cycle, is refused', () {
      for (final (json, problem) in [
        ('{"startingGems": 3}', '"hourlyGift"'),
        (
          '{"startingGems": 3, "hourlyGift": {"coins": 500, "minutes": 0, '
              '"gems": 1, "gemEvery": 4}}',
          '"hourlyGift.minutes", a whole number from 1',
        ),
        (
          '{"startingGems": 3, "hourlyGift": {"coins": 500, "minutes": 60, '
              '"gems": 1, "gemEvery": 0}}',
          '"hourlyGift.gemEvery", a whole number from 1',
        ),
        (
          '{"startingGems": 3, "hourlyGift": {"coins": -5, "minutes": 60, '
              '"gems": 1, "gemEvery": 4}}',
          '"hourlyGift.coins"',
        ),
      ]) {
        expect(
          () => EconomyConfig.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(problem),
            ),
          ),
          reason: json,
        );
      }
    });
  });

  group('Reading the amounts', () {
    test('a malformed file names the problem', () {
      expect(
        () => EconomyConfig.fromJson('{'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
      expect(() => EconomyConfig.fromJson('[]'), throwsFormatException);
    });

    test('a missing or negative amount is refused', () {
      const gift =
          '"hourlyGift": {"coins": 500, "minutes": 60, "gems": 1, '
          '"gemEvery": 4}';
      for (final json in [
        '{$gift}',
        '{"startingGems": -1, $gift}',
        '{"startingGems": 1.5, $gift}',
        '{"startingGems": "3", $gift}',
      ]) {
        expect(
          () => EconomyConfig.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('"startingGems"'),
            ),
          ),
          reason: json,
        );
      }
    });
  });
}
