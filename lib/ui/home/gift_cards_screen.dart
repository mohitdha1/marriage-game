import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';
import '../../data/gift_session.dart';
import '../ads/rewarded_ad_service.dart';
import '../ads/watch_ad.dart';
import '../sound/sound_effects.dart';
import '../table/card_view.dart';
import '../theme/table_felt.dart';
import 'economy_config_provider.dart';
import 'home_screen.dart' show CoinIcon, GemIcon, formatCoins;
import 'player_data_provider.dart';

/// Opens the hourly gift's cards, finishing once the player leaves them.
Future<void> openGiftCards(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'gift_cards'),
    builder: (_) => const GiftCardsScreen(),
  ),
);

/// A reward as a line: "+500 coins", "+1 gem", or "+500 coins and 1 gem".
String rewardText(Reward reward) => '+${amountText(reward)}';

/// The hourly gift: ten face-down cards in two rows, in the current card
/// back. The player taps one, it turns over to show what it gave, and the
/// rest turn over to show what else was there. Rewarded ads then offer to
/// double the pick, pick another card, or add a bonus, each once until the
/// next gift. Every reward is saved the moment it's earned, before any
/// card turns, so leaving partway loses nothing and repeats nothing.
class GiftCardsScreen extends ConsumerStatefulWidget {
  const GiftCardsScreen({super.key});

  /// How long a card takes to turn over.
  static const flipTime = Duration(milliseconds: 450);

  /// How long the pick is shown alone before the rest turn over.
  static const revealPause = Duration(milliseconds: 900);

  /// The gap between the other cards turning over, one after another.
  static const flipStagger = Duration(milliseconds: 70);

  /// Every pause in turning the cards, together: once it has passed, the
  /// board has settled.
  static Duration get settleTime =>
      flipTime + revealPause + flipStagger * HourlyGift.boardSize + flipTime;

