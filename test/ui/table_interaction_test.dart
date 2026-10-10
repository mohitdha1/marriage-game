import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
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
            stock: [
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

  testWidgets('drag the stock onto the hand to draw', (tester) async {
    await pumpTable(tester);

    await dragBetween(
      tester,
      find.byKey(const Key('stock')),
      find.byType(HandFan),
    );

    expect(stateOf(tester).hand.last.card, queenOfDiamonds);
  });

  testWidgets('drag the discard pile onto the hand to take its card', (
    tester,
  ) async {
    await pumpTable(tester);

    await dragBetween(
      tester,
      find.byKey(const Key('discard-pile')),
      find.byType(HandFan),
    );

    expect(stateOf(tester).hand.last.card, kingOfClubs);
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

  testWidgets('a quick drag on a hand card does nothing; it needs a long '
      'press', (tester) async {
    await pumpTable(tester);
    final before = stateOf(tester).hand;

    await dragBetween(
      tester,
      lastHandCard(tester),
      find.byKey(const Key('discard-pile')),
    );

    expect(stateOf(tester).hand, before);
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

    TableController controllerOf(WidgetTester tester) =>
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

    testWidgets('draw, group, show, pick the tiplu, see it revealed, and win', (
      tester,
    ) async {
      await pumpTable(tester, yourHand: winnableHand);
      expect(find.byKey(const Key('joker-chip')), findsNothing);

      // Before the joker: the helper counts toward the show; no maal yet.
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('hand-helper')),
                matching: find.byType(Text),
              ),
            )
            .data,
        'Ready to show · Dublees 0/7',
      );
      expect(find.byKey(const Key('maal-badge')), findsNothing);

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

      // First to show: pick the tiplu from the face-down stock.
      await tester.tap(find.byKey(const Key('show-button')));
      await tester.pump();
      expect(find.byType(TipluPicker), findsOneWidget);
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
      await tester.pump();
      expect(find.byType(JokerReveal), findsNothing);

      // After the joker: sets made and unmatched cards, and the maal badge
      // (8♥ is the poplu, worth 2).
      String badge(String key) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(badge('hand-helper'), '5 sets · 1 unmatched');
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
      expect(find.byKey(const Key('your-laid-down-sets')), findsOneWidget);

      // Win is offered only for a card whose discard wins.
      select(tester, [c(Suit.diamonds, Rank.ten)]);
      await tester.pump();
      final win = find.byKey(const Key('win-button'));
      expect(tester.widget<FilledButton>(win).onPressed, isNull);

      controllerOf(tester).toggleSelected(stateOf(tester).selected.single);
      select(tester, [twoOfDiamonds]);
      await tester.pump();
      expect(tester.widget<FilledButton>(win).onPressed, isNotNull);
      await tester.tap(win);
      await tester.pump();

      expect(status(tester), 'You won the round.');
      expect(find.text('You won the round!'), findsOneWidget);

      // After a moment, the scoreboard opens on its own.
      expect(find.byType(ScoreboardScreen), findsNothing);
      await tester.pump(scoreboardDelay);
      await tester.pumpAndSettle();
      expect(find.byType(ScoreboardScreen), findsOneWidget);
      expect(find.text('Round 1: You won'), findsOneWidget);
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
