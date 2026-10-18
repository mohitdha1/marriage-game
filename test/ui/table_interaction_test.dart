import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_notifier.dart';
import 'package:marriage_game/ui/state/table_state.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/table/hand_fan.dart';
import 'package:marriage_game/ui/table/joker_reveal.dart';
import 'package:marriage_game/ui/table/move_log.dart';
import 'package:marriage_game/ui/table/opening_picker.dart';
import 'package:marriage_game/ui/table/opponent_seat.dart';
import 'package:marriage_game/ui/table/suit_icon.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/table/tiplu_picker.dart';

const c = PlayingCard.new;

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

final yourCards = [
  c(Suit.hearts, Rank.three),
  c(Suit.hearts, Rank.four),
  c(Suit.hearts, Rank.five),
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.two),
];
final queenOfDiamonds = c(Suit.diamonds, Rank.queen);
final kingOfClubs = c(Suit.clubs, Rank.king);

Future<void> pumpTable(
  WidgetTester tester, {
  List<PlayingCard>? yourHand,
  List<PlayingCard>? stock,
  int firstSeat = 0,
  Duration thinkingTime = Duration.zero,
  bool reduceMotion = true,
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Jokers pulse forever, so a settled screen needs motion turned off.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A returning player: the first-time guide's tips are done.
        preferencesProvider.overrideWithValue(
          InMemoryPreferences({'guide.done': 'draw,discard,sets,joker'}),
        ),
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => thinkingTime),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              yourHand ?? yourCards,
              [
                c(Suit.spades, Rank.six),
                c(Suit.spades, Rank.eight),
                c(Suit.spades, Rank.queen),
              ],
            ],
            stock:
                stock ??
                [
                  c(Suit.clubs, Rank.five),
                  c(Suit.hearts, Rank.seven),
                  c(Suit.clubs, Rank.two),
                  queenOfDiamonds,
                ],
            discardPile: [kingOfClubs],
            firstSeat: firstSeat,
          ),
        ),
      ],
      child: const MarriageApp(home: singlePlayerTable),
    ),
  );
}

/// Whether [face] is drawn in the hand or on a pile, rather than carried
/// under the finger.
bool _inHandOrPile(WidgetTester tester, CardFace face) => find
    .ancestor(
      of: find.byWidget(face),
      matching: find.byWidgetPredicate(
        (w) => w is HandFan || w.key == const Key('discard-pile'),
      ),
    )
    .evaluate()
    .isNotEmpty;

TableState stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider);

/// The right-most card in the fan: the only one not partly covered by its
/// neighbour, so it's safe to tap or drag.
Finder lastHandCard(WidgetTester tester) =>
    find.byKey(ValueKey(stateOf(tester).hand.last.id));

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-line'))).data!;

