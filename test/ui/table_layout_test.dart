import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/table_center.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

/// Landscape screen sizes in logical pixels: a small phone, a large phone,
/// and a tablet.
const screens = {
  'small phone': Size(667, 375),
  'large phone': Size(932, 430),
  'tablet': Size(1180, 820),
};

void main() {
  final runs = [
    run(Suit.hearts, [Rank.three, Rank.four, Rank.five]),
    run(Suit.spades, [Rank.two, Rank.three, Rank.four]),
    run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]),
  ];

  /// A table where you have shown 3 sets, drawn, and selected a
  /// card: every on-screen element this step adds is visible at once.
  Future<void> pumpBusyTable(
    WidgetTester tester,
    Size size,
    int playerCount,
  ) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rest = [...Rank.values.map((r) => c(Suit.diamonds, r))];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomProvider.overrideWithValue(Random(0)),
          botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
          roundFactoryProvider.overrideWithValue(
            () => Round.fromCards(
              config: GameConfig(playerCount: playerCount),
              random: Random(0),
              hands: [
                [...runs.expand((r) => r), ...rest.take(12)],
                for (var bot = 1; bot < playerCount; bot++)
                  run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
              ],
              stock: [for (var i = 0; i < 10; i++) c(Suit.hearts, Rank.king)],
              discardPile: [c(Suit.clubs, Rank.king)],
            ),
          ),
        ],
        child: const MarriageApp(),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TableScreen)),
    );
    final controller = container.read(tableProvider.notifier);
    for (final set in runs) {
      final ids = <int>{};
      for (final card in set) {
        final id = container
            .read(tableProvider)
            .hand
            .firstWhere((h) => h.card == card && !ids.contains(h.id))
            .id;
        ids.add(id);
        controller.toggleSelected(id);
      }
      controller.groupSelected();
    }
    controller
      ..showGroups()
      ..pickTiplu(0)
      ..dismissReveal()
      ..draw(DrawSource.stock);
    // Let every bot take a turn, so each seat shows its last move too.
    unawaited(controller.discard(container.read(tableProvider).hand.last.id));
    await tester.pumpAndSettle();
    controller
      ..draw(DrawSource.stock)
      ..toggleSelected(container.read(tableProvider).hand.last.id);
    await tester.pump();
    expect(container.read(tableProvider).botMoves, hasLength(playerCount - 1));
  }

  for (final MapEntry(key: name, value: size) in screens.entries) {
    for (var players = 2; players <= 5; players++) {
      testWidgets('$players players on a $name: nothing overlaps the hand or '
          'the seats', (tester) async {
        await pumpBusyTable(tester, size, players);
        expect(tester.takeException(), isNull);

        final fan = tester.getRect(find.byType(HandFan));
        final above = {
          'stock and discard pile': find.byType(TableCenter),
          'status line': find.byKey(const Key('status-line')),
          'action buttons': find.byKey(const Key('action-bar')),
          'your laid-down sets': find.byKey(const Key('your-laid-down-sets')),
        };
        final seats = find.byType(OpponentSeat);
        expect(seats, findsNWidgets(players - 1));

        final rects = {
          for (final MapEntry(key: what, value: finder) in above.entries)
            what: tester.getRect(finder),
        };
        for (final a in rects.entries) {
          for (final b in rects.entries) {
            if (a.key.compareTo(b.key) >= 0) continue;
            expect(
              a.value.overlaps(b.value),
              isFalse,
              reason: '${a.key} (${a.value}) overlaps ${b.key} (${b.value})',
            );
          }
        }

        for (final MapEntry(key: what, value: finder) in above.entries) {
          expect(finder, findsOneWidget, reason: '$what should be on screen');
          final rect = tester.getRect(finder);
          expect(
            rect.bottom,
            lessThanOrEqualTo(fan.top + 0.5),
            reason: '$what ($rect) overlaps the hand ($fan)',
          );
          for (final seat in seats.evaluate()) {
            final seatRect = tester.getRect(find.byWidget(seat.widget));
            expect(
              rect.overlaps(seatRect),
              isFalse,
              reason: '$what ($rect) overlaps a seat ($seatRect)',
            );
          }
        }
      });
    }
  }
}
