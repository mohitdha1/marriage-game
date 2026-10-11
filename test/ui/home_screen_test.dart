import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/ui/home/game_setup.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/home/pass_and_play_setup.dart';
import 'package:marriage_game/ui/settings/about.dart';
import 'package:marriage_game/ui/settings/feedback.dart';
import 'package:marriage_game/ui/settings/how_to_play_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/theme/table_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<ProviderContainer> pumpHome(
  WidgetTester tester, {
  Map<String, Object>? saved,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(InMemoryPreferences(saved)),
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        ...overrides,
      ],
      child: const MarriageApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

void main() {
  testWidgets('the top bar shows the player, their coins and a gear', (
    tester,
  ) async {
    await pumpHome(
      tester,
      saved: {'profile.name': 'Mohit', 'coins.balance': 12345},
    );

    expect(find.text('Mohit'), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.byKey(const Key('settings-button')), findsOneWidget);
  });

  testWidgets('Quick Play opens a fresh table every time', (tester) async {
    final container = await pumpHome(tester);

    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    expect(find.byType(TableScreen), findsOneWidget);

    // Draw a card, then leave and come back: the new table starts afresh.
    container.read(tableProvider.notifier).draw(DrawSource.stock);
    await tester.pump();
    expect(container.read(tableProvider).view.youHaveDrawn, isTrue);

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    expect(container.read(tableProvider).view.youHaveDrawn, isFalse);
  });

  testWidgets('leaving mid-round asks first; Stay keeps you at the table', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leave-dialog')), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(TableScreen), findsOneWidget);
  });

  group('Game setup', () {
    testWidgets('Quick Play always deals the default table, whatever was '
        'chosen for a custom game', (tester) async {
      final container = await pumpHome(
        tester,
        saved: {'lobby.playerCount': 2, 'lobby.botDifficulty': 'hard'},
      );
      expect(find.text('4 bots · Medium'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-play')));
      await tester.pumpAndSettle();

      expect(container.read(tableProvider).view.opponents, hasLength(4));
      expect(container.read(botDifficultyProvider), BotDifficulty.medium);
    });

    testWidgets('Single Player asks for the players and bots, then plays '
        'with them', (tester) async {
      final container = await pumpHome(tester);

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game-setup')), findsOneWidget);
      expect(find.byType(TableScreen), findsNothing);

      await tester.tap(find.byKey(const Key('players-5')));
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      expect(find.text('Relaxed bots that sometimes slip up.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      final table = container.read(tableProvider);
      expect(table.view.opponents, hasLength(4));
      expect(container.read(botDifficultyProvider), BotDifficulty.easy);
    });

    testWidgets('Cancel stays home, but keeps the choices for next time', (
      tester,
    ) async {
      final container = await pumpHome(tester);

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('players-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(container.read(settingsProvider).playerCount, 2);

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('players-2'))).selected,
        isTrue,
      );
    });

    testWidgets('a match keeps its setup when the next game\'s changes', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byKey(const Key('quick-play')));
      await tester.pumpAndSettle();
      final opponents = container.read(tableProvider).view.opponents.length;

      container
          .read(matchSetupProvider.notifier)
          .choose(
            const MatchSetup(playerCount: 2, difficulty: BotDifficulty.easy),
          );
      await tester.pump();

      expect(
        container.read(tableProvider).view.opponents,
        hasLength(opponents),
      );
    });

    testWidgets('the setup fits a small phone', (tester) async {
      await pumpHome(tester);
      tester.view.physicalSize = const Size(667, 375);
      await tester.pump();

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('setup-play')).hitTestable(), findsOneWidget);
      expect(find.text('Hard').hitTestable(), findsOneWidget);
    });

    test('the setup sums up as bots and level', () {
      expect(describeSetup(const MatchSetup(playerCount: 2)), '1 bot · Medium');
      expect(
        describeSetup(const MatchSetup(difficulty: BotDifficulty.hard)),
        '4 bots · Hard',
      );
    });

    test('every level has a description', () {
      for (final level in BotDifficulty.values) {
        expect(describeDifficulty(level), isNotEmpty);
      }
    });
  });

  testWidgets('Play with Friends sets up pass and play, opening covered', (
    tester,
  ) async {
    final container = await pumpHome(tester, saved: {'profile.name': 'Mohit'});

    await tester.tap(find.byKey(const Key('friends')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friends-passAndPlay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pass-and-play-setup')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('person-name-0')))
          .controller!
          .text,
      'Mohit',
    );

    await tester.tap(find.byKey(const Key('people-3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('person-name-1')), 'Bina');
    await tester.tap(find.byKey(const Key('pass-and-play-start')));
    await tester.pumpAndSettle();

    expect(find.byType(TableScreen), findsOneWidget);
    final table = container.read(tableProvider);
    expect(table.seatNames, ['Mohit', 'Bina', 'Player 3']);
    expect(find.text('Pass the device to Mohit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pass-ready')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pass-screen')), findsNothing);
  });

  testWidgets(
    'the pass and play setup fits a small phone, five names and all',
    (tester) async {
      await pumpHome(tester);
      tester.view.physicalSize = const Size(667, 375);
      await tester.pump();

      await tester.tap(find.byKey(const Key('friends')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-passAndPlay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('people-5')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('pass-and-play-start')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  test('names are tidied: blanks get a seat name, repeats a number', () {
    expect(tidyNames([' Asha ', '', 'Asha']), ['Asha', 'Player 2', 'Asha 3']);
  });

  testWidgets('the settings popover switches sound, vibration and the hand '
      'helper', (tester) async {
    final container = await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-popover')), findsOneWidget);

    await tester.tap(find.byKey(const Key('setting-sound')));
    await tester.tap(find.byKey(const Key('setting-vibration')));
    await tester.tap(find.byKey(const Key('setting-hand-helper')));
    await tester.pump();

    final settings = container.read(settingsProvider);
    expect(settings.sound, isFalse);
    expect(settings.vibration, isFalse);
    expect(settings.handHelper, isFalse);
    expect(find.text('Sound off'), findsOneWidget);
  });

  testWidgets('the settings popover picks the table theme, and the screen '
      'behind it changes straight away', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    // Classic is chosen to start with.
    expect(
      tester.getSemantics(find.byKey(const Key('theme-classic'))),
      isSemantics(
        label: 'Classic table',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const Key('theme-midnight')));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).tableTheme, TableThemeId.midnight);
    // The popover stays open, so the themes can be compared.
    expect(find.byKey(const Key('settings-popover')), findsOneWidget);
    final home = tester.element(find.byType(HomeScreen));
    expect(TableTheme.of(home).felt, TableTheme.midnight.felt);
  });

  testWidgets('the settings popover fits a small phone', (tester) async {
    await pumpHome(tester);
    tester.view.physicalSize = const Size(667, 375);
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Scrolled to if needed, every theme can be tapped.
    await tester.ensureVisible(find.byKey(const Key('theme-dashain')));
    await tester.tap(find.byKey(const Key('theme-dashain')));
    await tester.pump();
    expect(find.byKey(const Key('theme-dashain')), findsOneWidget);
  });

  testWidgets('Profile changes the name and avatar colour', (tester) async {
    final container = await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-profile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile-name')), 'Asha');
    await tester.tap(find.byKey(const Key('avatar-colour-2')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).playerName, 'Asha');
    expect(
      container.read(settingsProvider).avatarColor,
      Settings.avatarColors[2],
    );
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('tapping your name also opens the profile', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('player-badge')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-dialog')), findsOneWidget);
  });

  testWidgets('About shows the version and the credits', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Marriage',
      packageName: 'io.github.mohitdha1.marriage',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('1.0.0 (7)'), findsOneWidget);
    expect(find.textContaining('Byron Knoll'), findsOneWidget);
  });

  testWidgets('Feedback opens a new issue, with the version filled in', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Marriage',
      packageName: 'io.github.mohitdha1.marriage',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
    final opened = <Uri>[];
    await pumpHome(
      tester,
      overrides: [
        openLinkProvider.overrideWithValue((link) async {
          opened.add(link);
          return true;
        }),
      ],
    );

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-feedback')));
    await tester.pumpAndSettle();

    final link = opened.single;
    expect(link.host, 'github.com');
    expect(link.path, '/mohitdha1/marriage-game/issues/new');
    expect(link.queryParameters['body'], contains('Marriage 1.0.0 (7)'));
  });

  testWidgets('if the browser won\'t open, Feedback says where to go', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Marriage',
      packageName: 'io.github.mohitdha1.marriage',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
    await pumpHome(
      tester,
      overrides: [openLinkProvider.overrideWithValue((link) async => false)],
    );

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-feedback')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('github.com/mohitdha1/marriage-game'),
      findsOneWidget,
    );
  });

  test('the court art\'s licence is listed with the others', () async {
    registerArtLicence();

    final entries = await LicenseRegistry.licenses.toList();
    expect(
      entries.expand((entry) => entry.packages),
      contains('Vector Playing Cards (court card figures)'),
    );
  });

  testWidgets('How to play opens the rules', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-how-to-play')));
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Seeing the joker'), 200);
    expect(find.text('Seeing the joker'), findsOneWidget);
  });

  test('the rules explain the ways to discard and the joker penalty', () {
    final rules = HowToPlayScreen.sections.map((s) => s.$2).join(' ');

    expect(rules, contains('drag a card up onto the pile'));
    expect(rules, contains('flick it'));
    expect(rules, contains('Long-press'));
    expect(rules, contains('${ScoringTable.jokerDiscardPenalty} points'));
  });

  testWidgets('the home screen fits a small phone', (tester) async {
    tester.view
      ..physicalSize = const Size(667, 375)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(InMemoryPreferences()),
        ],
        child: const MarriageApp(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('coins are shown with thousands separators', () {
    expect(formatCoins(1000), '1,000');
    expect(formatCoins(999), '999');
    expect(formatCoins(1234567), '1,234,567');
    expect(formatCoins(0), '0');
  });
}
