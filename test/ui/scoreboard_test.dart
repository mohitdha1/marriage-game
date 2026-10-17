import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/state/table_view.dart';

import '../engine/round_log_test.dart' show dealt, playOn;

/// A controller that serves a fixed state, at a [fixedStake] table if one
/// is given, and records Next round and End match.
class FakeTableController extends TableController {
  FakeTableController(this.fixed, {this.fixedStake});

  final TableState fixed;
  final int? fixedStake;
  var nextRoundRequests = 0;
  var endMatchRequests = 0;

  @override
  TableState build() => fixed;

  @override
  int? get stake => fixedStake;

  @override
  void startNextRound() => nextRoundRequests++;

  @override
  void endMatch() => endMatchRequests++;
}

const names = ['You', 'Priya', 'Jack'];

/// Round 1: you win with 18 maal (opening tunnella 5, marriage 10, one
/// tiplu 3); Priya has seen the joker with an alter (5) and paid a joker-
/// discard penalty; Jack never saw the joker.
final round1 = RoundScore(
  winner: 0,
  maal: const [
    MaalBreakdown(tunnellas: 5, handMarriages: 1, tiplu: 3),
    MaalBreakdown(alter: 5),
    MaalBreakdown(),
  ],
  maalShares: const [31, -8, -23],
  winnerPayments: const [13, -3, -10],
  penalties: const [0, 15, 0],
  sawJoker: const [true, true, false],
  setsShown: const [3, 3, 0],
  net: const [59, -26, -33],
);

/// Round 2: Priya wins with no maal anywhere.
final round2 = RoundScore(
  winner: 1,
  maal: const [MaalBreakdown(), MaalBreakdown(), MaalBreakdown()],
  maalShares: const [0, 0, 0],
  winnerPayments: const [-3, 13, -10],
  sawJoker: const [true, true, false],
  setsShown: const [3, 3, 0],
  net: const [-3, 13, -10],
);

TableState stateWith(List<RoundScore> rounds, {bool roundOver = true}) {
  const seats = [
    SeatView(seat: 0, name: 'You', cardCount: 0),
    SeatView(seat: 1, name: 'Priya', cardCount: 0),
    SeatView(seat: 2, name: 'Jack', cardCount: 0),
  ];
  return TableState(
    view: TableView(
      you: seats[0],
      opponents: seats.sublist(1),
      hand: const [],
      stockCount: 0,
      topDiscard: null,
      currentSeat: 0,
      youHaveDrawn: false,
      winner: roundOver ? seats[rounds.last.winner] : null,
    ),
    hand: const [],
    seatNames: names,
    roundScores: rounds,
    totals: [
      for (var seat = 0; seat < 3; seat++)
        rounds.fold(0, (sum, round) => sum + round.net[seat]),
    ],
  );
}

/// Opens the scoreboard on top of a placeholder screen, so Next round has
/// somewhere to return to.
Future<FakeTableController> openScoreboard(
  WidgetTester tester,
  TableState state, {
  Size size = const Size(844, 390),
  int? stake,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = FakeTableController(state, fixedStake: stake);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tableProvider.overrideWith(() => controller)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScoreboardScreen(),
                ),
              ),
              child: const Text('table'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('table'));
  await tester.pumpAndSettle();
  return controller;
}

/// The text of every cell in the table with [key], row by row. A marked
/// name reads as the name with 🏆 (round winner) or ★ (match leader).
List<List<String>> cellsOf(WidgetTester tester, String key) {
  final table = tester.widget<DataTable>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(DataTable)),
  );
  String textOf(Widget cell) => switch (cell) {
    Text(:final data) => data!,
    ScoreName(:final name, mark: ScoreMark.winner) => '$name 🏆',
    ScoreName(:final name, mark: ScoreMark.leader) => '$name ★',
    ScoreName(:final name) => name,
    _ => throw ArgumentError('unexpected cell $cell'),
  };
  return [
    for (final row in table.rows)
      [for (final cell in row.cells) textOf(cell.child)],
  ];
}

