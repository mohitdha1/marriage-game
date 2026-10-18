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
      for (final json in [
        '{}',
        '{"startingGems": -1}',
        '{"startingGems": 1.5}',
        '{"startingGems": "3"}',
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
