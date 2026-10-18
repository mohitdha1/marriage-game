import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/saved_match.dart';
import '../../engine/card.dart';
import '../haptics/table_haptics.dart';
import '../lobby/host_lobby_screen.dart';
import '../lobby/join_screen.dart';
import '../lobby/play_with_friends.dart';
import '../settings/profile_dialog.dart';
import '../settings/settings.dart';
import '../settings/settings_popover.dart';
import '../sound/table_sounds.dart';
import '../state/table_controller.dart';
import '../table/suit_icon.dart';
import '../table/table_screen.dart';
import '../theme/table_felt.dart';
import '../../data/economy_config.dart';
import '../shop/shop_sheet.dart';
import 'player_data_provider.dart';
import 'economy_config_provider.dart';
import 'entry_fee.dart';
import 'game_setup.dart';
import 'hourly_gift_button.dart';
import 'stake_table_picker.dart';
import 'stake_tables_provider.dart';
import 'pass_and_play_setup.dart';
import 'player_avatar.dart';
import '../../data/player_profile.dart';

/// The table for a game against bots, with its sounds and vibration, asking
/// before the back gesture leaves a round in progress.
/// back gesture leaves a round in progress.
const singlePlayerTable = TableSounds(
  child: TableHaptics(child: LeaveGuard(child: TableScreen())),
);

/// The first screen: the player's avatar and name, the hourly gift, gems
/// and coins along the top, a settings gear, a large tile for each way to
/// play (Single Player sets up a custom game), and a Quick Play button that
/// starts a game against bots straight away. A match left unfinished can be
/// picked up with the Continue button beside it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final playerData = ref.watch(playerDataProvider).value;
    final coins = playerData?.coins;
    final stakeTables = ref.watch(stakeTablesProvider).value;
    final saved = ref.watch(savedMatchProvider);
    final economy = ref.watch(economyConfigProvider).value;
    // Quick Play deals the stake table last chosen, once the tables and the
    // player's coins have loaded.
    final quickPlay = stakeTables == null || playerData == null
        ? null
        : quickPlaySetupFor(stakeTables, settings, playerData);

    return Scaffold(
      body: TableFelt(
        child: Stack(
          children: [
            const Positioned.fill(child: _SuitBackdrop()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PlayerBadge(
                          name:
                              playerData?.profile.name ??
                              PlayerProfile.defaultName,
                          look: playerData?.profile.look,
                          onTap: () => showProfileDialog(context),
                        ),
                        const Spacer(),
                        const HourlyGiftButton(),
                        const SizedBox(width: 8),
                        GemPill(
                          gems: playerData?.gems,
                          onTap: () => openShop(context, tab: Currency.gems),
                        ),
                        const SizedBox(width: 8),
                        CoinPill(coins: coins, onTap: () => openShop(context)),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: const Key('settings-button'),
                          tooltip: 'Settings',
                          onPressed: () => showSettingsPopover(context),
                          icon: const Icon(Icons.settings),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 24,
                                runSpacing: 16,
                                alignment: WrapAlignment.center,
                                children: [
                                  _ModeTile(
                                    key: const Key('single-player'),
                                    title: 'Single Player',
                                    subtitle: 'Choose your stake table',
                                    icon: Icons.smart_toy_outlined,
                                    colors: const [
                                      Color(0xFFFFB300),
                                      Color(0xFFF57C00),
                                    ],
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        settings: const RouteSettings(
                                          name: 'stake_tables',
                                        ),
                                        builder: (pickerContext) =>
                                            StakeTablePickerScreen(
                                              onPlay: (setup) async {
                                                // Short of gems, the player
                                                // stays on the picker.
                                                if (!await payEntryFee(
                                                      pickerContext,
                                                      ref,
                                                      setup.stake,
                                                    ) ||
                                                    !pickerContext.mounted ||
                                                    !context.mounted) {
                                                  return;
                                                }
                                                Navigator.of(
                                                  pickerContext,
                                                ).pop();
                                                _startMatch(
                                                  context,
                                                  ref,
                                                  setup,
                                                );
                                              },
                                            ),
                                      ),
                                    ),
                                  ),
                                  _ModeTile(
                                    key: const Key('friends'),
                                    title: 'Play with Friends',
                                    subtitle: 'On this device, or over Wi-Fi',
                                    icon: Icons.groups_outlined,
                                    colors: const [
                                      Color(0xFF7E57C2),
                                      Color(0xFF3949AB),
                                    ],
                                    onTap: () => _playWithFriends(context, ref),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (saved != null)
                                    _ContinueButton(
                                      match: describeSavedMatch(saved),
                                      onPressed: () =>
                                          _continueMatch(context, ref, saved),
                                    ),
                                  _QuickPlayButton(
                                    setup: quickPlay == null
                                        ? ''
                                        : [
                                            describeSetup(quickPlay),
                                            if (economy?.entryFee.gemsFor(
                                                  quickPlay.stake,
                                                )
                                                case final gems? when gems > 0)
                                              gemsText(gems),
                                          ].join(' · '),
                                    onPressed: quickPlay == null
                                        ? null
                                        : () async {
                                            if (await payEntryFee(
                                                  context,
                                                  ref,
                                                  quickPlay.stake,
                                                ) &&
                                                context.mounted) {
                                              _startMatch(
                                                context,
                                                ref,
                                                quickPlay,
                                              );
                                            }
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks how to play with friends, then sets that up.
  Future<void> _playWithFriends(BuildContext context, WidgetRef ref) async {
    final mode = await showPlayWithFriends(context);
    if (mode == null || !context.mounted) return;
    switch (mode) {
      case FriendsMode.passAndPlay:
        final names = await showPassAndPlaySetup(context);
        if (names != null && context.mounted) {
          _startMatch(context, ref, MatchSetup.passAndPlay(names));
        }
      case FriendsMode.host:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'host_lobby'),
            builder: (_) => const HostLobbyScreen(),
          ),
        );
      case FriendsMode.join:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'join'),
            builder: (_) => const JoinScreen(),
          ),
        );
    }
  }

  /// Opens a fresh match with [setup], its entry fee already paid, under the house rules in settings.
  void _startMatch(BuildContext context, WidgetRef ref, MatchSetup setup) {
    final settings = ref.read(settingsProvider);
    startMatchWith(ref, setup.withRules(settings.rules));
    _openTable(context);
  }

  /// Opens the [saved] match where it was left.
  void _continueMatch(BuildContext context, WidgetRef ref, SavedMatch saved) {
    resumeMatch(ref, saved);
    _openTable(context);
  }

  void _openTable(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'table'),
        builder: (_) => singlePlayerTable,
      ),
    );
  }
}

