import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/ui/ads/rewarded_ad_service.dart';
import 'package:marriage_game/ui/ads/watch_ad.dart'
    show noAdText, noAdsLeftText;
import 'package:marriage_game/ui/home/gift_cards_screen.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/table/card_view.dart';

import 'home_screen_test.dart' show pumpHome;

final noon = DateTime(2026, 10, 17, 12);

/// The app's own hourly gift.
final gift = EconomyConfig.fromJson(
  File(EconomyConfig.asset).readAsStringSync(),
).hourlyGift;

/// The rewards the gift's seeded draws turn up, in order.
List<Reward> drawsFor(int seed, int count) {
  final random = Random(seed);
  return [for (var i = 0; i < count; i++) gift.draw(random)];
}

/// Stands in for an ad network with nothing to show.
class _NoAds implements RewardedAdService {
  const _NoAds();

  @override
  Future<AdResult> show(BuildContext context) async => AdResult.unavailable;
}

Finder card(int i) => find.byKey(Key('gift-card-$i'));

/// How many cards show their backs.
int faceDown(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const Key('gift-cards')),
      matching: find.byType(CardBack),
    )
    .evaluate()
    .length;

/// Lets every card finish turning.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(GiftCardsScreen.settleTime);
  await tester.pumpAndSettle();
}

