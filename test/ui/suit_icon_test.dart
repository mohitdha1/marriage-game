import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/suit_icon.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

List<SuitIcon> iconsIn(WidgetTester tester) =>
    tester.widgetList<SuitIcon>(find.byType(SuitIcon)).toList();

void main() {
  group('SuitText', () {
    testWidgets('draws each suit symbol as an icon, in order', (tester) async {
      await pump(tester, const SuitText('Took 9♣, threw K♥'));

      expect(iconsIn(tester).map((icon) => icon.suit), [
        Suit.clubs,
        Suit.hearts,
      ]);
    });

    testWidgets('red suits are red; black suits take the text colour', (
      tester,
    ) async {
      await pump(
        tester,
        const SuitText(
          '♠♥♦♣',
          style: TextStyle(color: Colors.white),
          redColor: Colors.pink,
        ),
      );

      expect(iconsIn(tester).map((icon) => icon.color), [
        Colors.white,
        Colors.pink,
        Colors.pink,
        Colors.white,
      ]);
    });

    testWidgets('icons scale with the text', (tester) async {
      await pump(tester, const SuitText('A♠', style: TextStyle(fontSize: 20)));

      expect(iconsIn(tester).single.size, 20 * 0.85);
    });

    testWidgets('screen readers hear the original text', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const SuitText('Took 9♣, threw K♥'));

      expect(find.bySemanticsLabel('Took 9♣, threw K♥'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('text without suits has no icons', (tester) async {
      await pump(tester, const SuitText('Your turn: draw a card.'));

      expect(find.byType(SuitIcon), findsNothing);
      expect(find.text('Your turn: draw a card.'), findsOneWidget);
    });
  });

  testWidgets('card faces draw their suit, never the emoji-prone symbol', (
    tester,
  ) async {
    await pump(
      tester,
      const CardFace(PlayingCard(Suit.hearts, Rank.seven), width: 60),
    );

    expect(iconsIn(tester).map((icon) => icon.suit), [
      Suit.hearts,
      Suit.hearts,
    ]);
    expect(iconsIn(tester).every((icon) => icon.color == redSuitColor), isTrue);
    expect(find.textContaining('♥'), findsNothing);
  });

  testWidgets('every suit paints', (tester) async {
    await pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final suit in Suit.values)
            SuitIcon(suit, size: 24, color: Colors.black),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SuitIcon), findsNWidgets(4));
  });
}
