import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/watch_ad.dart';
import 'economy_config_provider.dart';
import 'home_screen.dart' show formatCoins;
import 'player_data_provider.dart';

/// The hourly gift on the home screen: a gift icon with the time left until
/// it can be collected, or, once it's ready, a glowing button that collects
/// it. While there are rewarded ads left today, collecting offers one for
/// more coins. Hidden until the player's data and the economy's amounts
/// have loaded.
class HourlyGiftButton extends ConsumerStatefulWidget {
  const HourlyGiftButton({super.key});

  @override
  ConsumerState<HourlyGiftButton> createState() => _HourlyGiftButtonState();
}

class _HourlyGiftButtonState extends ConsumerState<HourlyGiftButton> {
  /// Ticks once a second while the gift is on its way, so the countdown
  /// moves; stopped once it's ready, when nothing changes until it's
  /// collected.
  Timer? _ticker;
  bool _collecting = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tickWhile(bool waiting) {
    if (!waiting) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _collect() async {
    setState(() => _collecting = true);
    final reward = await ref.read(playerDataProvider.notifier).collectGift();
    if (!mounted) return;
    setState(() => _collecting = false);
    if (reward == null) return;
    final economy = ref.read(economyConfigProvider).value;
    final adsLeft = ref.read(playerDataProvider.notifier).adsLeftToday();
    if (economy == null || adsLeft == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('gift-collected'),
          content: Text(giftRewardText(reward)),
        ),
      );
      return;
    }
    // With ads left today, the gift comes with an offer of more.
    final watch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('gift-collected'),
        title: Text(giftRewardText(reward)),
        content: Text(
          'Want more? ${adOfferText(economy.rewardedAd)} '
          '(${adsLeftText(adsLeft)}).',
        ),
        actions: [
          TextButton(
            key: const Key('gift-no-ad'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No thanks'),
          ),
          FilledButton.icon(
            key: const Key('gift-watch-ad'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch ad'),
          ),
        ],
      ),
    );
    if (watch == true && mounted) await watchAdForCoins(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final economy = ref.watch(economyConfigProvider).value;
    final data = ref.watch(playerDataProvider).value;
    if (economy == null || data == null) return const SizedBox.shrink();

    final wait = data.giftWait(economy.hourlyGift, ref.read(clockProvider)());
    final ready = wait == Duration.zero;
    // Starting or stopping the ticker doesn't rebuild anything, so it's
    // safe to do while building.
    _tickWhile(!ready);

    final accent = Theme.of(context).colorScheme;
    return Semantics(
      button: ready,
      label: ready
          ? 'Hourly gift ready: tap to collect'
          : 'Next hourly gift in ${countdownText(wait)}',
      excludeSemantics: true,
      child: Material(
        key: const Key('hourly-gift'),
        color: ready ? const Color(0xFFFFC107) : const Color(0x66000000),
        shape: const StadiumBorder(),
        elevation: ready ? 4 : 0,
        shadowColor: const Color(0xFFFFC107),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: ready && !_collecting ? _collect : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 22,
                  color: ready ? accent.onPrimaryContainer : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  ready ? 'Collect' : countdownText(wait),
                  key: const Key('gift-label'),
                  style: TextStyle(
                    color: ready ? const Color(0xFF1A1A1A) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [wait] as a countdown: "59:07", or "1:02:05" past an hour. Seconds round
/// up, so it never shows 0:00 while there's still time to wait.
String countdownText(Duration wait) {
  final total = (wait.inMilliseconds / 1000).ceil();
  final hours = total ~/ 3600;
  final minutes = total ~/ 60 % 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '$minutes:${two(seconds)}';
}

/// What collecting a gift gave: "+500 coins", or "+500 coins and 1 gem".
String giftRewardText(({int coins, int gems}) reward) {
  final coins = '+${formatCoins(reward.coins)} coins';
  return switch (reward.gems) {
    0 => coins,
    1 => '$coins and 1 gem',
    final gems => '$coins and $gems gems',
  };
}
