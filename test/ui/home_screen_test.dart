import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/settings/how_to_play_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/theme/table_theme.dart';

Future<ProviderContainer> pumpHome(
  WidgetTester tester, {
  Map<String, Object>? saved,
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
        gameConfigProvider.overrideWithValue(GameConfig(playerCount: 3)),
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

  testWidgets('Single Player opens a fresh table every time', (tester) async {
    final container = await pumpHome(tester);

    await tester.tap(find.byKey(const Key('single-player')));
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

    await tester.tap(find.byKey(const Key('single-player')));
    await tester.pumpAndSettle();
    expect(container.read(tableProvider).view.youHaveDrawn, isFalse);
  });

  testWidgets('leaving mid-round asks first; Stay keeps you at the table', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('single-player')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leave-dialog')), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(TableScreen), findsOneWidget);
  });

  testWidgets('Hotspot / Local says it is coming soon', (tester) async {
    await pumpHome(tester);
    expect(find.byKey(const Key('coming-soon')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hotspot')));
    await tester.pump();

    expect(find.textContaining('coming soon'), findsOneWidget);
    expect(find.byType(TableScreen), findsNothing);
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

  testWidgets('How to play opens the rules', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-how-to-play')));
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text('Seeing the joker'), findsOneWidget);
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
