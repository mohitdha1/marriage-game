import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';

/// The app's own data file.
EconomyConfig appEconomy() =>
    EconomyConfig.fromJson(File(EconomyConfig.asset).readAsStringSync());

/// A valid entry fee, for files testing the other amounts.
const fee = '"entryFee": {"gems": 1, "aboveStake": 100}';

/// A valid hourly gift, for files testing the other amounts.
const validGift =
    '"hourlyGift": {"minutes": 60, "cards": [{"coins": 500, "weight": 1}], '
    '"bonus": {"gems": 1}}';

void main() {
  group("The app's data file", () {
    testWidgets('is bundled with the app and loads', (tester) async {
      final economy = await loadEconomyConfig();

      expect(economy.startingGems, appEconomy().startingGems);
    });

    test('starts a new player with 3 gems', () {
      expect(appEconomy().startingGems, 3);
    });

    test('pays 1,000 coins for a 30-second ad, 5 times a day', () {
      final ad = appEconomy().rewardedAd;

      expect(ad.coins, 1000);
      expect(ad.perDay, 5);
      expect(ad.length, const Duration(seconds: 30));
    });

    test('charges 1 gem a match at tables above 100 a point', () {
      final fee = appEconomy().entryFee;

      expect(fee.gems, 1);
      expect(fee.aboveStake, 100);
    });

    test('lays out cards worth 250 to 5,000 coins, or 1 or 3 gems, by the '
        'chosen chances, with a gem for the bonus', () {
      final gift = appEconomy().hourlyGift;

      expect(gift.interval, const Duration(hours: 1));
      expect(
        [for (final card in gift.cards) (card.reward, card.weight)],
        [
          (const Reward(coins: 250), 30),
          (const Reward(coins: 500), 30),
          (const Reward(coins: 1000), 20),
          (const Reward(coins: 2500), 8),
          (const Reward(coins: 5000), 2),
          (const Reward(gems: 1), 8),
          (const Reward(gems: 3), 2),
        ],
      );
      expect(gift.bonus, const Reward(gems: 1));
    });
  });

  group('The hourly gift', () {
    const gift = HourlyGift(
      interval: Duration(hours: 1),
      cards: [
        GiftCard(Reward(coins: 100), 6),
        GiftCard(Reward(coins: 1000), 3),
        GiftCard(Reward(gems: 1), 1),
      ],
      bonus: Reward(gems: 1),
    );

    test('cards turn up by their weights', () {
      final random = Random(42);
      final counts = <Reward, int>{};
      const draws = 20000;
      for (var i = 0; i < draws; i++) {
        counts.update(gift.draw(random), (n) => n + 1, ifAbsent: () => 1);
      }

      expect(counts[const Reward(coins: 100)]! / draws, closeTo(0.6, 0.015));
      expect(counts[const Reward(coins: 1000)]! / draws, closeTo(0.3, 0.015));
      expect(counts[const Reward(gems: 1)]! / draws, closeTo(0.1, 0.01));
    });

    test('a card never comes up without weight, and one card always does', () {
      const one = HourlyGift(
        interval: Duration(hours: 1),
        cards: [GiftCard(Reward(coins: 5), 1)],
        bonus: Reward(gems: 1),
      );
      final random = Random(7);

      expect(
        {for (var i = 0; i < 50; i++) one.draw(random)},
        {const Reward(coins: 5)},
      );
    });

    test('the board is ten cards, the same for the same seed', () {
      expect(gift.board(3), hasLength(10));
      expect(gift.board(3), gift.board(3));
      expect({
        for (var seed = 0; seed < 5; seed++) gift.board(seed).join(),
      }, hasLength(greaterThan(1)));
    });

    test('a reward doubles, and reads back from what it writes', () {
      const reward = Reward(coins: 250, gems: 1);

      expect(reward.doubled, const Reward(coins: 500, gems: 2));
      expect(Reward.fromJson(reward.toJson()), reward);
      expect(const Reward(gems: 3).toJson(), {'gems': 3});
    });

    test('a missing gift, or one with no wait, no cards, an empty card or '
        'no weight, is refused', () {
      const ad =
          '"rewardedAd": {"coins": 1000, "perDay": 5, "seconds": 30}, $fee';
      String giftWith(String body) =>
          '{"startingGems": 3, $ad, "hourlyGift": {$body}}';
      const cards = '"cards": [{"coins": 500, "weight": 1}]';
      const bonus = '"bonus": {"gems": 1}';
      for (final (json, problem) in [
        ('{"startingGems": 3, $ad}', '"hourlyGift"'),
        (
          giftWith('"minutes": 0, $cards, $bonus'),
          '"hourlyGift.minutes", a whole number from 1',
        ),
        (giftWith('"minutes": 60, $bonus'), '"hourlyGift.cards"'),
        (giftWith('"minutes": 60, "cards": [], $bonus'), '"hourlyGift.cards"'),
        (
          giftWith('"minutes": 60, "cards": [{"weight": 1}], $bonus'),
          '"hourlyGift.cards[0]" to give coins or gems',
        ),
        (
          giftWith(
            '"minutes": 60, "cards": [{"coins": 5, "weight": 1}, '
            '{"coins": 5, "weight": 0}], $bonus',
          ),
          '"hourlyGift.cards[1].weight", a whole number from 1',
        ),
        (
          giftWith(
            '"minutes": 60, "cards": [{"coins": -5, "weight": 1}], $bonus',
          ),
          '"hourlyGift.cards[0].coins"',
        ),
        (giftWith('"minutes": 60, $cards'), '"hourlyGift.bonus"'),
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

  test('a missing rewarded ad, or one with no length, is refused', () {
    const gift = '$validGift, $fee';
    for (final (json, problem) in [
      ('{"startingGems": 3, $gift}', '"rewardedAd"'),
      (
        '{"startingGems": 3, $gift, "rewardedAd": {"coins": 1000, '
            '"perDay": 5, "seconds": 0}}',
        '"rewardedAd.seconds", a whole number from 1',
      ),
      (
        '{"startingGems": 3, $gift, "rewardedAd": {"coins": 1000, '
            '"seconds": 30}}',
        '"rewardedAd.perDay"',
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

  group('The entry fee', () {
    const fee = EntryFee(gems: 1, aboveStake: 100);

    test('is charged only above its stake, and never off a stake table', () {
      expect(fee.gemsFor(100), 0);
      expect(fee.gemsFor(5), 0);
      expect(fee.gemsFor(250), 1);
      expect(fee.gemsFor(100000), 1);
      expect(fee.gemsFor(null), 0);
    });

    test('a missing fee, or one without a stake, is refused', () {
      const rest =
          '"startingGems": 3, $validGift, "rewardedAd": {"coins": 1000, '
          '"perDay": 5, "seconds": 30}';
      for (final (json, problem) in [
        ('{$rest}', '"entryFee"'),
        ('{$rest, "entryFee": {"gems": 1}}', '"entryFee.aboveStake"'),
        (
          '{$rest, "entryFee": {"gems": -1, "aboveStake": 100}}',
          '"entryFee.gems"',
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
          '$validGift, "rewardedAd": {"coins": 1000, "perDay": 5, '
          '"seconds": 30}, $fee';
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
