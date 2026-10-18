import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_data.dart';
import '../../data/stake_tables.dart';
import '../settings/house_rules_screen.dart';
import '../settings/settings.dart';
import '../state/table_controller.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';
import 'game_setup.dart';
import 'home_screen.dart';
import 'mode_picker.dart';
import 'player_data_provider.dart';
import 'stake_tables_provider.dart';

/// [coins] written short, as on a stake tile: 5, 250, 1K, 2.5K, 100K, 10M.
String formatStake(int coins) {
  String short(double value, String unit) => value == value.roundToDouble()
      ? '${value.round()}$unit'
      : '${value.toStringAsFixed(1)}$unit';
  if (coins >= 1000000) return short(coins / 1000000, 'M');
  if (coins >= 1000) return short(coins / 1000, 'K');
  return '$coins';
}

/// The table Quick Play deals: the last one chosen, if the player can still
/// join it, or else the highest below it they can, and five players, by the
/// rules last chosen.
MatchSetup quickPlaySetupFor(
  StakeTables tables,
  Settings settings,
  PlayerData data,
) {
  var table = tables.tiers.first;
  for (final tier in tables.tiers) {
    if (tier.stake > settings.stake) break;
    if (tables.canJoin(tier, data)) table = tier;
  }
  return MatchSetup.atTable(table, rules: settings.rules);
}

/// Why [data]'s player can't sit down at [tier] yet, or `null` if they can.
String? whyNotJoin(StakeTables tables, StakeTable tier, PlayerData data) {
  if (tables.unlockProgress(tier, data) case (:final played, :final needed)) {
    final below = formatStake(tables.below(tier)!.stake);
    final left = needed - played;
    return 'Play $left more ${left == 1 ? 'game' : 'games'} at the $below '
        'table to unlock it.';
  }
  if (data.coins < tier.minBalance) {
    return 'Needs ${formatCoins(tier.minBalance)} coins to join.';
  }
  return null;
}

/// Single player: a row of stake tables to choose from, each with its stake
/// and minimum balance, and a lock with progress until it's unlocked; then
/// the mode, how many play, and Play, with a line on the mode beneath. [onPlay] starts the match.
class StakeTablePickerScreen extends ConsumerWidget {
  const StakeTablePickerScreen({super.key, required this.onPlay});

  final ValueChanged<MatchSetup> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(stakeTablesProvider).value;
    final data = ref.watch(playerDataProvider).value;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Single Player'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          const HouseRulesButton(onDark: true),
          if (data != null) ...[
            GemPill(gems: data.gems),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CoinPill(coins: data.coins),
            ),
          ],
        ],
      ),
      body: TableFelt(
        child: SafeArea(
          child: tables == null || data == null
              ? const Center(child: CircularProgressIndicator())
              : _Picker(
                  tables: tables,
                  data: data,
                  settings: settings,
                  onPlay: onPlay,
                ),
        ),
      ),
    );
  }
}

class _Picker extends ConsumerWidget {
  const _Picker({
    required this.tables,
    required this.data,
    required this.settings,
    required this.onPlay,
  });

