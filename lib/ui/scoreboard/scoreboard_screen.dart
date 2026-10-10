import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/scoring.dart';
import '../state/table_controller.dart';
import '../state/table_state.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';

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

    final theme = TableTheme.of(context);
    final heading = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: Colors.white);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scoreboard'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (roundOver && !ref.read(tableProvider.notifier).dealsRounds)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                key: Key('waiting-for-host'),
                child: Text('The host deals the next round'),
              ),
            ),
          if (roundOver && ref.read(tableProvider.notifier).dealsRounds)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('next-round-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: const Color(0xFF1A1A1A),
                ),
                onPressed: () {
                  ref.read(tableProvider.notifier).startNextRound();
                  Navigator.of(context).pop();
                },
                child: const Text('Next round'),
              ),
            ),
        ],
      ),
      body: TableFelt(
        child: SafeArea(
          child: rounds.isEmpty
              ? Center(child: Text('No rounds finished yet.', style: heading))
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
                              onSelected: (_) =>
                                  setState(() => _shownRound = i),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Round ${shown + 1}: '
                      '${state.seatNames[rounds[shown].winner]} won'
                      '${rounds[shown].wonWithDoublees ? ' with doublees' : ''}',
                      key: const Key('round-title'),
                      style: heading,
                    ),
                    const SizedBox(height: 6),
                    _Panel(
                      color: theme.panel,
                      child: RoundBreakdownTable(
                        score: rounds[shown],
                        names: state.seatNames,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Match totals', style: heading),
                    const SizedBox(height: 6),
                    _Panel(
                      color: theme.panel,
                      child: MatchTotalsTable(state: state),
                    ),
                  ],
                ),
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
            name: ScoreName(
              names[seat],
              mark: seat == score.winner ? ScoreMark.winner : null,
            ),
            cells: [
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
            name: ScoreName(
              state.seatNames[seat],
              mark: state.totals[seat] == top ? ScoreMark.leader : null,
            ),
            cells: [
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

/// What a player's name is marked with in a score table.
enum ScoreMark {
  /// A trophy: they won this round.
  winner,

  /// A star: they lead the match.
  leader,
}

/// A player's name in a score table, followed by a drawn trophy or star if
/// it has a [mark]. Drawn rather than typed, as emoji look different on
/// every phone.
class ScoreName extends StatelessWidget {
  const ScoreName(this.name, {super.key, this.mark, this.style});

  final String name;
  final ScoreMark? mark;
  final TextStyle? style;

  /// This name drawn in [style].
  ScoreName styled(TextStyle? style) =>
      ScoreName(name, mark: mark, style: style);

  @override
  Widget build(BuildContext context) {
    final mark = this.mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: style),
        if (mark != null) ...[
          const SizedBox(width: 4),
          Icon(
            switch (mark) {
              ScoreMark.winner => Icons.emoji_events,
              ScoreMark.leader => Icons.star,
            },
            size: 16,
            color: TableTheme.of(context).accent,
            semanticLabel: switch (mark) {
              ScoreMark.winner => 'won the round',
              ScoreMark.leader => 'leads the match',
            },
          ),
        ],
      ],
    );
  }
}

class _Row {
  const _Row({required this.name, required this.cells, this.bold = false});

  final ScoreName name;
  final List<String> cells;
  final bool bold;
}

/// The theme's dark panel behind a table, so it reads on the felt.
class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Padding(padding: const EdgeInsets.all(4), child: child),
  );
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
    final bold = TextStyle(
      color: TableTheme.of(context).accent,
      fontWeight: FontWeight.bold,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: const TextStyle(color: Colors.white),
        dividerThickness: 0.5,
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
        ),
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
                DataCell(row.name.styled(row.bold ? bold : null)),
                for (final cell in row.cells)
                  DataCell(Text(cell, style: row.bold ? bold : null)),
              ],
            ),
        ],
      ),
    );
  }
}
