import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/scoring.dart';
import '../state/table_controller.dart';
import '../state/table_state.dart';

/// The match's scores: a line-by-line breakdown of one round (the latest by
/// default; earlier rounds can be picked), and every player's result for
/// each round with running totals.
///
/// Once the current round is over, Next round deals the next one and returns
/// to the table.
class ScoreboardScreen extends ConsumerStatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  ConsumerState<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends ConsumerState<ScoreboardScreen> {
  /// Which round's breakdown to show, or `null` for the latest.
  int? _shownRound;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tableProvider);
    final rounds = state.roundScores;
    final roundOver = state.view.winner != null;
    final shown = _shownRound ?? rounds.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
        toolbarHeight: 44,
        actions: [
          if (roundOver)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('next-round-button'),
                onPressed: () {
                  ref.read(tableProvider.notifier).startNextRound();
                  Navigator.of(context).pop();
                },
                child: const Text('Next round'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: rounds.isEmpty
            ? const Center(child: Text('No rounds finished yet.'))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (rounds.length > 1)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 0; i < rounds.length; i++)
                          ChoiceChip(
                            key: Key('round-chip-${i + 1}'),
                            label: Text('Round ${i + 1}'),
                            selected: i == shown,
                            onSelected: (_) => setState(() => _shownRound = i),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Round ${shown + 1}: '
                    '${state.seatNames[rounds[shown].winner]} won'
                    '${rounds[shown].wonWithDoublees ? ' with doublees' : ''}',
                    key: const Key('round-title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  RoundBreakdownTable(
                    score: rounds[shown],
                    names: state.seatNames,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Match totals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  MatchTotalsTable(state: state),
                ],
              ),
      ),
    );
  }
}

/// One round, item by item, for every player. Each player's items add up to
/// their round result.
class RoundBreakdownTable extends StatelessWidget {
  const RoundBreakdownTable({
    super.key,
    required this.score,
    required this.names,
  });

  final RoundScore score;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final penalties = score.penaltyTransfers;
    return _ScrollableTable(
      key: const Key('round-breakdown'),
      firstNumericColumn: 2,
      columns: const [
        'Player',
        'Seen',
        'Tunnellas',
        'Marriages',
        'Maal cards',
        'Maal',
        'Maal share',
        'Win / lose',
        'Penalty',
        'Round',
      ],
      rows: [
        for (var seat = 0; seat < names.length; seat++)
          _Row(
            bold: seat == score.winner,
            cells: [
              seat == score.winner ? '${names[seat]} 🏆' : names[seat],
              score.sawJoker[seat] ? 'Yes' : 'No',
              '${score.maal[seat].tunnellas}',
              '${score.maal[seat].marriages}',
              '${_maalCards(score.maal[seat])}',
              '${score.maal[seat].total}',
              signed(score.maalShares[seat]),
              signed(score.winnerPayments[seat]),
              signed(penalties[seat]),
              signed(score.net[seat]),
            ],
          ),
      ],
    );
  }

  static int _maalCards(MaalBreakdown maal) =>
      maal.tiplu + maal.jhiplu + maal.poplu + maal.alter;
}

/// Every player's result for each round, and their running total. The
/// leader (or leaders, if tied) is marked.
class MatchTotalsTable extends StatelessWidget {
  const MatchTotalsTable({super.key, required this.state});

  final TableState state;

  @override
  Widget build(BuildContext context) {
    final rounds = state.roundScores;
    final top = state.totals.reduce((a, b) => a > b ? a : b);
    return _ScrollableTable(
      key: const Key('match-totals'),
      firstNumericColumn: 1,
      columns: [
        'Player',
        for (var i = 0; i < rounds.length; i++) 'R${i + 1}',
        'Total',
      ],
      rows: [
        for (var seat = 0; seat < state.seatNames.length; seat++)
          _Row(
            bold: state.totals[seat] == top,
            cells: [
              state.totals[seat] == top
                  ? '${state.seatNames[seat]} ★'
                  : state.seatNames[seat],
              for (final round in rounds) signed(round.net[seat]),
              signed(state.totals[seat]),
            ],
          ),
      ],
    );
  }
}

/// A number with its sign: "+12", "−5", or "0".
String signed(int n) => n > 0 ? '+$n' : (n < 0 ? '−${-n}' : '0');

class _Row {
  const _Row({required this.cells, this.bold = false});

  final List<String> cells;
  final bool bold;
}

/// A compact table that scrolls sideways if it's wider than the screen.
class _ScrollableTable extends StatelessWidget {
  const _ScrollableTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.firstNumericColumn,
  });

  final List<String> columns;
  final List<_Row> rows;

  /// Columns from this index on hold numbers, so they're right-aligned.
  final int firstNumericColumn;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columns: [
          for (var i = 0; i < columns.length; i++)
            DataColumn(
              label: Text(columns[i]),
              numeric: i >= firstNumericColumn,
            ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final cell in row.cells)
                  DataCell(
                    Text(
                      cell,
                      style: row.bold
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
