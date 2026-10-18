import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../ads/rewarded_ad_service.dart';
import '../ads/watch_ad.dart';
import '../home/economy_config_provider.dart';
import '../home/home_screen.dart' show CoinIcon, CoinPill, GemIcon, GemPill;
import '../home/player_data_provider.dart';
import 'purchase_service.dart';

/// Opens the shop over [context] as a sheet from the bottom, on the [tab]
/// for that currency, finishing once it's closed. Never opened during a
/// hand: only screens away from the table offer it.
Future<void> openShop(BuildContext context, {Currency tab = Currency.coins}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 760),
      routeSettings: const RouteSettings(name: 'shop'),
      builder: (_) => ShopSheet(tab: tab),
    );

/// The shop: a tab for coins and one for gems. Each starts with a rewarded
/// ad for that currency, with how many are left today, then the packs on
/// sale. Every coin and gem it gives goes through the player's data.
class ShopSheet extends ConsumerStatefulWidget {
  const ShopSheet({super.key, this.tab = Currency.coins});

  /// The tab it opens on.
  final Currency tab;

  @override
  ConsumerState<ShopSheet> createState() => _ShopSheetState();
}

class _ShopSheetState extends ConsumerState<ShopSheet>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: Currency.values.length,
    initialIndex: widget.tab.index,
    vsync: this,
  )..addListener(() => setState(() => _note = null));

  /// A short note on what was just given, or why not.
  String? _note;

  /// Whether an ad failed to show, when the offer stays greyed out.
  var _noAd = false;

  var _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Currency get _currency => Currency.values[_tabs.index];

  PlayerDataController get _controller => ref.read(playerDataProvider.notifier);

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final note = await action();
    if (mounted) {
      setState(() {
        _busy = false;
        _note = note;
      });
    }
  }

  Future<void> _watchAd() => _run(() async {
    final currency = _currency;
    final result = await showRewardedAd(context, ref);
    switch (result) {
      case null:
        return noAdsLeftText;
      case AdResult.unavailable:
        _noAd = true;
        return noAdText;
      case AdResult.skipped:
        return null;
      case AdResult.watched:
        final reward = await _controller.claimAdReward(currency);
        return reward == null ? noAdsLeftText : '+${amountText(reward)}';
    }
  });

  Future<void> _buy(ShopPack pack) => _run(() async {
    switch (await ref.read(purchaseServiceProvider).buy(pack)) {
      case PurchaseResult.purchased:
        await _controller.addPurchase(pack);
        return '+${amountText(pack.reward)}';
      case PurchaseResult.cancelled:
        return null;
      case PurchaseResult.unavailable:
        return 'Purchases aren\'t available right now.';
    }
  });

  @override
  Widget build(BuildContext context) {
    final economy = ref.watch(economyConfigProvider).value;
    final data = ref.watch(playerDataProvider).value;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      key: const Key('shop'),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Text('Shop', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              GemPill(gems: data?.gems),
              CoinPill(coins: data?.coins),
              IconButton(
                key: const Key('shop-close'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(
                key: Key('shop-tab-coins'),
                height: 40,
                icon: CoinIcon(size: 18),
                iconMargin: EdgeInsets.zero,
                text: 'Coins',
              ),
              Tab(
                key: Key('shop-tab-gems'),
                height: 40,
                icon: GemIcon(size: 18),
                iconMargin: EdgeInsets.zero,
                text: 'Gems',
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: Center(
              child: _note == null
                  ? null
                  : Text(
                      _note!,
                      key: const Key('shop-note'),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (economy == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            _AdOffer(
              reward: economy.rewardedAd.rewardIn(_currency),
              adsLeft: _controller.adsLeftToday(),
              noAd: _noAd,
              onWatch: _busy ? null : _watchAd,
            ),
            const SizedBox(height: 12),
            Row(
              key: Key('shop-packs-${_currency.name}'),
              spacing: 12,
              children: [
                for (final pack in economy.shop.packsOf(_currency))
                  Expanded(
                    child: _PackCard(
                      pack: pack,
                      canBuy: ref.read(purchaseServiceProvider).canPurchase,
                      onBuy: _busy ? null : () => _buy(pack),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The rewarded ad at the top of a tab: greyed out, saying why, once the
/// day's are used up or when none could be shown.
class _AdOffer extends StatelessWidget {
  const _AdOffer({
    required this.reward,
    required this.adsLeft,
    required this.noAd,
    required this.onWatch,
  });

  final Reward reward;
  final int adsLeft;
  final bool noAd;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    final why = adsLeft == 0 ? noAdsLeftText : (noAd ? noAdText : null);
    return Row(
      spacing: 12,
      children: [
        FilledButton.icon(
          key: const Key('shop-ad'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: const Color(0xFF1A1A1A),
          ),
          onPressed: why == null ? onWatch : null,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(adOfferText(reward)),
        ),
        Flexible(
          child: Text(
            why ?? adsLeftText(adsLeft),
            key: const Key('shop-ads-left'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A pack on sale: what it gives and its price, or "Coming soon" while
/// nothing can be bought.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.canBuy,
    required this.onBuy,
  });

  final ShopPack pack;
  final bool canBuy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final gems = pack.reward.gems > 0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gems) const GemIcon(size: 30) else const CoinIcon(size: 30),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amountText(pack.reward),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: Key('buy-${pack.id}'),
              onPressed: canBuy ? onBuy : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(canBuy ? pack.price : 'Coming soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