Future<void> watchAd(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('Test ad'), findsOneWidget);
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  late ProviderContainer container;
  PlayerData data() => container.read(playerDataProvider).value!;

  /// Opens the home screen at [now] with the gift's draws seeded by [seed],
  /// then the gift's cards.
  Future<void> openCards(
    WidgetTester tester, {
    int seed = 1,
    Map<String, Object>? saved,
    DateTime Function()? clock,
    RewardedAdService? ads,
    bool tapGift = true,
  }) async {
    container = await pumpHome(
      tester,
      clock: clock ?? () => noon,
      saved: {'gems.startingGiven': true, ...?saved},
      overrides: [
        giftRandomProvider.overrideWithValue(Random(seed)),
        if (ads != null) rewardedAdServiceProvider.overrideWithValue(ads),
      ],
    );
    if (!tapGift) return;
    await tester.tap(find.byKey(const Key('hourly-gift')));
    await tester.pumpAndSettle();
  }

  group('The board', () {
    for (final (width, height) in [(844.0, 390.0), (640.0, 360.0)]) {
      testWidgets('ten cards, face down in two rows of five, fit a '
          '${width.round()}×${height.round()} screen', (tester) async {
        await openCards(tester);
        tester.view.physicalSize = Size(width, height);
        await tester.pumpAndSettle();

        expect(faceDown(tester), 10);
        final screen = Offset.zero & Size(width, height);
        final rects = [for (var i = 0; i < 10; i++) tester.getRect(card(i))];
        for (final (i, rect) in rects.indexed) {
          expect(screen.contains(rect.topLeft), isTrue, reason: 'card $i');
          expect(screen.contains(rect.bottomRight), isTrue, reason: 'card $i');
          expect(rect.width, greaterThan(48), reason: 'big enough to tap');
        }
        expect({for (final r in rects) r.top}, hasLength(2));
        expect(rects[4].top, rects[0].top);
        expect(rects[5].top, greaterThan(rects[0].bottom));
        for (var i = 0; i < 4; i++) {
          expect(rects[i].right, lessThan(rects[i + 1].left));
        }
      });
    }

    testWidgets('the cards wear the current card back', (tester) async {
      await openCards(tester);

      expect(
        find.descendant(of: card(0), matching: find.byType(CardBack)),
        findsOneWidget,
      );
    });
  });

  group('The free pick', () {
    testWidgets('turns over the card tapped to show the weighted draw, pays '
        'it, then turns over the rest', (tester) async {
      await openCards(tester, seed: 4);
      final [expected] = drawsFor(4, 1);
      final before = data();

      await tester.tap(card(7));
      await tester.pump();
      // Paid before the card has even turned.
      expect(data().coins, before.coins + expected.coins);
      expect(data().gems, before.gems + expected.gems);

      await tester.pump(GiftCardsScreen.flipTime);
      expect(faceDown(tester), 9);
      await settle(tester);
      expect(faceDown(tester), 0);
      expect(
        find.text('You got ${rewardText(expected).substring(1)}'),
        findsOneWidget,
      );
    });

    for (final tapped in [0, 9]) {
      testWidgets('the draw is the same whichever card is tapped: card '
          '${tapped + 1}', (tester) async {
        await openCards(tester, seed: 21);
        await tester.tap(card(tapped));
        await settle(tester);

        expect(data().giftSession!.pick.reward, drawsFor(21, 1).single);
      });
    }

    testWidgets('only one card an hour, however fast the taps', (tester) async {
      await openCards(tester);
      final coins = data().coins;

      await tester.tap(card(1));
      await tester.tap(card(2));
      await tester.pump();
      await settle(tester);
      await tester.tap(card(3));
      await settle(tester);

      expect(data().giftsCollected, 1);
      expect(data().giftSession!.pick.card, 1);
      expect(data().coins - coins, drawsFor(1, 1).single.coins);
    });

    testWidgets('starts the hour again', (tester) async {
      await openCards(tester);

      await tester.tap(card(0));
      await settle(tester);
      await tester.tap(find.byKey(const Key('gift-close')));
      await tester.pumpAndSettle();

      expect(data().giftCollectedAt, noon);
      expect(
        tester.widget<Text>(find.byKey(const Key('gift-label'))).data,
        '1:00:00',
      );
    });

    testWidgets('closing the screen mid-turn neither loses nor repeats the '
        'reward', (tester) async {
      await openCards(tester, seed: 9);
      final coins = data().coins;
      final gems = data().gems;
      final [expected] = drawsFor(9, 1);

      await tester.tap(card(5));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('gift-close')));
      await settle(tester);
      expect(find.byKey(const Key('gift-cards')), findsNothing);

      // Opened again, it shows the board as it was left, and picks nothing.
      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();
      expect(faceDown(tester), 0);
      await tester.tap(card(6));
      await settle(tester);

      expect(data().coins, coins + expected.coins);
      expect(data().gems, gems + expected.gems);
      expect(data().giftsCollected, 1);
      expect(data().giftSession!.pick.card, 5);
    });
  });

  group('The ad extras', () {
    Future<void> pickFree(WidgetTester tester, {int seed = 1}) async {
      await openCards(tester, seed: seed);
      await tester.tap(card(2));
      await settle(tester);
    }

    testWidgets('all three are offered after the free pick, not before', (
      tester,
    ) async {
      await openCards(tester);
      expect(find.byKey(const Key('gift-double')), findsNothing);

      await tester.tap(card(2));
      await settle(tester);

      expect(find.text('Watch an ad to double it'), findsOneWidget);
      expect(find.text('Watch an ad to pick another card'), findsOneWidget);
      expect(find.text('Watch an ad for a bonus (1 gem)'), findsOneWidget);
      expect(find.text('5 ads left today'), findsOneWidget);
    });

    testWidgets('doubling pays the free pick again, once', (tester) async {
      await pickFree(tester, seed: 6);
      final free = drawsFor(6, 1).single;
      final coins = data().coins;
      final gems = data().gems;

      await tester.tap(find.byKey(const Key('gift-double')));
      await watchAd(tester);

      expect(data().coins, coins + free.coins);
      expect(data().gems, gems + free.gems);
      expect(find.byKey(const Key('gift-double')), findsNothing);
      expect(find.byKey(const Key('gift-doubled')), findsOneWidget);
      expect(find.text('4 ads left today'), findsOneWidget);
    });

    testWidgets('another card turns the rest face down to pick from, pays '
        'its own draw, and leaves the hour alone', (tester) async {
      await pickFree(tester, seed: 8);
      final [_, second] = drawsFor(8, 2);
      final coins = data().coins;
      final gems = data().gems;

      await tester.tap(find.byKey(const Key('gift-another')));
      await watchAd(tester);
      expect(faceDown(tester), 9);
      expect(find.text('Pick one more card'), findsOneWidget);

      // The free pick can't be picked again.
      await tester.tap(card(2));
      await tester.pump();
      expect(faceDown(tester), 9);

      await tester.tap(card(8));
      await settle(tester);
      expect(faceDown(tester), 0);
      expect(data().coins, coins + second.coins);
      expect(data().gems, gems + second.gems);
      expect(data().giftSession!.extraPick?.card, 8);
      final [first, _] = drawsFor(8, 2);
      expect(
        find.text(
          'You got ${rewardText(Reward(coins: first.coins + second.coins, gems: first.gems + second.gems)).substring(1)}',
        ),
        findsOneWidget,
      );
      expect(data().giftCollectedAt, noon);
      expect(data().giftsCollected, 1);
      expect(find.byKey(const Key('gift-another')), findsNothing);
    });

    testWidgets('the double is only ever the free pick\'s, in either order', (
      tester,
    ) async {
      await pickFree(tester, seed: 13);
      final [free, second] = drawsFor(13, 2);
      final coins = data().coins;

      await tester.tap(find.byKey(const Key('gift-another')));
      await watchAd(tester);
      await tester.tap(card(0));
      await settle(tester);
      await tester.tap(find.byKey(const Key('gift-double')));
      await watchAd(tester);

      expect(data().coins, coins + second.coins + free.coins);
    });

    testWidgets('the bonus adds a gem, once', (tester) async {
      await pickFree(tester);
      final gems = data().gems;

      await tester.tap(find.byKey(const Key('gift-bonus')));
      await watchAd(tester);

      expect(data().gems, gems + 1);
      expect(find.text('Bonus! +1 gem'), findsOneWidget);
      expect(find.byKey(const Key('gift-bonus')), findsNothing);
    });

    testWidgets('once all three are taken, there\'s nothing more to open', (
      tester,
    ) async {
      await pickFree(tester);
      for (final key in ['gift-double', 'gift-bonus']) {
        await tester.tap(find.byKey(Key(key)));
        await watchAd(tester);
      }
      await tester.tap(find.byKey(const Key('gift-another')));
      await watchAd(tester);
      await tester.tap(card(9));
      await settle(tester);

      expect(find.text('Come back for the next gift!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gift-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gift-extras-waiting')), findsNothing);
      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gift-cards')), findsNothing);
    });

    testWidgets('an ad closed early gives nothing, and the offer stays', (
      tester,
    ) async {
      await pickFree(tester);
      final before = data();

      await tester.tap(find.byKey(const Key('gift-double')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(data(), before);
      expect(find.byKey(const Key('gift-double')), findsOneWidget);
    });

    testWidgets('with no ad to show, says so kindly, and the offer stays', (
      tester,
    ) async {
      await openCards(tester, ads: const _NoAds());
      await tester.tap(card(2));
      await settle(tester);
      final before = data();

      await tester.tap(find.byKey(const Key('gift-bonus')));
      await tester.pumpAndSettle();

      expect(find.text(noAdText), findsOneWidget);
      expect(data(), before);
      expect(find.byKey(const Key('gift-bonus')), findsOneWidget);
    });

    testWidgets('with the day\'s ads used up, says to come back tomorrow', (
      tester,
    ) async {
      await openCards(
        tester,
        saved: {'ads.day': '2026-10-17', 'ads.watched': 5},
      );
      await tester.tap(card(2));
      await settle(tester);
      expect(find.text('No ads left today'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gift-another')));
      await tester.pumpAndSettle();

      expect(find.text('Test ad'), findsNothing);
      expect(find.text(noAdsLeftText), findsOneWidget);
      expect(faceDown(tester), 0);
    });

    testWidgets('extras left can be taken after closing, until the next '
        'gift is ready', (tester) async {
      var now = noon;
      await openCards(tester, clock: () => now);
      await tester.tap(card(2));
      await settle(tester);
      await tester.tap(find.byKey(const Key('gift-close')));
      await tester.pumpAndSettle();

      now = now.add(const Duration(minutes: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('gift-extras-waiting')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gift-bonus')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gift-close')));
      await tester.pumpAndSettle();

      // The next gift is ready: a fresh board, face down.
      now = now.add(const Duration(minutes: 30));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();
      expect(faceDown(tester), 10);
      expect(find.byKey(const Key('gift-bonus')), findsNothing);
    });
  });

  test('rewards read as coins, gems, or both', () {
    expect(rewardText(const Reward(coins: 2500)), '+2,500 coins');
    expect(rewardText(const Reward(gems: 1)), '+1 gem');
    expect(rewardText(const Reward(gems: 3)), '+3 gems');
    expect(
      rewardText(const Reward(coins: 500, gems: 1)),
      '+500 coins and 1 gem',
    );
  });
}
