import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/scoring.dart';
import '../home/entry_fee.dart';
import '../state/table_controller.dart';
import '../table/win_celebration.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';
import 'scoreboard_screen.dart' show signed;

/// The end of a match: a banner naming the winner, then how the match went
/// (rounds played, the player's coins or points, their best round) and where
/// everyone finished. Rematch starts a new match at the same table with the
/// same players and rules, for the table's entry fee; Home goes back to the home screen.
///
/// When several people share the device, the summary is the table's rather
/// than one player's.
class ResultsScreen extends ConsumerWidget {
  /// Height kept clear at the top for the winner banner.
  static const _bannerRoom = 88.0;

  const ResultsScreen({
    super.key,
    required this.summary,
    required this.names,
    required this.you,
    this.stake,
    this.sharesDevice = false,
  });

  final MatchSummary summary;
  final List<String> names;

  /// The seat of the person holding the device.
  final int you;

  /// Coins per point, at a stake table.
  final int? stake;

  final bool sharesDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tableProvider.notifier);
    final youWon = sharesDevice || summary.winners.contains(you);
    final text = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: Colors.white);

    void goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

    return PopScope(
      // Back leads home too: the table behind has no match left on it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        body: TableFelt(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Room for the banner, which the celebration draws.
                    const SizedBox(height: _bannerRoom),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final summaryColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (key, line) in summaryLines(
                                summary,
                                names: names,
                                you: you,
                                stake: stake,
                                sharesDevice: sharesDevice,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(line, key: Key(key), style: text),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 12,
                                children: [
                                  OutlinedButton(
                                    key: const Key('results-home'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    onPressed: goHome,
                                    child: const Text('Home'),
                                  ),
                                  if (controller.canStartNewMatch)
                                    FilledButton(
                                      key: const Key('rematch'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: TableTheme.of(
                                          context,
                                        ).accent,
                                        foregroundColor: const Color(
                                          0xFF1A1A1A,
                                        ),
                                      ),
                                      onPressed: () async {
                                        // A rematch is a new match, with
                                        // its own entry fee.
                                        if (!await payEntryFee(
                                              context,
                                              ref,
                                              controller.stake,
                                            ) ||
                                            !context.mounted) {
                                          return;
                                        }
                                        controller.startNewMatch();
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Rematch'),
                                    ),
                                ],
                              ),
                            ],
                          );
                          final standings = _Standings(
                            summary: summary,
                            names: names,
                          );
                          // Side by side when there's room, as on a phone
                          // held sideways, so nothing needs scrolling.
                          final wide = constraints.maxWidth >= 560;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        spacing: 24,
                                        children: [
                                          Expanded(child: summaryColumn),
                                          Expanded(child: standings),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        spacing: 16,
                                        children: [summaryColumn, standings],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  top: 12,
                  child: WinCelebration(
                    winnerName: names[summary.winners.first],
                    youWon: youWon,
                    title: winnerTitle(
                      summary,
                      names: names,
                      you: sharesDevice ? null : you,
                    ),
                    alignment: Alignment.topCenter,
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

/// The results banner: who won the match, or who tied for it. [you] is the
/// seat of the person holding the device, or `null` when several share it.
String winnerTitle(
  MatchSummary summary, {
  required List<String> names,
  int? you,
}) {
  final winners = summary.winners;
  if (you != null && winners.contains(you)) {
    return winners.length == 1 ? 'You win the match!' : 'You tie for the win!';
  }
  if (winners.length == 1) return '${names[winners.single]} wins the match!';
  final named = [for (final seat in winners) names[seat]];
  final list =
      '${named.sublist(0, named.length - 1).join(', ')} and ${named.last}';
  return '$list tie for the win!';
}

/// The summary under the banner, each line with a key: rounds played, then
/// the player's coins (or points, without a [stake]) and best round. When
/// several people share the device, the best round anyone had instead.
List<(String, String)> summaryLines(
  MatchSummary summary, {
  required List<String> names,
  required int you,
  int? stake,
  bool sharesDevice = false,
}) {
  final rounds = summary.roundsPlayed;
  String round(BestRound best) =>
      '${signed(best.points)} in round ${best.round}';
  return [
    ('rounds-played', 'Rounds played: $rounds'),
    if (!sharesDevice) ...[
      if (stake case final stake?)
        ('your-result', 'Coins: ${signed(summary.coinsOf(you, stake))}')
      else
        ('your-result', 'Points: ${signed(summary.totals[you])}'),
      ('best-round', 'Your best round: ${round(summary.bestRoundOf(you))}'),
    ] else
      (
        'best-round',
        'Best round: ${names[summary.bestRound.seat]}, '
            '${round(summary.bestRound)}',
      ),
  ];
}

/// Where everyone finished: names and match totals, highest first.
class _Standings extends StatelessWidget {
  const _Standings({required this.summary, required this.names});

  final MatchSummary summary;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    final order = [for (var seat = 0; seat < names.length; seat++) seat]
      ..sort((a, b) => summary.totals[b].compareTo(summary.totals[a]));
    return DecoratedBox(
      key: const Key('standings'),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final seat in order)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        names[seat],
                        style: TextStyle(
                          color: summary.winners.contains(seat)
                              ? theme.accent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      signed(summary.totals[seat]),
                      key: Key('standing-$seat'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
