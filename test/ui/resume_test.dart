import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/data/saved_match.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/round_log.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/scoreboard/scoreboard_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

import 'analytics_test.dart' show winRound;
import 'haptics_test.dart' show run, winnableHand;
import 'home_screen_test.dart' show pumpHome;
import 'table_controller_test.dart' show tableWith;

const c = PlayingCard.new;

/// Deals the human a hand that wins in one turn, against one bot.
final winnableDeal = roundFactoryProvider.overrideWithValue(
  (seat) => Round.fromCards(
    config: GameConfig(playerCount: 2),
    random: Random(0),
    hands: [
      winnableHand,
      run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
    ],
    stock: [
      c(Suit.clubs, Rank.five),
      c(Suit.hearts, Rank.seven),
      c(Suit.clubs, Rank.two),
      c(Suit.diamonds, Rank.queen),
    ],
    discardPile: [c(Suit.clubs, Rank.king)],
    firstSeat: seat,
  ),
);

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen, skipOffstage: false)),
);

/// Everything the app has saved on the device, as it would be found on
/// the next launch.
Map<String, Object> savedOnDevice(WidgetTester tester) {
  final preferences = containerOf(tester).read(preferencesProvider);
  return {
    'match.saved': ?preferences.getString('match.saved'),
    'coins.balance': ?preferences.getInt('coins.balance'),
  };
}

/// Closes the app and opens it again with [saved] on the device.
Future<ProviderContainer> relaunch(
  WidgetTester tester,
  Map<String, Object> saved,
) async {
  await tester.pumpWidget(const SizedBox());
  return pumpHome(tester, saved: saved);
}

/// The cards in the human player's hand, in a fixed order.
List<String> handOf(ProviderContainer container) =>
    [for (final card in container.read(tableProvider).view.hand) '$card']
      ..sort();

/// The human player's hand in the order it's shown, their groups, and
/// the positions of their selected cards.
({List<PlayingCard> hand, List<List<PlayingCard>> groups, Set<int> selected})
arrangementOf(ProviderContainer container) {
  final table = container.read(tableProvider);
  final byId = {for (final handCard in table.hand) handCard.id: handCard.card};
  return (
    hand: [for (final handCard in table.hand) handCard.card],
    groups: [
      for (final group in table.groups) [for (final id in group) byId[id]!],
    ],
    selected: {
      for (final (i, handCard) in table.hand.indexed)
        if (table.selected.contains(handCard.id)) i,
    },
  );
}

/// A pass-and-play match between Asha and Bina, saved once Asha has
/// discarded and it's Bina's turn. With [arranged], each has their hand in
/// reverse order with its first two cards grouped and its sixth selected.
String passAndPlaySave({bool arranged = false}) {
  final round =
      Round.deal(config: GameConfig(playerCount: 2), random: Random(7))
        ..showOpeningTunnellas(0, [])
        ..showOpeningTunnellas(1, []);
  round
    ..draw(DrawSource.stock)
    ..discard(round.hands[0].cards.first);
  return jsonEncode(
    SavedMatch(
      config: round.config,
      difficulty: BotDifficulty.medium,
      stake: null,
      people: const ['Asha', 'Bina'],
      bots: const {},
      roundNumber: 1,
      rounds: const [],
      start: round.start,
      log: round.log,
      arrangements: {
        if (arranged)
          for (final seat in [0, 1])
            seat: HandArrangement(
              cards: round.hands[seat].cards.reversed.toList(),
              groups: [
                [0, 1],
              ],
              selected: [5],
            ),
      },
    ).toJson(),
  );
}