  @override
  ConsumerState<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends ConsumerState<GiftCardsScreen> {
  /// The cards showing their faces.
  final _faceUp = <int>{};

  /// The card celebrated last, and a count that replays the celebration.
  int? _celebrated;
  var _celebrations = 0;

  /// While cards are turning, or a reward is being saved.
  var _busy = false;

  /// After the ad for another card: waiting for the player to tap one.
  var _choosingExtra = false;

  @override
  void initState() {
    super.initState();
    // Opened on a gift collected earlier, every card shows its face.
    if (ref.read(playerDataProvider.notifier).openGiftSession() != null) {
      _faceUp.addAll(Iterable.generate(HourlyGift.boardSize));
    }
  }

  PlayerDataController get _controller => ref.read(playerDataProvider.notifier);

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  Future<void> _pause(Duration length) =>
      Future.delayed(_animate ? length : Duration.zero);

  /// A short note under the heading: what an extra gave, or why no ad
  /// could be shown. It sits clear of the buttons, unlike a snack bar.
  String? _note;

  void _say(String message) => setState(() => _note = message);

  /// Turns over the [card] just picked, celebrates it, then turns over the
  /// rest.
  Future<void> _reveal(int card) async {
    setState(() {
      _faceUp.add(card);
      _celebrated = card;
      _celebrations++;
    });
    ref.read(soundEffectsProvider).play(Sfx.jokerReveal);
    await _pause(GiftCardsScreen.flipTime + GiftCardsScreen.revealPause);
    for (var i = 0; i < HourlyGift.boardSize; i++) {
      if (!mounted) return;
      if (_faceUp.contains(i)) continue;
      setState(() => _faceUp.add(i));
      await _pause(GiftCardsScreen.flipStagger);
    }
    await _pause(GiftCardsScreen.flipTime);
  }

  Future<void> _tapCard(int card) async {
    if (_busy) return;
    _note = null;
    final session = _controller.openGiftSession();
    if (session != null && !_choosingExtra) return;
    setState(() => _busy = true);
    // Saved first, so the reward stands however the screen is left.
    final reward = session == null
        ? await _controller.collectGift(card)
        : await _controller.pickExtraGiftCard(card);
    if (!mounted) return;
    if (reward != null) {
      _choosingExtra = false;
      await _reveal(card);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Shows a rewarded ad, and returns whether it was watched to the end.
  /// Says why not when no ad could be shown.
  Future<bool> _watchAd() async {
    setState(() => _note = null);
    final result = await showRewardedAd(context, ref);
    if (!mounted) return false;
    switch (result) {
      case null:
        _say(noAdsLeftText);
      case AdResult.unavailable:
        _say(noAdText);
      case AdResult.watched || AdResult.skipped:
        break;
    }
    return result?.earned ?? false;
  }

  Future<void> _double(GiftSession session) async {
    if (_busy || !await _watchAd() || !mounted) return;
    final added = await _controller.doubleGift();
    if (!mounted || added == null) return;
    ref.read(soundEffectsProvider).play(Sfx.jokerReveal);
    setState(() {
      _celebrated = session.pick.card;
      _celebrations++;
    });
    _say('Doubled! ${rewardText(added)}');
  }

  Future<void> _anotherCard(GiftSession session) async {
    if (_busy || !await _watchAd() || !mounted) return;
    // Every card but those picked turns face down again, to choose from.
    setState(() {
      _choosingExtra = true;
      _faceUp
        ..clear()
        ..add(session.pick.card);
    });
  }

  Future<void> _bonus() async {
    if (_busy || !await _watchAd() || !mounted) return;
    final bonus = await _controller.claimGiftBonus();
    if (!mounted || bonus == null) return;
    ref.read(soundEffectsProvider).play(Sfx.jokerReveal);
    _say('Bonus! ${rewardText(bonus)}');
  }

  @override
  Widget build(BuildContext context) {
    final economy = ref.watch(economyConfigProvider).value;
    final data = ref.watch(playerDataProvider).value;
    if (economy == null || data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final gift = economy.hourlyGift;
    final now = ref.read(clockProvider)();
    final session = data.openGiftSession(gift, now);
    final ready = data.giftWait(gift, now) == Duration.zero;
    final board = switch (data.giftCollectedAt) {
      final at? when session != null => gift.board(at.millisecondsSinceEpoch),
      _ => null,
    };

    Reward? faceOf(int card) {
      if (session == null) return null;
      if (card == session.pick.card) {
        return session.doubled
            ? session.pick.reward.doubled
            : session.pick.reward;
      }
      if (session.extraPick case final extra? when extra.card == card) {
        return extra.reward;
      }
      return board?[card];
    }

    bool picked(int card) =>
        session != null &&
        (card == session.pick.card || card == session.extraPick?.card);

    final tappable = !_busy && (session == null ? ready : _choosingExtra);
    const white = TextStyle(color: Colors.white);

    return Scaffold(
      key: const Key('gift-cards'),
      body: TableFelt(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _heading(session, ready),
                            key: const Key('gift-heading'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_note case final note?)
                            Text(
                              note,
                              key: const Key('gift-note'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('gift-close'),
                      tooltip: 'Close',
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: _Board(
                    faceUp: _faceUp,
                    faceOf: faceOf,
                    picked: picked,
                    doubled: session?.doubled ?? false,
                    pickedFirst: session?.pick.card,
                    celebrated: _celebrated,
                    celebrations: _celebrations,
                    animate: _animate,
                    onTap: tappable ? _tapCard : null,
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: session == null || _choosingExtra || _busy
                      ? null
                      : _Extras(
                          session: session,
                          bonus: gift.bonus,
                          adsLeft: _controller.adsLeftToday(),
                          onDouble: () => _double(session),
                          onAnotherCard: () => _anotherCard(session),
                          onBonus: _bonus,
                          style: white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _heading(GiftSession? session, bool ready) {
    if (session == null) {
      return ready ? 'Hourly gift: pick a card' : 'Hourly gift';
    }
    if (_choosingExtra) return 'Pick one more card';
    final free = session.doubled
        ? session.pick.reward.doubled
        : session.pick.reward;
    final extra = session.extraPick?.reward ?? const Reward();
    final total = Reward(
      coins: free.coins + extra.coins,
      gems: free.gems + extra.gems,
    );
    return 'You got ${rewardText(total).substring(1)}';
  }
}

/// The ten cards, in two rows of five, as large as fits.
class _Board extends StatelessWidget {
  const _Board({
    required this.faceUp,
    required this.faceOf,
    required this.picked,
    required this.doubled,
    required this.pickedFirst,
    required this.celebrated,
    required this.celebrations,
    required this.animate,
    required this.onTap,
  });

  static const _gap = 10.0;
  static const _perRow = HourlyGift.boardSize ~/ 2;

  final Set<int> faceUp;
  final Reward? Function(int card) faceOf;
  final bool Function(int card) picked;
  final bool doubled;
  final int? pickedFirst;
  final int? celebrated;
  final int celebrations;
  final bool animate;

  /// Picks a card, or `null` while none can be picked.
  final void Function(int card)? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final byWidth = (constraints.maxWidth - _gap * (_perRow - 1)) / _perRow;
      final byHeight = (constraints.maxHeight - _gap * 3) / 2 * cardAspectRatio;
      final width = min(min(byWidth, byHeight), 120.0);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: _gap,
          children: [
            for (var row = 0; row < 2; row++)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: _gap,
                children: [
                  for (var i = row * _perRow; i < (row + 1) * _perRow; i++)
                    _GiftCard(
                      key: Key('gift-card-$i'),
                      index: i,
                      width: width,
                      faceUp: faceUp.contains(i),
                      reward: faceOf(i),
                      picked: picked(i),
                      doubled: doubled && i == pickedFirst,
                      celebrations: i == celebrated ? celebrations : 0,
                      animate: animate,
                      onTap: onTap == null || faceUp.contains(i)
                          ? null
                          : () => onTap!(i),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

/// One card of the gift, turning over between its back and the reward it
/// shows.
class _GiftCard extends StatelessWidget {
  const _GiftCard({
    super.key,
    required this.index,
    required this.width,
    required this.faceUp,
    required this.reward,
    required this.picked,
    required this.doubled,
    required this.celebrations,
    required this.animate,
    required this.onTap,
  });

  final int index;
  final double width;
  final bool faceUp;
  final Reward? reward;
  final bool picked;
  final bool doubled;

  /// Replays the celebration each time it goes up; 0 for none.
  final int celebrations;
  final bool animate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reward = this.reward;
    final face = reward == null
        ? CardSlot(width: width)
        : _RewardFace(
            reward: reward,
            width: width,
            picked: picked,
            doubled: doubled,
          );
    final card = TweenAnimationBuilder<double>(
      tween: Tween(end: faceUp ? 1 : 0),
      duration: animate ? GiftCardsScreen.flipTime : Duration.zero,
      curve: Curves.easeInOut,
      builder: (context, turn, _) {
        final showingFace = turn >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(pi * turn + (showingFace ? pi : 0)),
          child: showingFace ? face : CardBack(width: width),
        );
      },
    );
    return Semantics(
      button: onTap != null,
      label: faceUp && reward != null
          ? 'Card ${index + 1}: ${rewardText(reward).substring(1)}'
                '${picked ? ', yours' : ''}'
          : 'Card ${index + 1}, face down',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: _Celebration(
          key: ValueKey(celebrations),
          active: celebrations > 0 && animate,
          size: width,
          child: card,
        ),
      ),
    );
  }
}

/// A card's face: the coins or gems it holds. The cards the player picked
/// stand out in gold; the rest are dimmed.
class _RewardFace extends StatelessWidget {
  const _RewardFace({
    required this.reward,
    required this.width,
    required this.picked,
    required this.doubled,
  });

  final Reward reward;
  final double width;
  final bool picked;
  final bool doubled;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF263238);
    final icon = width * 0.36;
    final amount = reward.gems > 0
        ? '${reward.gems}'
        : formatCoins(reward.coins);
    return Opacity(
      opacity: picked ? 1 : 0.7,
      child: Container(
        width: width,
        height: width / cardAspectRatio,
        decoration: BoxDecoration(
          color: picked ? const Color(0xFFFFF8E1) : Colors.white,
          borderRadius: BorderRadius.circular(width * 0.1),
          border: Border.all(
            color: picked ? const Color(0xFFFFB300) : const Color(0xFFB0BEC5),
            width: picked ? 3 : 1,
          ),
          boxShadow: [
            if (picked)
              const BoxShadow(color: Color(0x99FFC107), blurRadius: 14),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(width * 0.08),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reward.gems > 0)
                  GemIcon(size: icon)
                else
                  CoinIcon(size: icon),
                const SizedBox(height: 6),
                Text(
                  amount,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  reward.gems > 0
                      ? (reward.gems == 1 ? 'gem' : 'gems')
                      : 'coins',
                  style: const TextStyle(color: ink, fontSize: 13),
                ),
                if (doubled)
                  const Text(
                    '×2',
                    key: Key('gift-doubled'),
                    style: TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
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

/// A small burst of gold sparks round [child], with a little bounce, played
/// once when [active].
class _Celebration extends StatelessWidget {
  const _Celebration({
    super.key,
    required this.active,
    required this.size,
    required this.child,
  });

  final bool active;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: GiftCardsScreen.flipTime + GiftCardsScreen.revealPause,
      builder: (context, t, child) {
        // The sparks start as the card shows its face.
        final burst = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
        final bounce = 1 + 0.12 * sin(pi * burst);
        return CustomPaint(
          foregroundPainter: _SparksPainter(burst),
          child: Transform.scale(scale: bounce, child: child),
        );
      },
      child: child,
    );
  }
}

class _SparksPainter extends CustomPainter {
  const _SparksPainter(this.progress);

  /// From 0, before the burst, to 1, once it has faded.
  final double progress;

  static const _sparks = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final reach = size.longestSide * (0.45 + 0.4 * progress);
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFFD54F),
        const Color(0x00FFD54F),
        progress,
      )!;
    for (var i = 0; i < _sparks; i++) {
      final angle = 2 * pi * i / _sparks;
      final at = center + Offset(cos(angle), sin(angle)) * reach;
      canvas.drawCircle(at, 3.5 * (1 - progress) + 1, paint);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => old.progress != progress;
}

/// The rewarded-ad extras, each shown until it's taken.
class _Extras extends StatelessWidget {
  const _Extras({
    required this.session,
    required this.bonus,
    required this.adsLeft,
    required this.onDouble,
    required this.onAnotherCard,
    required this.onBonus,
    required this.style,
  });

  final GiftSession session;
  final Reward bonus;
  final int adsLeft;
  final VoidCallback onDouble;
  final VoidCallback onAnotherCard;
  final VoidCallback onBonus;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (session.isFinished) {
      return Center(child: Text('Come back for the next gift!', style: style));
    }
    Widget offer(String key, String label, VoidCallback onPressed) =>
        FilledButton.icon(
          key: Key(key),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: const Color(0xFF1A1A1A),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.play_circle_outline, size: 20),
          label: Text(label),
        );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          if (!session.doubled)
            offer('gift-double', 'Watch an ad to double it', onDouble),
          if (session.extraPick == null)
            offer(
              'gift-another',
              'Watch an ad to pick another card',
              onAnotherCard,
            ),
          if (!session.bonusTaken)
            offer(
              'gift-bonus',
              'Watch an ad for a bonus (${rewardText(bonus).substring(1)})',
              onBonus,
            ),
          Text(
            adsLeft == 0 ? 'No ads left today' : _adsLeft(adsLeft),
            key: const Key('gift-ads-left'),
            style: style.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// How many ads are left today: "3 ads left today".
String _adsLeft(int left) => '$left ${left == 1 ? 'ad' : 'ads'} left today';
