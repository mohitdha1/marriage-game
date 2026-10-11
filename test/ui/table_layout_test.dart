import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/table_center.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

import 'real_fonts.dart';

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
  // Measure with Android's real font, not the test font, so text takes up
  // as much room as it does on a phone.
  setUpAll(loadRealFonts);

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
    int playerCount, {
    bool guideDone = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      // A landscape Android phone: status bar along the top, navigation
      // buttons down the right-hand side.
      ..padding = const FakeViewPadding(top: 28, right: 48);
    addTearDown(tester.view.reset);
    // Jokers pulse forever, so a settled screen needs motion turned off.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final rest = [...Rank.values.map((r) => c(Suit.diamonds, r))];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (guideDone)
            preferencesProvider.overrideWithValue(
              InMemoryPreferences({'guide.done': 'draw,discard,sets,joker'}),
            ),
          randomProvider.overrideWithValue(Random(0)),
          botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
          soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
          roundFactoryProvider.overrideWithValue(
            (seat) => Round.fromCards(
              config: GameConfig(playerCount: playerCount),
              random: Random(0),
              hands: [
                [...runs.expand((r) => r), ...rest.take(12)],
                // Bots hold three runs, so they show on their first turn
                // and every seat has chips to lay out.
                for (var bot = 1; bot < playerCount; bot++)
                  [
                    ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
                    ...run(Suit.diamonds, [Rank.seven, Rank.eight, Rank.nine]),
                    ...run(Suit.hearts, [Rank.jack, Rank.queen, Rank.king]),
                    c(Suit.spades, Rank.two),
                    c(Suit.clubs, Rank.nine),
                  ],
              ],
              stock: [for (var i = 0; i < 10; i++) c(Suit.hearts, Rank.king)],
              discardPile: [c(Suit.clubs, Rank.king)],
            ),
          ),
        ],
        child: const MarriageApp(home: singlePlayerTable),
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
    // Let every bot take a turn, so each seat shows its last discard too.
    unawaited(controller.discard(container.read(tableProvider).hand.last.id));
    await tester.pumpAndSettle();
    controller
      ..draw(DrawSource.stock)
      ..toggleSelected(container.read(tableProvider).hand.last.id);
    await tester.pump();
    expect(
      container.read(tableProvider).view.opponents.map((s) => s.lastDiscard),
      everyElement(isNotNull),
      reason: 'every seat shows its last discard',
    );
    expect(
      container.read(tableProvider).view.opponents.map((s) => s.laidDown),
      everyElement(hasLength(3)),
      reason: 'every bot has shown its sets',
    );
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
          'sort button and your sets': find.byKey(const Key('hand-tools')),
          'back and log buttons': find.byKey(const Key('top-left-buttons')),
          'scores button and joker chip': find.byKey(
            const Key('top-right-items'),
          ),
        };
        final seats = find.byType(OpponentSeat);
        expect(seats, findsNWidgets(players - 1));

        // The corner badges sit over the hand by design, but must stay clear
        // of every seat and of each other.
        // While the guide's tip shows, the hand helper waits.
        expect(find.byKey(const Key('hand-helper')), findsNothing);
        final badges = [tester.getRect(find.byKey(const Key('maal-badge')))];
        // They sit above the hand, so they mustn't hide anything there.
        for (final badge in badges) {
          for (final MapEntry(key: what, value: finder) in {
            'action buttons': find.byKey(const Key('action-bar')),
            'sort button and your sets': find.byKey(const Key('hand-tools')),
            'stock and discard pile': find.byType(TableCenter),
            'guide tip': find.byKey(const Key('guide-sets')),
          }.entries) {
            expect(
              badge.overlaps(tester.getRect(finder)),
              isFalse,
              reason: 'a corner badge ($badge) overlaps the $what',
            );
          }
        }
        for (final badge in badges) {
          for (final seat in find.byType(OpponentSeat).evaluate()) {
            expect(
              badge.overlaps(tester.getRect(find.byWidget(seat.widget))),
              isFalse,
              reason: 'a corner badge ($badge) overlaps a seat',
            );
          }
        }

        // The first-time guide's tip may cover the status line, which says
        // much the same, but nothing the player needs to see or tap.
        final tip = find.byKey(const Key('guide-sets'));
        expect(tip, findsOneWidget);
        final tipRect = tester.getRect(tip);
        for (final MapEntry(key: what, value: finder) in above.entries) {
          if (what == 'status line') continue;
          expect(
            tipRect.overlaps(tester.getRect(finder)),
            isFalse,
            reason: 'the guide tip ($tipRect) overlaps the $what',
          );
        }
        for (final seat in seats.evaluate()) {
          expect(
            tipRect.overlaps(tester.getRect(find.byWidget(seat.widget))),
            isFalse,
            reason: 'the guide tip ($tipRect) overlaps a seat',
          );
        }
        // The tip borrows the space above the hand from your shown sets.
        expect(find.byKey(const Key('your-laid-down-sets')), findsNothing);
        // Nor does it hide the corners of the cards in hand (a selected card
        // lifts into the room the tip uses).
        for (final element
            in find
                .descendant(
                  of: find.byType(HandFan),
                  matching: find.byType(CardFace),
                )
                .evaluate()) {
          if ((element.widget as CardFace).highlighted) continue;
          final card = tester.getRect(find.byWidget(element.widget));
          expect(
            tipRect.bottom,
            lessThanOrEqualTo(card.top + 0.5),
            reason: 'the guide tip ($tipRect) covers a card in hand ($card)',
          );
        }

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

  for (final MapEntry(key: name, value: size) in screens.entries) {
    testWidgets('on a $name, the badges and shown sets sit clear above the '
        'hand', (tester) async {
      await pumpBusyTable(tester, size, 5, guideDone: true);

      final cards = [
        for (final element
            in find
                .descendant(
                  of: find.byType(HandFan),
                  matching: find.byType(CardFace),
                )
                .evaluate())
          if (!(element.widget as CardFace).highlighted)
            tester.getRect(find.byWidget(element.widget)),
      ];
      final badges = {
        'maal badge': tester.getRect(find.byKey(const Key('maal-badge'))),
        'hand helper': tester.getRect(find.byKey(const Key('hand-helper'))),
        'your shown sets': tester.getRect(
          find.byKey(const Key('your-laid-down-sets')),
        ),
      };
      for (final a in badges.entries) {
        for (final b in badges.entries) {
          if (a.key.compareTo(b.key) >= 0) continue;
          expect(
            a.value.overlaps(b.value),
            isFalse,
            reason: 'the ${a.key} overlaps the ${b.key}',
          );
        }
      }
      for (final MapEntry(key: badge, value: rect) in badges.entries) {
        for (final card in cards) {
          expect(
            rect.overlaps(card),
            isFalse,
            reason: 'the $badge hides a card',
          );
        }
        for (final MapEntry(key: what, value: finder) in {
          'action buttons': find.byKey(const Key('action-bar')),
          'sort button and your sets': find.byKey(const Key('hand-tools')),
          'stock and discard pile': find.byType(TableCenter),
        }.entries) {
          expect(
            rect.overlaps(tester.getRect(finder)),
            isFalse,
            reason: 'the $badge ($rect) overlaps the $what',
          );
        }
        for (final seat in find.byType(OpponentSeat).evaluate()) {
          expect(
            rect.overlaps(tester.getRect(find.byWidget(seat.widget))),
            isFalse,
            reason: 'the $badge overlaps a seat',
          );
        }
      }
    });
  }
}
