import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/table/win_celebration.dart';

Future<void> pumpCelebration(
  WidgetTester tester, {
  required bool youWon,
  bool reduceMotion = false,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WinCelebration(winnerName: 'Asha', youWon: youWon),
      ),
    ),
  );
}

double bannerScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.ancestor(
        of: find.byKey(const Key('win-banner')),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  testWidgets('your win pops a banner in, with falling confetti', (
    tester,
  ) async {
    await pumpCelebration(tester, youWon: true);
    expect(find.text('You won!'), findsOneWidget);
    expect(find.byKey(const Key('confetti')), findsOneWidget);
    expect(bannerScale(tester), 0);

    await tester.pumpAndSettle();
    expect(bannerScale(tester), 1);
  });

  testWidgets('a bot\'s win gets a plain banner and no confetti', (
    tester,
  ) async {
    await pumpCelebration(tester, youWon: false);
    await tester.pumpAndSettle();
    expect(find.text('Asha won the round'), findsOneWidget);
    expect(find.byKey(const Key('confetti')), findsNothing);
  });

  testWidgets('with reduced motion the banner is simply there', (tester) async {
    await pumpCelebration(tester, youWon: true, reduceMotion: true);
    expect(bannerScale(tester), 1);
    expect(find.byKey(const Key('confetti')), findsNothing);
  });

  testWidgets('the celebration lets taps through to the table', (tester) async {
    await pumpCelebration(tester, youWon: true);
    expect(
      find.ancestor(
        of: find.byKey(const Key('win-banner')),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      ),
      findsWidgets,
    );
  });
}
