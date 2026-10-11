// Widget tests for the table screen, rendered at phone and tablet landscape
// sizes with a seeded shuffle so every deal is repeatable.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/state/table_view.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

/// Landscape screen sizes in logical pixels: a small phone, a large phone,
/// and a tablet.
const screens = {
  'small phone': Size(667, 375),
  'large phone': Size(932, 430),
  'tablet': Size(1180, 820),
};

Future<void> pumpTable(
  WidgetTester tester, {
  Size size = const Size(844, 390),
  int playerCount = 5,
  int seed = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(seed)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        gameConfigProvider.overrideWithValue(
          GameConfig(playerCount: playerCount),
        ),
      ],
      child: const MarriageApp(home: singlePlayerTable),
    ),
  );
}

/// The state the screen is currently drawing.
TableState currentState(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider);

TableView currentTable(WidgetTester tester) => currentState(tester).view;

void main() {
  testWidgets('the app opens on the table screen', (tester) async {
    await pumpTable(tester);

    expect(find.byType(TableScreen), findsOneWidget);
  });

  testWidgets('every opponent is shown with a name and card count', (
    tester,
  ) async {
    await pumpTable(tester);

    expect(find.byType(OpponentSeat), findsNWidgets(4));
    final names = currentTable(tester).opponents.map((s) => s.name).toList();
    expect(names.toSet(), hasLength(4), reason: 'every bot has its own name');
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }
    for (var seat = 1; seat <= 4; seat++) {
      expect(
        tester.widget<Text>(find.byKey(Key('card-count-$seat'))).data,
        '21',
      );
    }
  });

  for (final MapEntry(key: name, value: size) in screens.entries) {
    testWidgets('on a $name, all 22 cards fit and each shows its rank and '
        'suit', (tester) async {
      // Real phones have system bars; reduced motion skips the deal.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpTable(tester, size: size);
      ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      ).read(tableProvider.notifier).draw(DrawSource.stock);
      await tester.pump();
      expect(currentState(tester).hand, hasLength(22));

      final cards = find.descendant(
        of: find.byType(HandFan),
        matching: find.byType(CardFace),
      );
      final rects = [
        for (final element in cards.evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ]..sort((a, b) => a.left.compareTo(b.left));
      expect(rects, hasLength(22));
      final width = rects.first.width;
      for (var i = 0; i + 1 < rects.length; i++) {
        // The corner index takes the first quarter of a card's width.
        expect(
          rects[i + 1].left - rects[i].left,
          greaterThanOrEqualTo(width * 0.27),
          reason: 'card $i is covered past its rank and suit',
        );
      }
      expect(rects.first.left, greaterThanOrEqualTo(0));
      expect(rects.last.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the 21 cards are dealt into the hand fan, in order', (
    tester,
  ) async {
    List<Object> faces() => tester
        .widgetList<CardFace>(
          find.descendant(
            of: find.byType(HandFan),
            matching: find.byType(CardFace),
          ),
        )
        .map((face) => face.card)
        .toList();

    await pumpTable(tester);
    // Cards appear in the hand as they're dealt.
    expect(faces(), isEmpty);
    await tester.pump(); // the cards take off
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(faces().length, inExclusiveRange(0, 21));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('flying-card')), findsNothing);
    expect(faces(), hasLength(21));
    expect(faces(), currentState(tester).hand.map((c) => c.card));
  });

  testWidgets('the centre shows the stock size and the top discard', (
    tester,
  ) async {
    await pumpTable(tester);
    final table = currentTable(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('stock-count'))).data,
      'Stock · ${table.stockCount}',
    );
    expect(table.stockCount, 156 - 5 * 21 - 1);
    expect(
      find.byWidgetPredicate(
        (w) => w is CardFace && w.card == table.topDiscard,
      ),
      findsWidgets,
    );
  });

  testWidgets('tilted cards stay inside the hand fan\'s own bounds', (
    tester,
  ) async {
    // If cards spilled outside the fan's layout box, they could be clipped
    // or overlap whatever sits below the hand.
    for (final size in screens.values) {
      await pumpTable(tester, size: size);
      final fan = tester.getRect(find.byType(HandFan));

      for (final element
          in find
              .descendant(
                of: find.byType(HandFan),
                matching: find.byType(CardFace),
              )
              .evaluate()) {
        final box = element.renderObject! as RenderBox;
        final corners = [
          Offset.zero,
          box.size.topRight(Offset.zero),
          box.size.bottomLeft(Offset.zero),
          box.size.bottomRight(Offset.zero),
        ].map(box.localToGlobal);
        for (final corner in corners) {
          expect(
            fan.inflate(0.5).contains(corner),
            isTrue,
            reason: '$corner is outside the fan $fan on a $size screen',
          );
        }
      }
    }
  });

  for (final MapEntry(key: screen, value: size) in screens.entries) {
    for (var players = 2; players <= 5; players++) {
      testWidgets('$players players fit a $screen without overflowing', (
        tester,
      ) async {
        await pumpTable(tester, size: size, playerCount: players);

        // Layout overflows are reported as exceptions in tests.
        expect(tester.takeException(), isNull);
        expect(find.byType(OpponentSeat), findsNWidgets(players - 1));
      });
    }
  }
}
