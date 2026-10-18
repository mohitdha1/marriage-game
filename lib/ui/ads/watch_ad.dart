import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../home/home_screen.dart' show formatCoins;
import '../home/player_data_provider.dart';
import 'rewarded_ad_service.dart';

/// The offer on an ad button: "Watch a 30s ad for 1,000 coins".
String adOfferText(RewardedAd ad) =>
    'Watch a ${ad.length.inSeconds}s ad for ${formatCoins(ad.coins)} coins';

/// Said when no ad could be shown.
const noAdText = 'No ad is ready right now. Please try again in a moment.';

/// Said once the day's ads are used up.
const noAdsLeftText = 'No more ads today. Come back tomorrow.';

/// How many ads are left today: "3 left today".
String adsLeftText(int left) => '$left left today';

/// Shows a rewarded ad and, if it was watched to the end, pays its coins
/// and says so. Once the day's ads are used up, says to come back tomorrow
/// instead. Call it only away from the table, never during a hand.
Future<void> watchAdForCoins(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(playerDataProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  if (controller.adsLeftToday() == 0) {
    messenger.showSnackBar(const SnackBar(content: Text(noAdsLeftText)));
    return;
  }
  final result = await ref.read(rewardedAdServiceProvider).show(context);
  if (result == AdResult.unavailable) {
    messenger.showSnackBar(const SnackBar(content: Text(noAdText)));
  }
  if (!result.earned) return;
  final coins = await controller.claimAdReward();
  if (coins == null) return;
  messenger.showSnackBar(
    SnackBar(
      key: const Key('ad-reward'),
      content: Text('+${formatCoins(coins)} coins'),
    ),
  );
}
