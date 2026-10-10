// Renders the store screenshots from the app's real screens, at 1920 × 1080,
// into docs/store/screenshots/ as JPEGs (the felt's fine grain makes PNGs
// several times larger). Games are dealt from fixed shuffles, so the
// pictures come out the same every time.
//
// Run from the project folder:  flutter test tool/render_screenshots.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/haptics/haptics.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

import '../test/ui/real_fonts.dart';

const folder = 'docs/store/screenshots';

/// A phone held sideways, as 1920 × 1080 pixels.
const screen = Size(1920, 1080);
const pixelRatio = 2.8125;

final _frame = GlobalKey();

Future<void> pumpApp(
  WidgetTester tester, {
  required Widget home,
  Map<String, Object> saved = const {},
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(
            // A returning player: the first-time guide's tips are done.
            InMemoryPreferences({
              'profile.name': 'Mohit',
              'guide.done': 'draw,discard,sets,joker',
              ...saved,
            }),
          ),
          botThinkingTimeProvider.overrideWithValue(
            () => const Duration(days: 1),
          ),
          soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
          hapticsProvider.overrideWithValue(const SilentHaptics()),
          ...overrides,
        ],
        child: MarriageApp(home: home),
      ),
    ),
  );
}

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    // Court figures and other images finish loading.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final jpeg = img.encodeJpg(
      img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgba!.buffer,
        numChannels: 4,
      ),
      quality: 90,
    );
    File('$folder/$name.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(jpeg);
  });
  stdout.writeln('$folder/$name.jpg');
}

/// Lets [time] pass a frame at a time, so animations run as on a phone.
Future<void> play(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < time; t += frame) {
    await tester.pump(frame);
  }
}

TableController controllerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableScreen)),
).read(tableProvider.notifier);

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

void main() {
  setUp(() async {
    await loadRealFonts();
    await loadMaterialIcons();
  });

  void atPhoneSize(WidgetTester tester) {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);
  }

  testWidgets('home', (tester) async {
    atPhoneSize(tester);
    await pumpApp(
      tester,
      home: const HomeScreen(),
      saved: {'coins.balance': 1240},
    );
    await tester.pumpAndSettle();
    await shoot(tester, '1-home');
  });

  testWidgets('a full table', (tester) async {
    atPhoneSize(tester);
    await pumpApp(
      tester,
      home: singlePlayerTable,
      overrides: [
        randomProvider.overrideWithValue(Random(3)),
        gameConfigProvider.overrideWithValue(GameConfig(playerCount: 5)),
      ],
    );
    await play(tester, const Duration(seconds: 3)); // the deal
    controllerOf(tester).sortHand();
    await tester.pump();
    await shoot(tester, '2-table');
  });

  testWidgets('a festive table', (tester) async {
    atPhoneSize(tester);
    await pumpApp(
      tester,
      home: singlePlayerTable,
      saved: {'settings.tableTheme': 'dashain'},
      overrides: [
        randomProvider.overrideWithValue(Random(8)),
        gameConfigProvider.overrideWithValue(GameConfig(playerCount: 4)),
      ],
    );
    await play(tester, const Duration(seconds: 3));
    await shoot(tester, '3-dashain');
  });

  testWidgets('choosing a game', (tester) async {
    atPhoneSize(tester);
    await pumpApp(
      tester,
      home: const HomeScreen(),
      saved: {
        'settings.tableTheme': 'midnight',
        'lobby.playerCount': 4,
        'lobby.botDifficulty': 'hard',
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('single-player')));
    await tester.pumpAndSettle();
    await shoot(tester, '4-setup');
  });

  testWidgets('passing the device between friends', (tester) async {
    atPhoneSize(tester);
    await pumpApp(
      tester,
      home: singlePlayerTable,
      overrides: [
        randomProvider.overrideWithValue(Random(5)),
        matchSetupProvider.overrideWith(_ThreeFriends.new),
      ],
    );
    await play(tester, const Duration(seconds: 2));
    final controller = controllerOf(tester)
      ..takeOver()
      ..draw(DrawSource.stock);
    final hand = ProviderScope.containerOf(
      tester.element(find.byType(TableScreen)),
    ).read(tableProvider).hand;
    unawaited(controller.discard(hand.last.id));
    await play(tester, const Duration(seconds: 1));
    await shoot(tester, '7-pass');
  });

  testWidgets('winning and the scores', (tester) async {
    atPhoneSize(tester);
    final hearts = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
    final spades = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
    final clubs = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
    final twoOfDiamonds = c(Suit.diamonds, Rank.two);
    await pumpApp(
      tester,
      home: singlePlayerTable,
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              [
                ...hearts,
                ...spades,
                ...clubs,
                c(Suit.spades, Rank.king),
                c(Suit.diamonds, Rank.king),
                c(Suit.clubs, Rank.seven),
                c(Suit.diamonds, Rank.ten),
                c(Suit.diamonds, Rank.jack),
                c(Suit.hearts, Rank.eight),
                twoOfDiamonds,
              ],
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
    );
    await play(tester, const Duration(seconds: 2));
    final controller = controllerOf(tester)..draw(DrawSource.stock);
    final hand = ProviderScope.containerOf(
      tester.element(find.byType(TableScreen)),
    ).read(tableProvider).hand;
    int idOf(PlayingCard card) => hand.firstWhere((h) => h.card == card).id;
    for (final set in [hearts, spades, clubs]) {
      for (final card in set) {
        controller.toggleSelected(idOf(card));
      }
      controller.groupSelected();
    }
    controller
      ..showGroups()
      ..pickTiplu(1)
      ..dismissReveal()
      ..toggleSelected(idOf(twoOfDiamonds))
      ..declareWin();
    // The banner has popped in and the confetti is falling; the notice
    // saying the same is cleared so the hand shows.
    await play(tester, const Duration(milliseconds: 700));
    ScaffoldMessenger.of(
      tester.element(find.byType(TableScreen)),
    ).removeCurrentSnackBar();
    await tester.pump();
    await shoot(tester, '5-win');

    await play(tester, scoreboardDelay + const Duration(seconds: 1));
    await shoot(tester, '6-scores');
  });
}

/// Three friends passing the device round.
class _ThreeFriends extends MatchSetupController {
  @override
  MatchSetup build() => MatchSetup.passAndPlay(['Mohit', 'Bina', 'Chandra']);
}