void main() {
  testWidgets('before any round finishes, there is nothing to show', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith(const [], roundOver: false));

    expect(find.text('No rounds finished yet.'), findsOneWidget);
    expect(find.byKey(const Key('next-round-button')), findsNothing);
  });

  testWidgets('the latest round is broken down line by line', (tester) async {
    await openScoreboard(tester, stateWith([round1, round2]));

    expect(find.text('Round 2: Priya won'), findsOneWidget);
    expect(cellsOf(tester, 'round-breakdown'), [
      ['You', '3', '0', '0', '0', '0', '0', '−3', '0', '−3'],
      ['Priya 🏆', '3', '0', '0', '0', '0', '0', '+13', '0', '+13'],
      ['Jack', '0', '0', '0', '0', '0', '0', '−10', '0', '−10'],
      ['Total', '', '', '', '', '', '0', '0', '0', '0'],
    ]);
  });

  testWidgets('an earlier round can be picked, with every item shown', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith([round1, round2]));

    await tester.tap(find.byKey(const Key('round-chip-1')));
    await tester.pump();

    expect(find.text('Round 1: You won'), findsOneWidget);
    expect(cellsOf(tester, 'round-breakdown'), [
      // Sets shown, tunnellas, marriages, maal cards and maal; then the
      // round's items (maal share, game fee, penalty), which add up to the
      // round total, and each settles to 0.
      ['You 🏆', '3', '5', '10', '3', '18', '+31', '+13', '+15', '+59'],
      ['Priya', '3', '0', '0', '5', '5', '−8', '−3', '−15', '−26'],
      ['Jack', '0', '0', '0', '0', '0', '−23', '−10', '0', '−33'],
      ['Total', '', '', '', '', '', '0', '0', '0', '0'],
    ]);
  });

  testWidgets('a doublee win says so, explaining the bigger payments', (
    tester,
  ) async {
    // Jack wins with doublees: everyone pays the usual 3 or 10, plus 5.
    final dubleeRound = RoundScore(
      winner: 2,
      maal: const [MaalBreakdown(), MaalBreakdown(), MaalBreakdown()],
      maalShares: const [0, 0, 0],
      winnerPayments: const [-8, -8, 16],
      sawJoker: const [true, true, true],
      wonWithDoublees: true,
      net: const [-8, -8, 16],
    );
    await openScoreboard(tester, stateWith([dubleeRound]));

    expect(find.text('Round 1: Jack won with doublees'), findsOneWidget);
  });

  testWidgets('match totals show every round and mark the leader', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith([round1, round2]));

    expect(cellsOf(tester, 'match-totals'), [
      ['You ★', '+59', '−3', '+56'],
      ['Priya', '−26', '+13', '−13'],
      ['Jack', '−33', '−10', '−43'],
    ]);
  });

  testWidgets('the trophy and star are drawn, not typed as emoji', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith([round1, round2]));

    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.textContaining('🏆'), findsNothing);
    expect(find.textContaining('★'), findsNothing);
  });

  testWidgets('Next round deals the next round and returns to the table', (
    tester,
  ) async {
    final controller = await openScoreboard(tester, stateWith([round1]));

    await tester.tap(find.byKey(const Key('next-round-button')));
    await tester.pumpAndSettle();

    expect(controller.nextRoundRequests, 1);
    expect(find.byType(ScoreboardScreen), findsNothing);
    expect(find.text('table'), findsOneWidget);
  });

  testWidgets('End match asks first, then ends the match and goes home', (
    tester,
  ) async {
    final controller = await openScoreboard(tester, stateWith([round1]));

    await tester.tap(find.byKey(const Key('end-match')));
    await tester.pumpAndSettle();
    expect(find.text('End the match?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.endMatchRequests, 0);
    expect(find.byType(ScoreboardScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('end-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('end-match-confirm')));
    await tester.pumpAndSettle();
    expect(controller.endMatchRequests, 1);
    expect(find.byType(ScoreboardScreen), findsNothing);
    expect(find.text('table'), findsOneWidget);
  });

  testWidgets('at a stake table, each result is shown in coins too', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith([round1, round2]), stake: 5);

    expect(
      [for (final row in cellsOf(tester, 'round-breakdown')) row.last],
      ['−15', '+65', '−50', '0'],
    );
    expect(
      [for (final row in cellsOf(tester, 'match-totals')) row.last],
      ['+280', '−65', '−215'],
    );
    expect(
      find.text('Points and coins won and lost settle to 0.'),
      findsOneWidget,
    );
  });

  testWidgets('without a stake, there are no coins', (tester) async {
    await openScoreboard(tester, stateWith([round1]));

    expect(find.text('Coins'), findsNothing);
    expect(find.text('Points won and lost settle to 0.'), findsOneWidget);
  });

  testWidgets('shows exactly what the engine settled for a played round', (
    tester,
  ) async {
    final round = dealt(7);
    playOn(round, Random(7), turns: 1000);
    expect(round.isOver, isTrue);
    final score = round.score();
    final players = score.net.length;
    final names = [for (var seat = 0; seat < players; seat++) 'P$seat'];
    final seats = [
      for (var seat = 0; seat < players; seat++)
        SeatView(seat: seat, name: names[seat], cardCount: 0),
    ];
    final state = TableState(
      view: TableView(
        you: seats[0],
        opponents: seats.sublist(1),
        hand: const [],
        stockCount: 0,
        topDiscard: null,
        currentSeat: 0,
        youHaveDrawn: false,
        winner: seats[score.winner],
      ),
      hand: const [],
      seatNames: names,
      roundScores: [score],
      totals: score.net,
    );

    await openScoreboard(tester, state, stake: 10);

    final rows = cellsOf(tester, 'round-breakdown');
    final penalties = score.penaltyTransfers;
    for (var seat = 0; seat < players; seat++) {
      expect(rows[seat].sublist(1), [
        '${score.setsShown[seat]}',
        '${score.maal[seat].tunnellas}',
        '${score.maal[seat].marriages}',
        isA<String>(),
        '${score.maal[seat].total}',
        signed(score.maalShares[seat]),
        signed(score.winnerPayments[seat]),
        signed(penalties[seat]),
        signed(score.net[seat]),
        signed(score.coinsAt(10)[seat]),
      ]);
    }
    expect(rows.last.sublist(6), ['0', '0', '0', '0', '0']);
  });

  testWidgets('Next round is not offered while a round is being played', (
    tester,
  ) async {
    await openScoreboard(tester, stateWith([round1], roundOver: false));

    expect(find.byKey(const Key('next-round-button')), findsNothing);
    expect(find.text('Round 1: You won'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    await openScoreboard(
      tester,
      stateWith([round1, round2, round1, round2, round1]),
      size: const Size(667, 375),
    );

    expect(tester.takeException(), isNull);
  });

  test('signed numbers', () {
    expect(signed(12), '+12');
    expect(signed(-5), '−5');
    expect(signed(0), '0');
  });
}