  final StakeTables tables;
  final PlayerData data;
  final Settings settings;
  final ValueChanged<MatchSetup> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsProvider.notifier);
    final chosen = tables.withStake(settings.stake) ?? tables.tiers.first;
    final reason = whyNotJoin(tables, chosen, data);
    const white = TextStyle(color: Colors.white);

    return Column(
      children: [
        const SizedBox(height: 8),
        _TileRow(
          tables: tables,
          data: data,
          chosen: chosen,
          onChoose: (tier) => controller.setStake(tier.stake),
        ),
        const Spacer(),
        // One line, shrinking to fit a narrow screen.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Each point is worth ${formatCoins(chosen.stake)} coins · '
            '${describeDifficulty(chosen.difficulty)}',
            key: const Key('stake-summary'),
            maxLines: 1,
            style: white,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 24,
          runSpacing: 8,
          children: [
            const ModePicker(onDark: true, describe: false),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                const Text('Players', style: white),
                const SizedBox(width: 4),
                for (
                  var count = Settings.minPlayers;
                  count <= Settings.maxPlayers;
                  count++
                )
                  ChoiceChip(
                    key: Key('players-$count'),
                    label: Text('$count'),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selected: settings.playerCount == count,
                    onSelected: (_) => controller.setPlayerCount(count),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('setup-play'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E9E44),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          ),
          onPressed: reason != null
              ? null
              : () => onPlay(
                  MatchSetup.atTable(
                    chosen,
                    playerCount: settings.playerCount,
                    rules: settings.rules,
                  ),
                ),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            'Play',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        // Why the table is locked, or else what the chosen mode means.
        SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: reason == null
                  ? ModeDescription(mode: settings.rules.mode, onDark: true)
                  : Text(
                      reason,
                      key: const Key('stake-locked-reason'),
                      style: TextStyle(color: TableTheme.of(context).accent),
                    ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// The stake tables side by side, scrolling sideways, opening on the
/// chosen one.
class _TileRow extends StatefulWidget {
  const _TileRow({
    required this.tables,
    required this.data,
    required this.chosen,
    required this.onChoose,
  });

  final StakeTables tables;
  final PlayerData data;
  final StakeTable chosen;
  final ValueChanged<StakeTable> onChoose;

  @override
  State<_TileRow> createState() => _TileRowState();
}

class _TileRowState extends State<_TileRow> {
  static const _tileWidth = 116.0;
  static const _gap = 10.0;

  // Opens with the tile before the chosen one in view too, so the table
  // just below shows.
  late final _scroll = ScrollController(
    initialScrollOffset:
        (widget.tables.tiers.indexOf(widget.chosen) - 1).clamp(0, 1 << 20) *
        (_tileWidth + _gap),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: ListView.separated(
      key: const Key('stake-tiles'),
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.tables.tiers.length,
      separatorBuilder: (_, _) => const SizedBox(width: _gap),
      itemBuilder: (context, i) {
        final tier = widget.tables.tiers[i];
        return _StakeTile(
          tier: tier,
          progress: widget.tables.unlockProgress(tier, widget.data),
          affordable: widget.data.coins >= tier.minBalance,
          chosen: tier == widget.chosen,
          width: _tileWidth,
          onTap: () => widget.onChoose(tier),
        );
      },
    ),
  );
}

/// One stake table: its stake, and below it the minimum balance, or a lock
/// with the games played toward unlocking it.
class _StakeTile extends StatelessWidget {
  const _StakeTile({
    required this.tier,
    required this.progress,
    required this.affordable,
    required this.chosen,
    required this.width,
    required this.onTap,
  });

  final StakeTable tier;
  final ({int played, int needed})? progress;
  final bool affordable;
  final bool chosen;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = progress != null;
    final background = chosen
        ? const Color(0xFF8EE4AF)
        : locked
        ? const Color(0xFFB0BEC5)
        : const Color(0xFFF1F4FF);
    const ink = Color(0xFF263238);
    const small = TextStyle(color: ink, fontSize: 12);

    return Semantics(
      button: true,
      selected: chosen,
      label:
          '${formatStake(tier.stake)} coins a point'
          '${locked ? ', locked' : ''}',
      child: GestureDetector(
        key: Key('stake-${tier.stake}'),
        onTap: onTap,
        child: Container(
          width: width,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen ? const Color(0xFF2E7D32) : const Color(0xFF1A237E),
              width: chosen ? 3 : 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          // Each line shrinks to fit the tile, whatever the text size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 22),
                    const SizedBox(width: 6),
                    Text(
                      formatStake(tier.stake),
                      style: TextStyle(
                        color: locked ? ink.withValues(alpha: 0.6) : ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tier.minBalance == 0
                      ? 'Open to all'
                      : 'Min ${formatStake(tier.minBalance)}',
                  key: Key('stake-${tier.stake}-min'),
                  style: small.copyWith(
                    color: affordable ? ink : const Color(0xFFC62828),
                    fontWeight: affordable ? null : FontWeight.w700,
                  ),
                ),
                if (progress case (:final played, :final needed))
                  Row(
                    key: Key('stake-${tier.stake}-lock'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: ink),
                      const SizedBox(width: 3),
                      Text('$played/$needed games', style: small),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
