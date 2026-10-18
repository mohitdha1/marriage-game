import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../home/home_screen.dart' show formatCoins;
import '../home/player_data_provider.dart';
import 'rewarded_ad_service.dart';

/// The offer on an ad button: "Watch a 30s ad for 1,000 coins".
String adOfferText(RewardedAd ad) =>
    'Watch a ${ad.length.inSeconds}s ad for ${formatCoins(ad.coins)} coins';

/// How many ads are left today: "3 left today".
String adsLeftText(int left) => '$left left today';

/// Shows a rewarded ad and, if it was watched to the end, pays its coins
/// and says so. Once the day's ads are used up, says to come back tomorrow
/// instead. Call it only away from the table, never during a hand.
Future<void> watchAdForCoins(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(playerDataProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  if (controller.adsLeftToday() == 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No more ads today. Come back tomorrow.')),
    );
    return;
  }
  final watched = await ref.read(rewardedAdServiceProvider).show(context);
  if (!watched) return;
  final coins = await controller.claimAdReward();
  if (coins == null) return;
  messenger.showSnackBar(
    SnackBar(
      key: const Key('ad-reward'),
      content: Text('+${formatCoins(coins)} coins'),
    ),
  );
}