/// Picks up the match left unfinished, named underneath.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.match, required this.onPressed});

  final String match;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('continue-match'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x33000000),
        side: const BorderSide(color: Colors.white, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.replay_rounded, size: 26),
              SizedBox(width: 6),
              Text(
                'Continue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Text(
            match,
            key: const Key('continue-match-setup'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The big button that starts a game against bots straight away, with the
/// default setup named underneath.
class _QuickPlayButton extends StatelessWidget {
  const _QuickPlayButton({required this.setup, required this.onPressed});

  final String setup;

  /// Starts the game, or `null` while the stake tables load.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // The same soft drop shadow as the mode tiles above it.
    final button = FilledButton(
      key: const Key('quick-play'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFC400),
        foregroundColor: const Color(0xFF3E2723),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 28),
              SizedBox(width: 4),
              Text(
                'Quick Play',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Text(
            setup,
            key: const Key('quick-play-setup'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: button,
    );
  }
}

/// The player's avatar and name. Tapping it opens their profile.
class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.name,
    required this.look,
    required this.onTap,
  });

  final String name;
  final int? look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('player-badge'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(name: name, look: look, radius: 20),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coin balance in a pill, with a drawn coin. Given [onTap], it's a
/// button with a "+" that opens the shop.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, this.onTap});

  /// The balance, or `null` while it loads.
  final int? coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _BalancePill(
    key: const Key('coin-balance'),
    plusKey: const Key('coin-plus'),
    icon: const CoinIcon(size: 22),
    balance: coins,
    unit: 'coins',
    onTap: onTap,
  );
}

/// The gem balance in a pill, with a drawn gem. Given [onTap], it's a
/// button with a "+" that opens the shop.
class GemPill extends StatelessWidget {
  const GemPill({super.key, required this.gems, this.onTap});

  /// The balance, or `null` while it loads.
  final int? gems;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _BalancePill(
    key: const Key('gem-balance'),
    plusKey: const Key('gem-plus'),
    icon: const GemIcon(size: 22),
    balance: gems,
    unit: 'gems',
    onTap: onTap,
  );
}

/// A balance in a pill. When it changes, the number counts to the new
/// balance and the icon swells while it does, so a reward is seen arriving.
class _BalancePill extends StatelessWidget {
  const _BalancePill({
    super.key,
    required this.plusKey,
    required this.icon,
    required this.balance,
    required this.unit,
    required this.onTap,
  });

  /// How long the count takes.
  static const countTime = Duration(milliseconds: 900);

  final Key plusKey;
  final Widget icon;
  final int? balance;

  /// What the balance counts, for screen readers: "10,255 coins".
  final String unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final balance = this.balance;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final pill = Container(
      padding: EdgeInsets.fromLTRB(6, 4, onTap == null ? 12 : 4, 4),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: balance == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [icon, const SizedBox(width: 6), _number('…')],
            )
          : TweenAnimationBuilder<int>(
              // Only the end matters after the first build: a new balance
              // counts on from wherever the number is showing.
              tween: IntTween(begin: balance, end: balance),
              duration: animate ? countTime : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, shown, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: shown == balance ? 1 : 1.25,
                    duration: const Duration(milliseconds: 150),
                    child: icon,
                  ),
                  const SizedBox(width: 6),
                  _number(formatCoins(shown)),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: plusKey,
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF43A047),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
    return Semantics(
      label: balance == null ? null : '${formatCoins(balance)} $unit',
      hint: onTap == null ? null : 'Opens the shop',
      button: onTap != null,
      excludeSemantics: balance != null,
      child: onTap == null
          ? pill
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: pill,
              ),
            ),
    );
  }

  Widget _number(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

/// [coins] with thousands separated by commas: 12,345.
String formatCoins(int coins) {
  final digits = coins.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${coins < 0 ? '-' : ''}$grouped';
}

/// A simple gold coin.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
        ),
        border: Border.all(color: const Color(0xFFB8860B), width: size * 0.08),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.45,
        height: size * 0.45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFB8860B),
            width: size * 0.06,
          ),
        ),
      ),
    );
  }
}