/// Drags from [from] to [to] the way a finger would. Hand cards only start
/// dragging after a long press, so [longPress] holds still first.
Future<void> dragBetween(
  WidgetTester tester,
  Finder from,
  Finder to, {
  bool longPress = false,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  if (longPress) await tester.pump(const Duration(milliseconds: 400));
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a card selects it with a highlight', (tester) async {
    await pumpTable(tester);

    await tester.tap(lastHandCard(tester));
    await tester.pump();

    expect(stateOf(tester).selected, {stateOf(tester).hand.last.id});
    final face = tester.widget<CardFace>(
      find.descendant(
        of: lastHandCard(tester),
        matching: find.byType(CardFace),
      ),
    );
    expect(face.highlighted, isTrue);
  });

  testWidgets('tap the stock to draw, then select and tap the pile to '
      'discard', (tester) async {
    await pumpTable(tester);
    expect(status(tester), 'Your turn: draw a card.');

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    expect(stateOf(tester).hand.last.card, queenOfDiamonds);
    expect(status(tester), 'Select a card to discard.');

    await tester.tap(lastHandCard(tester));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pumpAndSettle(); // let the bot play

    // The bot has played, and it is your turn again.
    final state = stateOf(tester);
    expect(state.hand.map((c) => c.card), isNot(contains(queenOfDiamonds)));
    expect(state.view.isYourTurn, isTrue);
    expect(status(tester), 'Your turn: draw a card.');
  });

  testWidgets('a refused move pops up the reason', (tester) async {
    await pumpTable(tester);

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pump();

    expect(
      find.text('Select one card, then tap the discard pile.'),
      findsOneWidget,
    );
  });

  group('dragging a pile into the hand', () {
    /// Picks up [pile], then moves over the hand card at [slot] (measured
    /// once the drawn card has joined the hand) and lets go there, or at
    /// [releaseAt] instead. Returns what the finger was carrying just before
    /// letting go.
    Future<List<PlayingCard>> dragPileTo(
      WidgetTester tester,
      Finder pile, {
      int? slot,
      Offset? releaseAt,
    }) async {
      final gesture = await tester.startGesture(tester.getCenter(pile));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final target =
          releaseAt ??
          tester.getCenter(
            find.byKey(ValueKey(stateOf(tester).hand[slot!].id)),
          );
      await gesture.moveTo(target);
      await tester.pump();
      final carried = [
        for (final face in tester.widgetList<CardFace>(find.byType(CardFace)))
          if (!_inHandOrPile(tester, face)) face.card,
      ];
      await gesture.up();
      await tester.pumpAndSettle();
      return carried;
    }

    testWidgets('from the stock, the card shows face up and drops into the '
        'middle of the hand', (tester) async {
      await pumpTable(tester);

      final carried = await dragPileTo(
        tester,
        find.byKey(const Key('stock')),
        slot: 3,
      );

      expect(carried, contains(queenOfDiamonds));
      final hand = stateOf(tester).hand.map((c) => c.card).toList();
      expect(hand, hasLength(yourCards.length + 1));
      expect(hand[3], queenOfDiamonds);
      expect(status(tester), 'Select a card to discard.');
    });

    testWidgets('from the discard pile, the card drops into the middle of '
        'the hand', (tester) async {
      await pumpTable(tester);

      await dragPileTo(tester, find.byKey(const Key('discard-pile')), slot: 2);

      final hand = stateOf(tester).hand.map((c) => c.card).toList();
      expect(hand[2], kingOfClubs);
      expect(stateOf(tester).view.topDiscard, isNull);
    });

    testWidgets('let go away from the hand, the card goes to the right end', (
      tester,
    ) async {
      await pumpTable(tester);

      await dragPileTo(
        tester,
        find.byKey(const Key('stock')),
        releaseAt: const Offset(60, 120),
      );

      expect(stateOf(tester).hand.last.card, queenOfDiamonds);
    });

    testWidgets('the other cards slide apart to show where it will land', (
      tester,
    ) async {
      await pumpTable(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('stock'))),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final third = stateOf(tester).hand[2].id;
      final before = tester.getTopLeft(find.byKey(ValueKey(third))).dx;

      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey(stateOf(tester).hand[1].id))),
      );
      await tester.pump();

      // The card that was third makes way for the one being placed second.
      expect(
        tester.getTopLeft(find.byKey(ValueKey(third))).dx,
        greaterThan(before),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a draw that isn\'t allowed glides back to its pile', (
      tester,
    ) async {
      await pumpTable(tester, reduceMotion: false);
      await tester.pumpAndSettle(); // the deal
      await tester.tap(find.byKey(const Key('stock')));
      await tester.pumpAndSettle();
      final hand = stateOf(tester).hand;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('discard-pile'))),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(hand[2].id))));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const Key('flying-card')), findsOneWidget);
      expect(
        tester.widget<CardFace>(find.byKey(const Key('flying-card'))).card,
        kingOfClubs,
      );
      await tester.pumpAndSettle();
      expect(stateOf(tester).hand, hand);
      expect(stateOf(tester).view.topDiscard, kingOfClubs);
      expect(
        find.text('Already drew this turn; discard first'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a quick flick up from the stock draws and discards in one '
      'move', (tester) async {
    await pumpTable(tester);
    final before = stateOf(tester).hand.map((c) => c.card).toList();

    await tester.fling(
      find.byKey(const Key('stock')),
      const Offset(0, -150),
      1500,
    );
    await tester.pumpAndSettle();

    final state = stateOf(tester);
    expect(state.hand.map((c) => c.card), before);
    expect(
      state.view.events.whereType<DiscardedCard>().first,
      isA<DiscardedCard>()
          .having((e) => e.seat, 'seat', 0)
          .having((e) => e.card, 'card', queenOfDiamonds),
    );
    expect(state.view.isYourTurn, isTrue, reason: 'the bot has played');
  });

  testWidgets('a quick flick up from the discard pile only takes the card', (
    tester,
  ) async {
    await pumpTable(tester);

    await tester.fling(
      find.byKey(const Key('discard-pile')),
      const Offset(0, -150),
      1500,
    );
    await tester.pumpAndSettle();

    expect(stateOf(tester).hand.last.card, kingOfClubs);
    expect(stateOf(tester).view.youHaveDrawn, isTrue);
  });

  testWidgets('drag a card onto the discard pile to discard it', (
    tester,
  ) async {
    await pumpTable(tester);
    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();

    await dragBetween(
      tester,
      lastHandCard(tester),
      find.byKey(const Key('discard-pile')),
      longPress: true,
    );

    expect(
      stateOf(tester).hand.map((c) => c.card),
      isNot(contains(queenOfDiamonds)),
    );
    expect(stateOf(tester).view.isYourTurn, isTrue);
  });

  testWidgets('long-press and drag moves a card within the hand', (
    tester,
  ) async {
    await pumpTable(tester);
    final before = stateOf(tester).hand;
    final moved = before.last;

    // Drop the last card onto the first card's slot.
    final firstSlot = find.byKey(ValueKey(before.first.id));
    final gesture = await tester.startGesture(
      tester.getCenter(lastHandCard(tester)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(tester.getTopLeft(firstSlot) + const Offset(20, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final after = stateOf(tester).hand;
    expect(after.first, moved);
    expect(after, hasLength(before.length));
    expect(stateOf(tester).view.youHaveDrawn, isFalse, reason: 'not a draw');
  });

  group('Moving cards in the hand', () {
    Finder cardWidget(HandCard card) => find.byKey(ValueKey(card.id));

    /// Picks up [card] the way a finger would and carries it to [to],
    /// leaving the finger down. With [driftUp], the finger slips upward
    /// before the long press completes, as real fingers do.
    Future<TestGesture> pickUpAndCarry(
      WidgetTester tester,
      Offset from,
      Offset to, {
      bool driftUp = false,
    }) async {
      final gesture = await tester.startGesture(from);
      if (driftUp) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
      } else {
        await tester.pump(const Duration(milliseconds: 400));
      }
      final start = driftUp ? from + const Offset(0, -30) : from;
      // Straight sideways, in small steps.
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(Offset.lerp(start, to, step / 8)!);
        await tester.pump();
      }
      return gesture;
    }

    testWidgets('long-press a card and drag it straight sideways to any '
        'spot in the hand', (tester) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;
      final moved = before.last;

      final gesture = await pickUpAndCarry(
        tester,
        tester.getCenter(cardWidget(moved)),
        tester.getCenter(cardWidget(before[2])),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      final after = stateOf(tester).hand;
      expect(after[2], moved);
      expect(after.toSet(), before.toSet());
      expect(stateOf(tester).view.youHaveDrawn, isFalse, reason: 'not a draw');
    });

    testWidgets('a card picked up with the finger slipping upward still '
        'moves where it is let go over the hand', (tester) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;
      final moved = before.last;

      final gesture = await pickUpAndCarry(
        tester,
        tester.getCenter(cardWidget(moved)),
        tester.getCenter(cardWidget(before.first)) + const Offset(0, -30),
        driftUp: true,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateOf(tester).hand.first, moved);
      expect(stateOf(tester).hand, hasLength(before.length));
    });

    testWidgets('while a card is held, the others slide aside to make room', (
      tester,
    ) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;
      final firstLeft = tester.getTopLeft(cardWidget(before.first)).dx;

      final gesture = await pickUpAndCarry(
        tester,
        tester.getCenter(cardWidget(before.last)),
        tester.getCenter(cardWidget(before.first)),
      );

      // Nothing has moved in the game yet, but the first card has made room.
      expect(stateOf(tester).hand, before);
      expect(
        tester.getTopLeft(cardWidget(before.first)).dx,
        greaterThan(firstLeft),
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(stateOf(tester).hand.first, before.last);
    });

    testWidgets('a grouped set moves together', (tester) async {
      await pumpTable(tester);
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      ).read(tableProvider.notifier);
      HandCard held(PlayingCard card) =>
          stateOf(tester).hand.firstWhere((h) => h.card == card);
      final three = held(c(Suit.hearts, Rank.three));
      final four = held(c(Suit.hearts, Rank.four));
      controller
        ..toggleSelected(three.id)
        ..toggleSelected(four.id)
        ..groupSelected();
      await tester.pumpAndSettle();
      expect(stateOf(tester).hand.take(2), [three, four]);
      final last = stateOf(tester).hand.last;

      // Pick the set up by its first card's visible edge and carry it to
      // the far end.
      final gesture = await pickUpAndCarry(
        tester,
        tester.getTopLeft(cardWidget(three)) + const Offset(12, 50),
        tester.getCenter(cardWidget(last)),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      final after = stateOf(tester).hand;
      expect(after.sublist(after.length - 2), [three, four]);
      expect(stateOf(tester).groups, [
        [three.id, four.id],
      ]);
    });

    testWidgets('a drawn card joins at the right-hand end, and the hand is '
        'never re-sorted', (tester) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;
      final gesture = await pickUpAndCarry(
        tester,
        tester.getCenter(cardWidget(before.last)),
        tester.getCenter(cardWidget(before.first)),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final arranged = stateOf(tester).hand;
      expect(arranged.first, before.last);

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pumpAndSettle();

      final after = stateOf(tester).hand;
      expect(after.take(arranged.length), arranged);
      expect(after.last.card, queenOfDiamonds);
    });

    testWidgets('a quick drag sideways, without the long press, moves '
        'nothing', (tester) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;

      final gesture = await tester.startGesture(
        tester.getCenter(cardWidget(before.last)),
      );
      for (var step = 0; step < 6; step++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateOf(tester).hand, before);
    });
  });

  group('Discarding by gesture', () {
    /// The card that was drawn: the last one in the hand.
    PlayingCard drawn(WidgetTester tester) => stateOf(tester).hand.last.card;

    Future<void> drawFromStock(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();
    }

    bool inHand(WidgetTester tester, PlayingCard card) =>
        stateOf(tester).hand.any((c) => c.card == card);

    testWidgets('drag a card straight up onto the pile, no long press needed', (
      tester,
    ) async {
      await pumpTable(tester);
      await drawFromStock(tester);
      final card = drawn(tester);

      await dragBetween(
        tester,
        lastHandCard(tester),
        find.byKey(const Key('discard-pile')),
      );

      expect(inHand(tester, card), isFalse);
      expect(stateOf(tester).view.isYourTurn, isTrue, reason: 'bot played');
    });

    testWidgets('flick a card upwards to discard it', (tester) async {
      await pumpTable(tester);
      await drawFromStock(tester);
      final card = drawn(tester);

      await tester.fling(lastHandCard(tester), const Offset(0, -120), 1500);
      await tester.pumpAndSettle();

      expect(inHand(tester, card), isFalse);
    });

    testWidgets('a slow drag up that misses the pile keeps the card', (
      tester,
    ) async {
      await pumpTable(tester);
      await drawFromStock(tester);
      final before = stateOf(tester).hand;

      final gesture = await tester.startGesture(
        tester.getCenter(lastHandCard(tester)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateOf(tester).hand, before);
    });

    testWidgets('a quick drag sideways does nothing: moving a card needs a '
        'long press', (tester) async {
      await pumpTable(tester);
      await drawFromStock(tester);
      final before = stateOf(tester).hand;

      final gesture = await tester.startGesture(
        tester.getCenter(lastHandCard(tester)),
      );
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateOf(tester).hand, before);
    });

    testWidgets('before drawing, a flick is refused with the reason and the '
        'card stays', (tester) async {
      await pumpTable(tester);
      final before = stateOf(tester).hand;

      await tester.fling(lastHandCard(tester), const Offset(0, -120), 1500);
      await tester.pumpAndSettle();

      expect(stateOf(tester).hand, before);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('on a bot\'s turn, a drag onto the pile is refused', (
      tester,
    ) async {
      await pumpTable(tester, thinkingTime: const Duration(seconds: 1));
      await drawFromStock(tester);
      await tester.tap(lastHandCard(tester));
      await tester.pump();
      await tester.tap(find.byKey(const Key('discard-pile')));
      await tester.pump();
      final bot = stateOf(tester).view.opponents.single;
      final before = stateOf(tester).hand;

      await dragBetween(
        tester,
        lastHandCard(tester),
        find.byKey(const Key('discard-pile')),
      );

      expect(stateOf(tester).hand, before);
      expect(find.text('Wait for ${bot.name} to play.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    group('with motion', () {
      final flyingCard = find.byKey(const Key('flying-card'));

      testWidgets('a refused card glides back from where it was let go', (
        tester,
      ) async {
        await pumpTable(tester, reduceMotion: false);
        await tester.pumpAndSettle(); // the deal
        final id = stateOf(tester).hand.last.id;

        await tester.fling(lastHandCard(tester), const Offset(0, -120), 1500);
        await tester.pump();
        await tester.pump();

        expect(flyingCard, findsOneWidget);
        // Its place stays empty until it's back.
        expect(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(CardFace),
          ),
          findsNothing,
        );

        await tester.pumpAndSettle();
        expect(flyingCard, findsNothing);
        expect(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(CardFace),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a flicked card flies on to the pile from where it was let '
          'go', (tester) async {
        await pumpTable(
          tester,
          reduceMotion: false,
          thinkingTime: const Duration(seconds: 1),
        );
        await tester.pumpAndSettle(); // the deal
        await drawFromStock(tester);
        await tester.pumpAndSettle();
        final handCentre = tester.getCenter(find.byType(HandFan));
        const flick = Offset(0, -120);
        final letGoAt = tester.getCenter(lastHandCard(tester)) + flick;

        await tester.fling(lastHandCard(tester), flick, 1500);
        await tester.pump();
        await tester.pump();

        expect(stateOf(tester).view.topDiscard, queenOfDiamonds);
        final start = tester.getCenter(flyingCard);
        expect(
          (start - letGoAt).distance,
          lessThan((start - handCentre).distance),
          reason: 'the flight starts where the card was let go',
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      });
    });
  });

  testWidgets('Sort orders the hand ♠ ♥ ♣ ♦, then by rank', (tester) async {
    await pumpTable(tester);

    await tester.tap(find.byKey(const Key('sort-button')));
    await tester.pump();

    final shown = tester
        .widgetList<CardFace>(
          find.descendant(
            of: find.byType(HandFan),
            matching: find.byType(CardFace),
          ),
        )
        .map((face) => face.card)
        .toList();
    // ♠ ♥ ♣ ♦: black and red alternate.
    expect(shown, [
      c(Suit.spades, Rank.king),
      c(Suit.hearts, Rank.three),
      c(Suit.hearts, Rank.four),
      c(Suit.hearts, Rank.five),
      c(Suit.clubs, Rank.seven),
      c(Suit.diamonds, Rank.two),
      c(Suit.diamonds, Rank.king),
    ]);
  });

  testWidgets('with 4 dealt tunnellas, the player picks 3 to show', (
    tester,
  ) async {
    await pumpTable(
      tester,
      yourHand: [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          ...tunnellaOf(c(Suit.clubs, rank)),
        c(Suit.hearts, Rank.ace),
      ],
    );
    expect(find.byType(OpeningPicker), findsOneWidget);
    expect(status(tester), 'Choose your opening tunnellas.');

    final showButton = find.widgetWithText(FilledButton, 'Show these 3');
    expect(tester.widget<FilledButton>(showButton).onPressed, isNull);

    for (final i in [0, 1, 3]) {
      await tester.tap(find.byKey(Key('opening-tunnella-$i')));
    }
    await tester.pump();
    await tester.tap(showButton);
    await tester.pump();

    expect(find.byType(OpeningPicker), findsNothing);
    expect(stateOf(tester).hand, hasLength(4));
    expect(status(tester), 'Your turn: draw a card.');
  });

  group('Turn flow', () {
    final heartsRun = [
      c(Suit.hearts, Rank.three),
      c(Suit.hearts, Rank.four),
      c(Suit.hearts, Rank.five),
    ];
    final spadesRun = [
      c(Suit.spades, Rank.two),
      c(Suit.spades, Rank.three),
      c(Suit.spades, Rank.four),
    ];
    final clubsRun = [
      c(Suit.clubs, Rank.nine),
      c(Suit.clubs, Rank.ten),
      c(Suit.clubs, Rank.jack),
    ];
    final twoOfDiamonds = c(Suit.diamonds, Rank.two);
    final winnableHand = [
      ...heartsRun,
      ...spadesRun,
      ...clubsRun,
      c(Suit.spades, Rank.king),
      c(Suit.diamonds, Rank.king),
      c(Suit.clubs, Rank.seven),
      c(Suit.diamonds, Rank.ten),
      c(Suit.diamonds, Rank.jack),
      c(Suit.hearts, Rank.eight),
      twoOfDiamonds,
    ];

    TableNotifier controllerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(TableScreen)),
        ).read(tableProvider.notifier);

    /// Selects one copy of each of [cards].
    void select(WidgetTester tester, List<PlayingCard> cards) {
      final used = <int>{};
      for (final card in cards) {
        final id = stateOf(
          tester,
        ).hand.firstWhere((h) => h.card == card && !used.contains(h.id)).id;
        used.add(id);
        controllerOf(tester).toggleSelected(id);
      }
    }

    group('Discarding a joker', () {
      final sevenOfClubs = c(Suit.clubs, Rank.seven);
      final dialog = find.byKey(const Key('joker-discard-dialog'));

      /// Draws, shows the three runs, discards 2♦ and picks 7♥ as the
      /// tiplu, which makes the 7♣ in hand a joker; then, once the bot has
      /// played, draws again.
      Future<void> seeTheJoker(WidgetTester tester) async {
        await pumpTable(tester, yourHand: winnableHand);
        final controller = controllerOf(tester)..draw(DrawSource.stock);
        for (final run in [heartsRun, spadesRun, clubsRun]) {
          select(tester, run);
          controller.groupSelected();
        }
        controller.showGroups();
        unawaited(
          controller.discard(
            stateOf(tester).hand.firstWhere((h) => h.card == twoOfDiamonds).id,
          ),
        );
        controller
          ..pickTiplu(1)
          ..dismissReveal();
        await tester.pumpAndSettle();
        controller.draw(DrawSource.stock);
        await tester.pump();
      }

      int idOf(WidgetTester tester, PlayingCard card) =>
          stateOf(tester).hand.firstWhere((h) => h.card == card).id;

      testWidgets('a joker flicked up from the stock asks first', (
        tester,
      ) async {
        // Every 7 is wild, whichever the tiplu turns out to be.
        final sevenOfSpades = c(Suit.spades, Rank.seven);
        await pumpTable(
          tester,
          yourHand: winnableHand,
          stock: [
            sevenOfSpades,
            sevenOfSpades,
            c(Suit.diamonds, Rank.seven),
            c(Suit.diamonds, Rank.seven),
            queenOfDiamonds,
          ],
        );
        final controller = controllerOf(tester)..draw(DrawSource.stock);
        for (final run in [heartsRun, spadesRun, clubsRun]) {
          select(tester, run);
          controller.groupSelected();
        }
        controller.showGroups();
        // Completes once the bot has played, which the pumping lets it do.
        unawaited(controller.discard(idOf(tester, queenOfDiamonds)));
        controller
          ..pickTiplu(1)
          ..dismissReveal();
        await tester.pumpAndSettle();
        expect(stateOf(tester).view.isYourTurn, isTrue);
        final before = stateOf(tester).hand.map((c) => c.card).toList();

        await tester.fling(
          find.byKey(const Key('stock')),
          const Offset(0, -150),
          1500,
        );
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(find.textContaining('15-point penalty'), findsOneWidget);
        expect(stateOf(tester).hand, hasLength(before.length + 1));

        await tester.tap(find.byKey(const Key('joker-discard-confirm')));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(stateOf(tester).hand.map((c) => c.card), before);
        expect(
          stateOf(tester).view.events.whereType<DiscardedCard>().last.card.rank,
          Rank.seven,
        );
      });

      bool inHand(WidgetTester tester, PlayingCard card) =>
          stateOf(tester).hand.any((h) => h.card == card);

      testWidgets('tapping the pile with a joker selected asks first; Cancel '
          'keeps it', (tester) async {
        await seeTheJoker(tester);
        select(tester, [sevenOfClubs]);
        await tester.pump();

        await tester.tap(find.byKey(const Key('discard-pile')));
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(find.text('Discard a joker?'), findsOneWidget);
        expect(find.textContaining('15-point penalty'), findsOneWidget);

        await tester.tap(find.byKey(const Key('joker-discard-cancel')));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(inHand(tester, sevenOfClubs), isTrue);
        expect(stateOf(tester).view.youHaveDrawn, isTrue, reason: 'no move');
      });

      testWidgets('flicking a joker asks first; Discard throws it away', (
        tester,
      ) async {
        await seeTheJoker(tester);
        // Moved to the end of the hand, where nothing covers it.
        final controller = controllerOf(tester);
        controller.moveCard(
          idOf(tester, sevenOfClubs),
          stateOf(tester).hand.length - 1,
        );
        await tester.pump();

        await tester.fling(lastHandCard(tester), const Offset(0, -120), 1500);
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(inHand(tester, sevenOfClubs), isTrue, reason: 'not yet');

        await tester.tap(find.byKey(const Key('joker-discard-confirm')));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(inHand(tester, sevenOfClubs), isFalse);
      });

      testWidgets('dragging a joker onto the pile asks too', (tester) async {
        await seeTheJoker(tester);
        controllerOf(
          tester,
        ).moveCard(idOf(tester, sevenOfClubs), stateOf(tester).hand.length - 1);
        await tester.pump();

        await dragBetween(
          tester,
          lastHandCard(tester),
          find.byKey(const Key('discard-pile')),
        );
        expect(dialog, findsOneWidget);

        await tester.tap(find.byKey(const Key('joker-discard-cancel')));
        await tester.pumpAndSettle();
        expect(inHand(tester, sevenOfClubs), isTrue);
      });

      testWidgets('an ordinary card is discarded without asking', (
        tester,
      ) async {
        await seeTheJoker(tester);
        // 10♦, since discarding K♠ or the club just drawn would win.
        final ten = c(Suit.diamonds, Rank.ten);
        select(tester, [ten]);
        await tester.pump();

        await tester.tap(find.byKey(const Key('discard-pile')));
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(inHand(tester, ten), isFalse);
      });
    });

    testWidgets('draw, group, show, discard, pick the tiplu, see it '
        'revealed, and win the next turn', (tester) async {
      await pumpTable(tester, yourHand: winnableHand);
      expect(find.byKey(const Key('joker-chip')), findsNothing);

      String badge(String key) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .data!;

      // Before the joker: the helper counts toward the show; no maal, and
      // no count toward the win yet.
      expect(badge('dub-count'), 'Dub 0');
      expect(badge('seq-count'), 'Seq 3');
      expect(find.byKey(const Key('maal-badge')), findsNothing);
      expect(find.byKey(const Key('to-win')), findsNothing);
      expect(find.textContaining('to win'), findsNothing);

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();

      // Group the three runs with the Group button.
      for (final run in [heartsRun, spadesRun, clubsRun]) {
        select(tester, run);
        await tester.pump();
        await tester.tap(find.byKey(const Key('group-button')));
        await tester.pump();
      }
      expect(stateOf(tester).groups, hasLength(3));

      // Show lays the sets down; the joker comes after the discard.
      await tester.tap(find.byKey(const Key('show-button')));
      await tester.pump();
      expect(find.byType(TipluPicker), findsNothing);
      expect(find.byKey(const Key('your-laid-down-sets')), findsOneWidget);
      expect(find.byKey(const Key('show-button')), findsNothing);
      expect(status(tester), 'Discard a card to see the joker.');

      // First to show: after the discard, pick the tiplu from the
      // face-down stock.
      select(tester, [twoOfDiamonds]);
      await tester.pump();
      await tester.tap(find.byKey(const Key('discard-pile')));
      await tester.pump();
      expect(find.byType(TipluPicker), findsOneWidget);
      expect(find.text('Cancel'), findsNothing, reason: 'the pick is owed');
      await tester.tap(find.byKey(const Key('stock-card-1')));
      await tester.pump();

      // The reveal flips the tiplu over.
      expect(find.byType(JokerReveal), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SuitText>(find.byKey(const Key('reveal-title'))).text,
        'The joker is 7♥',
      );
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(JokerReveal), findsNothing);

      // The bot has played; it's your turn. Every card left is in a set, so
      // the hand is ready to win, and the maal badge shows (8♥ is the
      // poplu, worth 2).
      expect(stateOf(tester).view.isYourTurn, isTrue);
      expect(find.byKey(const Key('dub-count')), findsNothing);
      expect(badge('to-win'), 'Ready to win!');
      expect(badge('maal-badge'), 'Maal 2');

      // The joker stays in the corner, and wild cards in hand glow.
      expect(find.byKey(const Key('joker-chip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HandFan),
          matching: find.byType(JokerGlow),
        ),
        findsNWidgets(2), // 7♣ and 8♥
      );

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();

      // Win is offered only for a card whose discard wins.
      select(tester, [c(Suit.diamonds, Rank.ten)]);
      await tester.pump();
      final win = find.byKey(const Key('win-button'));
      expect(tester.widget<FilledButton>(win).onPressed, isNull);

      controllerOf(tester).toggleSelected(stateOf(tester).selected.single);
      select(tester, [c(Suit.spades, Rank.king)]);
      await tester.pump();
      expect(tester.widget<FilledButton>(win).onPressed, isNotNull);
      await tester.tap(win);
      await tester.pump();

      expect(status(tester), 'You won the round.');
      expect(find.text('You won the round!'), findsOneWidget);
      // A banner celebrates; with reduced motion, no confetti falls.
      expect(
        find.descendant(
          of: find.byKey(const Key('win-banner')),
          matching: find.text('You won!'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('confetti')), findsNothing);

      // After a moment, the scoreboard opens on its own.
      expect(find.byType(ScoreboardScreen), findsNothing);
      await tester.pump(scoreboardDelay);
      await tester.pumpAndSettle();
      expect(find.byType(ScoreboardScreen), findsOneWidget);
      expect(find.text('Round 1: You won'), findsOneWidget);
    });

    group('Ready to win', () {
      /// Shows on the first turn: draws Q♦, shows the three runs, discards
      /// 2♦ and picks 7♥ as the tiplu. Once the bot has played, every card
      /// left is in a set, and the badge says Ready to win; then draws a
      /// club, the one spare card.
      Future<HandCard> readyAndDrawn(WidgetTester tester) async {
        await pumpTable(tester, yourHand: winnableHand);
        final controller = controllerOf(tester)..draw(DrawSource.stock);
        for (final run in [heartsRun, spadesRun, clubsRun]) {
          select(tester, run);
          controller.groupSelected();
        }
        controller.showGroups();
        unawaited(
          controller.discard(
            stateOf(tester).hand.firstWhere((h) => h.card == twoOfDiamonds).id,
          ),
        );
        controller
          ..pickTiplu(1)
          ..dismissReveal();
        await tester.pumpAndSettle();
        expect(stateOf(tester).view.isYourTurn, isTrue);
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(const Key('to-win')),
                  matching: find.byType(Text),
                ),
              )
              .data,
          'Ready to win!',
        );
        controller.draw(DrawSource.stock);
        await tester.pump();
        return stateOf(tester).hand.firstWhere(
          (h) => h.card.suit == Suit.clubs && h.card.rank != Rank.seven,
        );
      }

      testWidgets('discarding the spare card on the pile wins the round', (
        tester,
      ) async {
        final spare = await readyAndDrawn(tester);

        controllerOf(tester).toggleSelected(spare.id);
        await tester.pump();
        await tester.tap(find.byKey(const Key('discard-pile')));
        await tester.pumpAndSettle();

        expect(status(tester), 'You won the round.');
        expect(find.text('You won the round!'), findsOneWidget);
        await tester.pump(scoreboardDelay);
        await tester.pumpAndSettle();
      });

      testWidgets('a winning discard by any gesture wins the round', (
        tester,
      ) async {
        final spare = await readyAndDrawn(tester);

        // Tapping, dragging and flicking a card all discard through here.
        unawaited(controllerOf(tester).discard(spare.id));
        await tester.pumpAndSettle();

        expect(status(tester), 'You won the round.');
        await tester.pump(scoreboardDelay);
        await tester.pumpAndSettle();
      });

      testWidgets('the turn of the show never wins, whatever is discarded', (
        tester,
      ) async {
        await pumpTable(tester, yourHand: winnableHand);
        final controller = controllerOf(tester)..draw(DrawSource.stock);
        for (final run in [heartsRun, spadesRun, clubsRun]) {
          select(tester, run);
          controller.groupSelected();
        }
        controller.showGroups();
        await tester.pump();

        expect(find.byKey(const Key('win-button')), findsNothing);
        expect(find.byKey(const Key('to-win')), findsNothing);
        expect(status(tester), 'Discard a card to see the joker.');

        // 2♦ would leave a winning hand, but only from the next turn.
        unawaited(
          controller.discard(
            stateOf(tester).hand.firstWhere((h) => h.card == twoOfDiamonds).id,
          ),
        );
        await tester.pump();
        expect(stateOf(tester).view.winner, isNull);
        expect(find.byType(TipluPicker), findsOneWidget);
        controller.pickTiplu(1);
        await tester.pumpAndSettle();
      });
    });

    testWidgets('Show and Group only appear when they can be used', (
      tester,
    ) async {
      await pumpTable(tester, yourHand: winnableHand);

      expect(find.byKey(const Key('group-button')), findsNothing);
      expect(find.byKey(const Key('show-button')), findsNothing);
      expect(find.byKey(const Key('win-button')), findsNothing);

      select(tester, heartsRun);
      await tester.pump();
      expect(find.byKey(const Key('group-button')), findsOneWidget);
    });

    testWidgets('the opponent whose turn it is glows', (tester) async {
      // A bot plays first, but waits while you choose opening tunnellas.
      await pumpTable(
        tester,
        firstSeat: 1,
        yourHand: [
          for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
            ...tunnellaOf(c(Suit.clubs, rank)),
        ],
      );

      expect(
        tester.widget<OpponentSeat>(find.byType(OpponentSeat)).isCurrentTurn,
        isTrue,
      );
      expect(status(tester), 'Choose your opening tunnellas.');

      for (final i in [0, 1, 2]) {
        await tester.tap(find.byKey(Key('opening-tunnella-$i')));
      }
      await tester.pump();
      await tester.tap(find.text('Show these 3'));
      await tester.pumpAndSettle(); // let the bot play

      // The bot has had its turn; now it's yours, and its seat is calm.
      expect(
        tester.widget<OpponentSeat>(find.byType(OpponentSeat)).isCurrentTurn,
        isFalse,
      );
      expect(stateOf(tester).view.isYourTurn, isTrue);
    });
  });

  testWidgets('a bot visibly thinks, then its discard appears at its seat', (
    tester,
  ) async {
    await pumpTable(tester, thinkingTime: const Duration(seconds: 1));
    final bot = stateOf(tester).view.opponents.single;

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    await tester.tap(lastHandCard(tester));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discard-pile')));
    await tester.pump();

    // During the pause: the bot's seat glows and the status says so.
    expect(status(tester), '${bot.name} is thinking…');
    expect(
      tester.widget<OpponentSeat>(find.byType(OpponentSeat)).isCurrentTurn,
      isTrue,
    );

    // Tapping the stock now is refused.
    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();
    expect(find.text('Wait for ${bot.name} to play.'), findsOneWidget);

    // After the pause, the bot has moved and it's your turn.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(status(tester), 'Your turn: draw a card.');
    // The bot's discard now shows beside its avatar.
    expect(find.byKey(Key('last-discard-${bot.seat}')), findsOneWidget);
  });

  group('card flights', () {
    final flyingCard = find.byKey(const Key('flying-card'));

    /// The card shown on the discard pile, or `null` when it looks empty.
    PlayingCard? pileTop(WidgetTester tester) {
      final faces = find.descendant(
        of: find.byKey(const Key('discard-pile')),
        matching: find.byType(CardFace),
      );
      return faces.evaluate().isEmpty
          ? null
          : tester.widget<CardFace>(faces.first).card;
    }

    testWidgets('a drawn card flies in, and shows in the hand once it lands', (
      tester,
    ) async {
      await pumpTable(tester, reduceMotion: false);
      await tester.pumpAndSettle(); // the deal

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump(); // the move
      await tester.pump(); // the flight takes off
      final drawn = stateOf(tester).hand.last;
      expect(drawn.card, queenOfDiamonds);
      expect(flyingCard, findsOneWidget);
      // Its place in the hand is kept empty until it arrives.
      expect(
        find.descendant(
          of: find.byKey(ValueKey(drawn.id)),
          matching: find.byType(CardFace),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(flyingCard, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ValueKey(drawn.id)),
          matching: find.byType(CardFace),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the pile shows its old top card until a discard lands', (
      tester,
    ) async {
      await pumpTable(
        tester,
        reduceMotion: false,
        thinkingTime: const Duration(seconds: 1),
      );
      await tester.pumpAndSettle(); // the deal
      await tester.tap(find.byKey(const Key('stock')));
      await tester.pumpAndSettle();

      await tester.tap(lastHandCard(tester));
      await tester.pump();
      await tester.tap(find.byKey(const Key('discard-pile')));
      await tester.pump();
      await tester.pump();
      expect(stateOf(tester).view.topDiscard, queenOfDiamonds);
      expect(flyingCard, findsOneWidget);
      expect(pileTop(tester), kingOfClubs);

      await tester.pumpAndSettle();
      expect(flyingCard, findsNothing);
      expect(pileTop(tester), queenOfDiamonds);

      // Let the bot finish its turn.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('nothing flies when the device asks for less motion', (
      tester,
    ) async {
      await pumpTable(tester);

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();
      await tester.pump();
      expect(flyingCard, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ValueKey(stateOf(tester).hand.last.id)),
          matching: find.byType(CardFace),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('the hand helper can be turned off in settings', (tester) async {
    await pumpTable(tester);
    expect(find.byKey(const Key('hand-helper')), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(TableScreen)),
    ).read(settingsProvider.notifier).setHandHelper(false);
    await tester.pump();

    expect(find.byKey(const Key('hand-helper')), findsNothing);
  });

  testWidgets('the Log button opens this round\'s moves', (tester) async {
    await pumpTable(tester);
    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('log-button')));
    await tester.pumpAndSettle();

    expect(find.byType(MoveLog), findsOneWidget);
    expect(
      tester.widget<SuitText>(find.byType(SuitText).first).text,
      'You drew from the stock',
    );
  });
}
