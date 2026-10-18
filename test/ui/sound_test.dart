import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/sound/table_sounds.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_notifier.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

import '../../tool/import_sounds.dart' show decodeWav, sampleRate;

const c = PlayingCard.new;

/// Remembers every sound it's asked to play, in order.
class RecordingSoundEffects implements SoundEffects {
  final played = <Sfx>[];

  @override
  void play(Sfx sound) => played.add(sound);

  var preloads = 0;

  @override
  Future<void> preload() async => preloads++;

  @override
  Future<void> dispose() async {}
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

Future<RecordingSoundEffects> pumpTable(
  WidgetTester tester, {
  List<PlayingCard>? botHand,
  List<PlayingCard>? stock,
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Jokers pulse forever, so a settled screen needs motion turned off.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final sounds = RecordingSoundEffects();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        soundEffectsProvider.overrideWithValue(sounds),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              winnableHand,
              botHand ?? run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
            ],
            stock:
                stock ??
                [
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
  return sounds;
}

TableNotifier controllerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider.notifier);

int idOf(WidgetTester tester, PlayingCard card) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider).hand.firstWhere((h) => h.card == card).id;

void main() {
  group('soundFor', () {
    test('draws and discards snap', () {
      expect(
        soundFor(const DrewCard(1, DrawSource.stock), yourSeat: 0),
        Sfx.cardSnap,
      );
      expect(
        soundFor(DiscardedCard(0, twoOfDiamonds), yourSeat: 0),
        Sfx.cardSnap,
      );
    });

    test('winning plays the jingle; someone else winning a gentler tone', () {
      expect(soundFor(WonRound(0, twoOfDiamonds), yourSeat: 0), Sfx.win);
      expect(soundFor(WonRound(1, twoOfDiamonds), yourSeat: 0), Sfx.roundOver);
    });

    test('shows, openings and reshuffles are silent', () {
      expect(
        soundFor(ShowedSets(0, ShowKind.pureSets, [heartsRun]), yourSeat: 0),
        isNull,
      );
      expect(soundFor(OpenedTunnellas(0, [heartsRun]), yourSeat: 0), isNull);
      expect(soundFor(const StockReshuffled(0), yourSeat: 0), isNull);
    });
  });

  group('At the table', () {
    testWidgets('the deal shuffles', (tester) async {
      final sounds = await pumpTable(tester);

      expect(sounds.played, [Sfx.shuffle]);
    });

    testWidgets('selecting a card clicks; drawing and discarding snap, '
        'including the bot\'s moves', (tester) async {
      final sounds = await pumpTable(tester);
      sounds.played.clear();

      await tester.tap(find.byKey(const Key('stock')));
      await tester.pump();
      expect(sounds.played, [Sfx.cardSnap]);

      final lastCard = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      ).read(tableProvider).hand.last.id;
      await tester.tap(find.byKey(ValueKey(lastCard)));
      await tester.pump();
      expect(sounds.played.last, Sfx.select);

      sounds.played.clear();
      await tester.tap(find.byKey(const Key('discard-pile')));
      await tester.pumpAndSettle();
      // Your discard, the bot's draw and discard, then your turn again.
      expect(sounds.played, [
        Sfx.cardSnap,
        Sfx.cardSnap,
        Sfx.cardSnap,
        Sfx.yourTurn,
      ]);
    });

    testWidgets('sounds are loaded as the app starts', (tester) async {
      final sounds = await pumpTable(tester);

      expect(sounds.preloads, 1);
    });

    testWidgets('seeing the joker plays the reveal, once', (tester) async {
      final sounds = await pumpTable(tester);
      final controller = controllerOf(tester)..draw(DrawSource.stock);
      for (final set in [heartsRun, spadesRun, clubsRun]) {
        for (final card in set) {
          controller.toggleSelected(idOf(tester, card));
        }
        controller.groupSelected();
      }
      await tester.pump();
      sounds.played.clear();

      controller
        ..showGroups()
        ..pickTiplu(1);
      await tester.pump();
      expect(sounds.played, [Sfx.jokerReveal]);

      controller.toggleSelected(idOf(tester, twoOfDiamonds));
      await tester.pump();
      expect(sounds.played.where((s) => s == Sfx.jokerReveal), hasLength(1));
    });

    testWidgets('no chime when a round starts on your turn', (tester) async {
      final sounds = await pumpTable(tester);

      expect(sounds.played, isNot(contains(Sfx.yourTurn)));
    });

    testWidgets('winning plays the jingle, and the next round shuffles', (
      tester,
    ) async {
      final sounds = await pumpTable(tester);
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
      sounds.played.clear();

      controller.declareWin();
      await tester.pump();
      expect(sounds.played, [Sfx.win]);

      controller.startNextRound();
      await tester.pump();
      expect(sounds.played.last, Sfx.shuffle);

      // Let the scoreboard timer and the bot (who plays first now) finish.
      await tester.pump(scoreboardDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('a bot winning plays the gentler tone', (tester) async {
      final sounds = await pumpTable(
        tester,
        botHand: [
          ...run(Suit.spades, [Rank.jack, Rank.queen, Rank.king]),
          ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
          ...run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]),
          c(Suit.hearts, Rank.eight),
          c(Suit.clubs, Rank.queen),
          c(Suit.diamonds, Rank.queen),
        ],
        stock: [c(Suit.hearts, Rank.seven), c(Suit.clubs, Rank.two)],
      );
      final controller = controllerOf(tester)..tapDiscardPile();
      await tester.pump();

      sounds.played.clear();
      // Widget tests run on fake time, so the bot's turn happens as the test
      // pumps rather than by awaiting the discard.
      unawaited(controller.discard(idOf(tester, c(Suit.hearts, Rank.three))));
      await tester.pumpAndSettle();

      expect(sounds.played.last, Sfx.roundOver);
      await tester.pump(scoreboardDelay);
      await tester.pumpAndSettle();
    });
  });

  group('Sharing the speaker', () {
    test('Android: sounds never take audio focus from other apps', () {
      final android = soundEffectsAudioContext().android;

      expect(android.audioFocus, AndroidAudioFocus.none);
      expect(android.usageType, AndroidUsageType.game);
      expect(android.contentType, AndroidContentType.sonification);
    });

    test('iOS: sounds mix with other audio and respect the silent switch', () {
      expect(
        soundEffectsAudioContext().iOS.category,
        AVAudioSessionCategory.ambient,
      );
    });
  });

  group('Sound files', () {
    test('every sound has its file in assets/sounds', () {
      for (final sound in Sfx.values) {
        final file = File('assets/sounds/${sound.file}');
        expect(file.existsSync(), isTrue, reason: '${sound.file} is missing');
        expect(
          file.lengthSync(),
          greaterThan(44),
          reason: 'more than a header',
        );
      }
    });

    test('every sound is short and well below full volume', () {
      for (final sound in Sfx.values) {
        final samples = decodeWav(
          File('assets/sounds/${sound.file}').readAsBytesSync(),
        );
        final seconds = samples.length / sampleRate;
        final peak = samples.fold(0.0, (loudest, s) => max(loudest, s.abs()));

        expect(seconds, lessThanOrEqualTo(1.5), reason: '${sound.file} length');
        // −3 dB below full scale, leaving the loudest a little headroom.
        expect(peak, lessThanOrEqualTo(0.71), reason: '${sound.file} peak');
      }
    });

    test('the sounds folder is bundled with the app', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/sounds/'),
      );
    });
  });
}
