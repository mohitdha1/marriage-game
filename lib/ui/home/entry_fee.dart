import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../ads/rewarded_ad_service.dart';
import '../shop/shop_screen.dart';
import 'economy_config_provider.dart';
import 'player_data_provider.dart';
import 'stake_table_picker.dart' show formatStake;

/// A match's entry fee: "1 gem", or "2 gems".
String gemsText(int gems) => '$gems ${gems == 1 ? 'gem' : 'gems'}';

/// The prompt for a player short of gems at the [stake] table, whose
/// [fee] it is, offering the shop, and the rewarded [ad] while there are
/// any left today. Ends by naming the tables that are free, those up to
/// [freeUpTo], so there's always a way to play.
String shortOfGemsText({
  required int stake,
  required int fee,
  required RewardedAd? ad,
  required int? freeUpTo,
}) => [
  'The ${formatStake(stake)} table costs ${gemsText(fee)} a game.',
  if (ad != null)
    'Get gems in the shop, or watch a ${ad.length.inSeconds}s ad to play '
        'this game free.'
  else
    'Get gems in the shop, or come back tomorrow for more ads.',
  if (freeUpTo != null)
    'Tables up to ${formatStake(freeUpTo)} a point are always free.',
].join(' ');

/// What the player picked when they were short of gems.
enum _ShortOfGems { shop, ad }

/// Pays the entry fee for a match at [stake], and returns whether the match
/// can start: straight away when it's free or the player has the gems.
/// Short of gems, the player is offered the shop, or a rewarded ad that
/// stands in for the fee, and the match starts if either comes through.
Future<bool> payEntryFee(
  BuildContext context,
  WidgetRef ref,
  int? stake,
) async {
  final controller = ref.read(playerDataProvider.notifier);
  if (await controller.payEntryFee(stake)) return true;
  if (!context.mounted) return false;

  final fee = controller.entryFeeFor(stake);
  final economy = ref.read(economyConfigProvider).value;
  final adsLeft = controller.adsLeftToday();
  final choice = await showDialog<_ShortOfGems>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('short-of-gems'),
      title: const Text('Out of gems'),
      content: Text(
        shortOfGemsText(
          stake: stake!,
          fee: fee,
          ad: adsLeft > 0 ? economy?.rewardedAd : null,
          freeUpTo: economy?.entryFee.aboveStake,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('gems-not-now'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        OutlinedButton.icon(
          key: const Key('gems-shop'),
          onPressed: () => Navigator.of(context).pop(_ShortOfGems.shop),
          icon: const Icon(Icons.storefront),
          label: const Text('Shop'),
        ),
        if (adsLeft > 0)
          FilledButton.icon(
            key: const Key('gems-watch-ad'),
            onPressed: () => Navigator.of(context).pop(_ShortOfGems.ad),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch ad'),
          ),
      ],
    ),
  );
  if (!context.mounted) return false;
  switch (choice) {
    case _ShortOfGems.shop:
      await openShop(context);
      // Gems bought in the shop pay the fee on the way back.
      return context.mounted && await controller.payEntryFee(stake);
    case _ShortOfGems.ad:
      final watched = await ref.read(rewardedAdServiceProvider).show(context);
      return watched && await controller.claimAdEntry();
    case null:
      return false;
  }
}
