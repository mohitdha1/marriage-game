import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';

const sevenOfClubs = PlayingCard(Suit.clubs, Rank.seven);

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

/// How strongly the glow is showing right now.
double glowAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byKey(const Key('joker-glow')));
  return (box.decoration as BoxDecoration).boxShadow!.single.color.a;
}

void main() {
  testWidgets('a wild card glows instead of carrying a "J" label', (
    tester,
  ) async {
    await pump(tester, const CardFace(sevenOfClubs, width: 60, wild: true));

    expect(find.byType(JokerGlow), findsOneWidget);
    expect(find.text('J'), findsNothing);
  });

  testWidgets('an ordinary card does not glow', (tester) async {
    await pump(tester, const CardFace(sevenOfClubs, width: 60));

    expect(find.byType(JokerGlow), findsNothing);
  });

  testWidgets('the glow pulses slowly', (tester) async {
    await pump(tester, const CardFace(sevenOfClubs, width: 60, wild: true));

    // Brightens for 1.8 seconds, then fades back over the next 1.8.
    final start = glowAlpha(tester);
    await tester.pump(const Duration(milliseconds: 1800));
    final peak = glowAlpha(tester);
    await tester.pump(const Duration(milliseconds: 1800));
    final back = glowAlpha(tester);

    expect(peak, greaterThan(start + 0.3));
    expect(back, closeTo(start, 0.05));
  });

  testWidgets('with reduced motion the glow holds steady', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, const CardFace(sevenOfClubs, width: 60, wild: true));

    final first = glowAlpha(tester);
    await tester.pump(const Duration(milliseconds: 900));

    expect(glowAlpha(tester), first);
    expect(first, greaterThan(0.4), reason: 'still clearly visible');
  });

  testWidgets('screen readers hear that the card is a joker', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const CardFace(sevenOfClubs, width: 60, wild: true));

    expect(find.bySemanticsLabel('7♣, joker'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a hand only glows once the joker is known', (tester) async {
    Widget hand(Jokers? jokers) => SizedBox(
      width: 400,
      child: HandFan(
        cards: const [HandCard(1, sevenOfClubs)],
        cardWidth: 60,
        jokers: jokers,
      ),
    );

    await pump(tester, hand(null));
    expect(find.byType(JokerGlow), findsNothing);

    await pump(
      tester,
      hand(Jokers(const PlayingCard(Suit.hearts, Rank.seven))),
    );
    expect(find.byType(JokerGlow), findsOneWidget);
  });
}