void main() {
  testWidgets('with nothing saved, there\'s nothing to continue', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('continue-match')), findsNothing);
  });

  testWidgets('a match left mid-turn is picked up where it was after the '
      'app is closed', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    container.read(tableProvider.notifier).draw(DrawSource.stock);
    await tester.pump();
    final hand = handOf(container);
    final names = container.read(tableProvider).seatNames;

    final relaunched = await relaunch(tester, savedOnDevice(tester));
    expect(find.text('Round 1 · 4 bots · Easy · 5 table'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    expect(find.byType(TableScreen), findsOneWidget);
    final table = relaunched.read(tableProvider);
    expect(table.view.youHaveDrawn, isTrue);
    expect(handOf(relaunched), hand);
    expect(table.seatNames, names);
    expect(relaunched.read(tableProvider.notifier).stake, 5);
  });

  testWidgets('bots whose turn it was play on once the match is picked up', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    final controller = container.read(tableProvider.notifier)
      ..draw(DrawSource.stock);
    // Saved the moment the human discards, before any bot moves.
    final hand = container.read(tableProvider).hand;
    unawaited(controller.discard(hand.first.id));
    // The save is made once the discard is done, ahead of any bot's turn.
    await Future<void>.value();
    final saved = savedOnDevice(tester);
    await tester.pumpAndSettle();

    final relaunched = await relaunch(tester, saved);
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    final table = relaunched.read(tableProvider);
    expect(table.view.currentSeat, humanSeat);
    expect(table.view.youHaveDrawn, isFalse);
    // The human's discard, then each of the four bots'.
    expect(table.view.events.whereType<DiscardedCard>(), hasLength(5));
  });

  testWidgets('leaving the table ends the match, so there\'s nothing to '
      'continue', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('continue-match')), findsNothing);
    expect(savedOnDevice(tester), isNot(contains('match.saved')));
  });

  testWidgets('a new game replaces the saved one', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    container.read(tableProvider.notifier).draw(DrawSource.stock);
    await tester.pump();

    final relaunched = await relaunch(tester, savedOnDevice(tester));
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();

    expect(relaunched.read(tableProvider).view.youHaveDrawn, isFalse);
    expect(
      SavedMatchStore(
        relaunched.read(preferencesProvider),
      ).load()!.log.whereType<DrawMove>(),
      isEmpty,
    );
  });

  testWidgets('a round won before the app closed isn\'t paid out again, '
      'and its scores open', (tester) async {
    // The win celebration would otherwise keep the screen busy.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = await pumpHome(tester, overrides: [winnableDeal]);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    await winRound(tester);
    await tester.pump(scoreboardDelay);
    await tester.pumpAndSettle();
    final coins = (await container.read(playerDataProvider.future)).coins;
    final saved = savedOnDevice(tester);
    expect(saved['coins.balance'], coins);

    final relaunched = await relaunch(tester, saved);
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    final table = relaunched.read(tableProvider);
    expect(table.view.winner?.seat, humanSeat);
    expect(table.roundScores, hasLength(1));
    expect((await relaunched.read(playerDataProvider.future)).coins, coins);
    // The scores open straight away, ready for the next round.
    expect(find.byType(ScoreboardScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-round-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreboardScreen), findsNothing);
    expect(relaunched.read(tableProvider).roundNumber, 2);
    expect(relaunched.read(savedMatchProvider)!.roundNumber, 2);
  });

  testWidgets('the hand is picked up arranged, grouped and selected as it '
      'was left', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    final controller = container.read(tableProvider.notifier);
    final hand = container.read(tableProvider).hand;
    controller
      ..moveCard(hand.last.id, 0)
      ..toggleSelected(hand[3].id)
      ..toggleSelected(hand[7].id)
      ..groupSelected()
      ..moveCard(hand[10].id, 5)
      ..toggleSelected(hand[12].id)
      ..toggleSelected(hand[2].id);
    await tester.pump();
    final arranged = arrangementOf(container);
    expect(arranged.groups, hasLength(1));
    expect(arranged.selected, hasLength(2));

    final relaunched = await relaunch(tester, savedOnDevice(tester));
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    final (hand: cards, :groups, :selected) = arrangementOf(relaunched);
    expect(cards, arranged.hand);
    expect(groups, arranged.groups);
    expect(selected, arranged.selected);
  });

  testWidgets('selecting a card is enough to be saved', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    final hand = container.read(tableProvider).hand;
    container.read(tableProvider.notifier).toggleSelected(hand[4].id);
    await tester.pump();

    final relaunched = await relaunch(tester, savedOnDevice(tester));
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    expect(arrangementOf(relaunched).selected, {4});
  });

  testWidgets('everyone sharing the device gets their own arrangement back', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      saved: {'match.saved': passAndPlaySave(arranged: true)},
    );
    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();
    final controller = container.read(tableProvider.notifier)..takeOver();
    await tester.pump();

    // Bina's turn: her hand, reversed, with two cards grouped.
    final bina = arrangementOf(container);
    expect(bina.hand, container.read(tableProvider).view.hand.reversed);
    expect(bina.groups, [bina.hand.take(2).toList()]);
    expect(bina.selected, {5});

    // Asha's arrangement waits for her turn.
    controller.draw(DrawSource.stock);
    final drawn = container.read(tableProvider).hand.last;
    await controller.discard(drawn.id);
    await tester.pumpAndSettle();
    controller.takeOver();
    await tester.pump();

    expect(container.read(tableProvider).passingTo, isNull);
    expect(container.read(tableProvider).view.currentSeat, 0);
    final asha = arrangementOf(container);
    expect(asha.hand, container.read(tableProvider).view.hand.reversed);
    expect(asha.groups, [asha.hand.take(2).toList()]);
    expect(asha.selected, {5});
  });

  testWidgets('pass and play is picked up covered, for whoever plays next', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      saved: {'match.saved': passAndPlaySave()},
    );
    expect(find.text('Round 1 · Pass and play'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-match')));
    await tester.pumpAndSettle();

    final table = container.read(tableProvider);
    expect(table.seatNames, ['Asha', 'Bina']);
    expect(table.passingTo, 1);
    expect(table.view.currentSeat, 1);
    expect(find.text('I\'m Bina: show my cards'), findsOneWidget);
  });

  test('a game hosted for other devices isn\'t saved', () {
    final container = tableWith(
      setup: MatchSetup.hosted(hostName: 'Asha', playerCount: 2, remote: {}),
    );
    container.read(tableProvider.notifier).draw(DrawSource.stock);

    expect(container.read(savedMatchProvider), isNull);
  });

  test('a game against bots is saved after every move', () async {
    final container = tableWith();
    container.read(tableProvider);
    await Future<void>.delayed(Duration.zero);
    final dealt = container.read(savedMatchProvider)!.log.length;

    container.read(tableProvider.notifier).draw(DrawSource.stock);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(savedMatchProvider)!.log, hasLength(dealt + 1));
  });
}
