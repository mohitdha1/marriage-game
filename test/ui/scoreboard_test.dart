import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/state/table_view.dart';

/// A controller that serves a fixed state and records Next round.
class FakeTableController extends TableController {
  FakeTableController(this.fixed);

  final TableState fixed;
  var nextRoundRequests = 0;

  @override
  TableState build() => fixed;

  @override
  void startNextRound() => nextRoundRequests++;
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
  net: const [59, -26, -33],
);

/// Round 2: Priya wins with no maal anywhere.
final round2 = RoundScore(
  winner: 1,
  maal: const [MaalBreakdown(), MaalBreakdown(), MaalBreakdown()],
  maalShares: const [0, 0, 0],
  winnerPayments: const [-3, 13, -10],
  sawJoker: const [true, true, false],
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
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = FakeTableController(state);
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

/// The text of every cell in the table with [key], row by row.
List<List<String>> cellsOf(WidgetTester tester, String key) {
  final table = tester.widget<DataTable>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(DataTable)),
  );
  return [
    for (final row in table.rows)
      [for (final cell in row.cells) (cell.child as Text).data!],
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
      ['You', 'Yes', '0', '0', '0', '0', '0', '−3', '0', '−3'],
      ['Priya 🏆', 'Yes', '0', '0', '0', '0', '0', '+13', '0', '+13'],
      ['Jack', 'No', '0', '0', '0', '0', '0', '−10', '0', '−10'],
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
      // Tunnellas, marriages, maal cards and maal; then the round's items,
      // which add up to the round total.
      ['You 🏆', 'Yes', '5', '10', '3', '18', '+31', '+13', '+15', '+59'],
      ['Priya', 'Yes', '0', '0', '5', '5', '−8', '−3', '−15', '−26'],
      ['Jack', 'No', '0', '0', '0', '0', '−23', '−10', '0', '−33'],
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
