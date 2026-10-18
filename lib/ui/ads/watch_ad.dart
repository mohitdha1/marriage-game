import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../home/home_screen.dart' show formatCoins;
import '../home/player_data_provider.dart';
import 'rewarded_ad_service.dart';

/// [reward] as an amount: "1,000 coins", "1 gem" or "3 gems".
String amountText(Reward reward) {
  String gems(int n) => '$n ${n == 1 ? 'gem' : 'gems'}';
  return switch (reward) {
    Reward(coins: 0, gems: final g) => gems(g),
    Reward(coins: final c, gems: 0) => '${formatCoins(c)} coins',
    Reward(coins: final c, gems: final g) =>
      '${formatCoins(c)} coins and '
          '${gems(g)}',
  };
}

/// The offer on an ad button: "Watch an ad for 1,000 coins".
String adOfferText(Reward reward) => 'Watch an ad for ${amountText(reward)}';

/// How many ads are left today: "3 left today".
String adsLeftText(int left) => '$left left today';

/// Said when no ad could be shown.
const noAdText = 'No ad is ready right now. Please try again in a moment.';

/// Said once the day's ads are used up.
const noAdsLeftText = 'No more ads today. Come back tomorrow.';

/// Shows a rewarded ad over [context] while there are any left today, and
/// returns how it went, or `null`, showing nothing, once the day's are used
/// up. Paying for it is up to the caller. Call it only away from the table,
/// never during a hand.
Future<AdResult?> showRewardedAd(BuildContext context, WidgetRef ref) async {
  if (ref.read(playerDataProvider.notifier).adsLeftToday() == 0) return null;
  return ref.read(rewardedAdServiceProvider).show(context);
}
