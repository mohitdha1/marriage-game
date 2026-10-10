import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/haptics/haptics.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

/// Remembers every buzz it's asked for, in order.
class RecordingHaptics implements Haptics {
  final buzzed = <Buzz>[];

  @override
  void buzz(Buzz kind) => buzzed.add(kind);
}

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
final twoOfDiamonds = c(Suit.diamonds, Rank.two);

/// After drawing Q♦, this hand shows 3 runs (7♥ becomes the tiplu) and wins
/// by discarding 2♦.
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

Future<RecordingHaptics> pumpTable(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final haptics = RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        hapticsProvider.overrideWithValue(haptics),
        roundFactoryProvider.overrideWithValue(
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
        ),
      ],
      child: const MarriageApp(home: singlePlayerTable),
    ),
  );
  await tester.pump();
  return haptics;
}

TableController controllerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider.notifier);

int idOf(WidgetTester tester, PlayingCard card) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider).hand.firstWhere((h) => h.card == card).id;

void main() {
  group('At the table', () {
    testWidgets('a round that starts on your turn doesn\'t buzz', (
      tester,
    ) async {
      final haptics = await pumpTable(tester);

      expect(haptics.buzzed, isEmpty);
    });

    testWidgets('a gentle tap when the bot hands the turn back', (
      tester,
    ) async {
      final haptics = await pumpTable(tester);
      final controller = controllerOf(tester)..draw(DrawSource.stock);

      unawaited(controller.discard(idOf(tester, c(Suit.spades, Rank.king))));
      await tester.pumpAndSettle();

      expect(haptics.buzzed, [Buzz.yourTurn]);
    });

    testWidgets('winning buzzes for the win only', (tester) async {
      final haptics = await pumpTable(tester);
      final controller = controllerOf(tester)..draw(DrawSource.stock);
      for (final set in [heartsRun, spadesRun, clubsRun]) {
        for (final card in set) {
          controller.toggleSelected(idOf(tester, card));
        }
        controller.groupSelected();
      }
      controller
        ..showGroups()
        ..pickTiplu(1)
        ..toggleSelected(idOf(tester, twoOfDiamonds));
      await tester.pump();

      controller.declareWin();
      await tester.pump();
      expect(haptics.buzzed, [Buzz.win]);

      await tester.pump(scoreboardDelay);
      await tester.pumpAndSettle();
    });
  });

  group('Switching off', () {
    test('the gate passes buzzes only while vibration is on', () {
      final inner = RecordingHaptics();
      var on = true;
      final gated = GatedHaptics(inner, isOn: () => on)..buzz(Buzz.win);
      on = false;
      gated.buzz(Buzz.yourTurn);

      expect(inner.buzzed, [Buzz.win]);
    });
  });

  group('On the device', () {
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    testWidgets('your turn is one light tap', (tester) async {
      const DeviceHaptics().buzz(Buzz.yourTurn);
      await tester.pump();

      expect(calls, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('a win is two heavy taps, a moment apart', (tester) async {
      const DeviceHaptics().buzz(Buzz.win);
      await tester.pump();
      expect(calls, ['HapticFeedbackType.heavyImpact']);

      await tester.pump(DeviceHaptics.winGap);
      expect(calls, [
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });
  });
}
