import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/state/table_view.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';

Future<void> pumpSeat(WidgetTester tester, {required bool offline}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: OpponentSeat(
            seat: const SeatView(seat: 1, name: 'Bina', cardCount: 21),
            offline: offline,
          ),
        ),
      ),
    );

void main() {
  testWidgets('a seat whose player has lost their link says Offline', (
    tester,
  ) async {
    await pumpSeat(tester, offline: true);

    expect(find.byKey(const Key('offline-1')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('a seat whose player is there doesn\'t', (tester) async {
    await pumpSeat(tester, offline: false);

    expect(find.text('Offline'), findsNothing);
  });
}