/// A simple cut gem: a flat top, sloping crown and pointed base, in shades
/// of violet so it reads apart from the gold coin.
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GemPainter());
}

class _GemPainter extends CustomPainter {
  const _GemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The outline's corners: the table (top edge), the girdle (widest
    // line) and the point.
    final tableLeft = Offset(w * 0.3, h * 0.15);
    final tableRight = Offset(w * 0.7, h * 0.15);
    final girdleLeft = Offset(w * 0.05, h * 0.4);
    final girdleRight = Offset(w * 0.95, h * 0.4);
    final point = Offset(w * 0.5, h * 0.92);

    Path shape(List<Offset> corners) => Path()..addPolygon(corners, true);
    final crown = shape([tableLeft, tableRight, girdleRight, girdleLeft]);
    final pavilion = shape([girdleLeft, girdleRight, point]);
    canvas
      ..drawPath(crown, Paint()..color = const Color(0xFFCE93D8))
      ..drawPath(pavilion, Paint()..color = const Color(0xFF8E24AA))
      // A lighter facet down the middle of the base catches the light.
      ..drawPath(
        shape([Offset(w * 0.35, h * 0.4), Offset(w * 0.65, h * 0.4), point]),
        Paint()..color = const Color(0xFFAB47BC),
      );
    final edge = Paint()
      ..color = const Color(0xFF4A148C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        shape([tableLeft, tableRight, girdleRight, point, girdleLeft]),
        edge,
      )
      ..drawLine(girdleLeft, girdleRight, edge);
  }

  @override
  bool shouldRepaint(_GemPainter oldDelegate) => false;
}

/// A large, tappable tile for one way to play.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 230,
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(onTap: onTap, child: tile),
    );
  }
}

/// Large, faint card suits scattered behind the home screen.
class _SuitBackdrop extends StatelessWidget {
  const _SuitBackdrop();

  @override
  Widget build(BuildContext context) {
    const faint = Color(0x14FFFFFF);
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -30,
            bottom: -40,
            child: SuitIcon(Suit.spades, size: 220, color: faint),
          ),
          Positioned(
            right: 40,
            top: 60,
            child: SuitIcon(Suit.hearts, size: 140, color: faint),
          ),
          Positioned(
            right: -40,
            bottom: -30,
            child: SuitIcon(Suit.clubs, size: 200, color: faint),
          ),
          Positioned(
            left: 180,
            top: 40,
            child: SuitIcon(Suit.diamonds, size: 90, color: faint),
          ),
        ],
      ),
    );
  }
}
