import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/table/tiplu_picker.dart';

Future<List<int>> pumpPicker(WidgetTester tester, {required bool again}) async {
  final picks = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TipluPicker(
          stockCount: 5,
          onPick: picks.add,
          onCancel: () {},
          again: again,
        ),
      ),
    ),
  );
  return picks;
}

void main() {
  testWidgets('the first pick can be cancelled', (tester) async {
    final picks = await pumpPicker(tester, again: false);

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stock-card-3')));
    expect(picks, [3]);
  });

  testWidgets('after a man card, it says so and cannot be cancelled', (
    tester,
  ) async {
    await pumpPicker(tester, again: true);

    expect(find.textContaining('That was a man card'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
