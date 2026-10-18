import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'economy_config_provider.dart';
import 'gift_cards_screen.dart';
import 'player_data_provider.dart';

/// The hourly gift on the home screen: a gift icon with the time left until
/// it can be collected, or, once it's ready, a glowing button that opens
/// its cards to pick from. While the last gift's rewarded-ad extras are
/// still on offer, tapping the countdown opens them again. Hidden until the
/// player's data and the economy's amounts have loaded.
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
  bool _opening = false;

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

  Future<void> _open() async {
    setState(() => _opening = true);
    await openGiftCards(context);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final economy = ref.watch(economyConfigProvider).value;
    final data = ref.watch(playerDataProvider).value;
    if (economy == null || data == null) return const SizedBox.shrink();

    final now = ref.read(clockProvider)();
    final wait = data.giftWait(economy.hourlyGift, now);
    final ready = wait == Duration.zero;
    // While the last gift's extras are still on offer, it opens again.
    final reopens =
        !ready &&
        !(data.openGiftSession(economy.hourlyGift, now)?.isFinished ?? true);
    // Starting or stopping the ticker doesn't rebuild anything, so it's
    // safe to do while building.
    _tickWhile(!ready);

    final accent = Theme.of(context).colorScheme;
    return Semantics(
      button: ready || reopens,
      label: ready
          ? 'Hourly gift ready: tap to pick a card'
          : 'Next hourly gift in ${countdownText(wait)}'
                '${reopens ? ': tap for its extras' : ''}',
      excludeSemantics: true,
      child: Material(
        key: const Key('hourly-gift'),
        color: ready ? const Color(0xFFFFC107) : const Color(0x66000000),
        shape: const StadiumBorder(),
        elevation: ready ? 4 : 0,
        shadowColor: const Color(0xFFFFC107),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: (ready || reopens) && !_opening ? _open : null,
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
                // Extras still on offer from the last gift.
                if (reopens) ...[
                  const Icon(
                    Icons.play_circle,
                    key: Key('gift-extras-waiting'),
                    size: 16,
                    color: Color(0xFFFFC107),
                  ),
                  const SizedBox(width: 4),
                ],
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
