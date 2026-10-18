import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/ui/ads/rewarded_ad_service.dart';
import 'package:marriage_game/ui/ads/watch_ad.dart'
    show noAdText, noAdsLeftText;
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/shop/purchase_service.dart';
import 'package:marriage_game/ui/shop/shop_sheet.dart';

import 'home_screen_test.dart' show pumpHome;

final noon = DateTime(2026, 10, 17, 12);

/// Stands in for an ad network with nothing to show.
class _NoAds implements RewardedAdService {
  const _NoAds();

  @override
  Future<AdResult> show(BuildContext context) async => AdResult.unavailable;
}

/// The tab the open shop shows.
Currency shownTab(WidgetTester tester) =>
    find.byKey(const Key('shop-packs-coins')).evaluate().isNotEmpty
    ? Currency.coins
    : Currency.gems;

String textOf(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .join(' ');

void main() {
  late ProviderContainer container;
  PlayerData data() => container.read(playerDataProvider).value!;

  Future<void> home(
    WidgetTester tester, {
    Map<String, Object>? saved,
    RewardedAdService? ads,
    PurchaseService? store,
  }) async {
    container = await pumpHome(
      tester,
      clock: () => noon,
      saved: {'gems.startingGiven': true, 'gems.balance': 2, ...?saved},
      overrides: [
        if (ads != null) rewardedAdServiceProvider.overrideWithValue(ads),
        if (store != null) purchaseServiceProvider.overrideWithValue(store),
      ],
    );
  }

  Future<void> openFrom(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    expect(find.byType(ShopSheet), findsOneWidget, reason: key);
  }

  group('The balances open the shop on their tab', () {
    for (final (key, tab) in [
      ('coin-balance', Currency.coins),
      ('coin-plus', Currency.coins),
      ('gem-balance', Currency.gems),
      ('gem-plus', Currency.gems),
    ]) {
      testWidgets('$key on the home screen opens ${tab.name}', (tester) async {
        await home(tester);

        await openFrom(tester, key);

        expect(shownTab(tester), tab);
      });

      testWidgets('$key on the table picker opens ${tab.name}', (tester) async {
        await home(tester);
        await tester.tap(find.byKey(const Key('single-player')));
        await tester.pumpAndSettle();

        await openFrom(tester, key);

        expect(shownTab(tester), tab);
      });
    }

    testWidgets('the tabs switch between the coin and gem packs', (
      tester,
    ) async {
      await home(tester);
      await openFrom(tester, 'coin-plus');
      expect(find.byKey(const Key('buy-coins_25k')), findsOneWidget);

      await tester.tap(find.byKey(const Key('shop-tab-gems')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('buy-gems_10')), findsOneWidget);
      expect(find.byKey(const Key('buy-coins_25k')), findsNothing);
    });

    testWidgets('each tab offers its ad, and its packs with their prices', (
      tester,
    ) async {
      await home(tester);
      await openFrom(tester, 'coin-plus');

      expect(find.text('Watch an ad for 1,000 coins'), findsOneWidget);
      expect(find.text('5 left today'), findsOneWidget);
      for (final (id, amount, price) in [
        ('coins_25k', '25,000 coins', r'$0.99'),
        ('coins_150k', '150,000 coins', r'$4.99'),
        ('coins_400k', '400,000 coins', r'$9.99'),
      ]) {
        expect(find.text(amount), findsOneWidget);
        expect(textOf(tester, Key('buy-$id')), price);
      }

      await tester.tap(find.byKey(const Key('shop-tab-gems')));
      await tester.pumpAndSettle();
      expect(find.text('Watch an ad for 1 gem'), findsOneWidget);
      expect(find.text('150 gems'), findsOneWidget);
    });
  });

  group('Ads in the shop', () {
    testWidgets('pay the tab\'s currency once watched', (tester) async {
      await home(tester);
      await openFrom(tester, 'coin-plus');

      await tester.tap(find.byKey(const Key('shop-ad')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(data().coins, PlayerData.startingCoins + 1000);
      expect(find.text('+1,000 coins'), findsOneWidget);
      expect(find.text('4 left today'), findsOneWidget);

      await tester.tap(find.byKey(const Key('shop-tab-gems')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-ad')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(data().gems, 3);
      expect(find.text('+1 gem'), findsOneWidget);
    });

    testWidgets('closed early, pay nothing', (tester) async {
      await home(tester);
      await openFrom(tester, 'coin-plus');

      await tester.tap(find.byKey(const Key('shop-ad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(data().coins, PlayerData.startingCoins);
      expect(find.text('5 left today'), findsOneWidget);
    });

    testWidgets('grey out, saying why, once the day\'s are used up', (
      tester,
    ) async {
      await home(tester, saved: {'ads.day': '2026-10-17', 'ads.watched': 5});
      await openFrom(tester, 'gem-plus');

      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('shop-ad')))
            .onPressed,
        isNull,
      );
      expect(find.text(noAdsLeftText), findsOneWidget);
    });

    testWidgets('grey out, saying why, when no ad can be shown', (
      tester,
    ) async {
      await home(tester, ads: const _NoAds());
      await openFrom(tester, 'coin-plus');

      await tester.tap(find.byKey(const Key('shop-ad')));
      await tester.pumpAndSettle();

      expect(find.text(noAdText), findsWidgets);
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('shop-ad')))
            .onPressed,
        isNull,
      );
      expect(data().coins, PlayerData.startingCoins);
    });
  });

  group('Packs', () {
    testWidgets('in a debug build, Buy gives the pack', (tester) async {
      await home(tester);
      await openFrom(tester, 'gem-plus');

      await tester.tap(find.byKey(const Key('buy-gems_60')));
      await tester.pumpAndSettle();

      expect(data().gems, 62);
      expect(find.text('+60 gems'), findsOneWidget);
    });

    testWidgets('where nothing can be bought, they\'re coming soon', (
      tester,
    ) async {
      await home(tester, store: const FakePurchaseService(canPurchase: false));
      await openFrom(tester, 'coin-plus');

      expect(textOf(tester, const Key('buy-coins_25k')), 'Coming soon');
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('buy-coins_25k')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('the store refusing gives nothing, and says so', (
      tester,
    ) async {
      await home(tester, store: const _RefusingStore());
      await openFrom(tester, 'coin-plus');

      await tester.tap(find.byKey(const Key('buy-coins_25k')));
      await tester.pumpAndSettle();

      expect(data().coins, PlayerData.startingCoins);
      expect(
        find.text('Purchases aren\'t available right now.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the top bar counts up to a new balance', (tester) async {
    await home(tester);
    String coins() => textOf(tester, const Key('coin-balance'));
    expect(coins(), '10,000');

    await container.read(playerDataProvider.notifier).addCoins(25000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final midway = int.parse(coins().replaceAll(',', ''));
    expect(midway, greaterThan(10000));
    expect(midway, lessThan(35000));

    await tester.pumpAndSettle();
    expect(coins(), '35,000');
  });
}

/// A store that takes the order but can't charge for it.
class _RefusingStore implements PurchaseService {
  const _RefusingStore();

  @override
  bool get canPurchase => true;

  @override
  Future<PurchaseResult> buy(ShopPack pack) async => PurchaseResult.unavailable;
}
