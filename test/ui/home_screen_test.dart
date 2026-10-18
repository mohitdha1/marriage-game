import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/data/stake_tables.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/ui/home/game_setup.dart';
import 'package:marriage_game/ui/home/economy_config_provider.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/home/hourly_gift_button.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/home/pass_and_play_setup.dart';
import 'package:marriage_game/ui/home/stake_table_picker.dart';
import 'package:marriage_game/ui/home/stake_tables_provider.dart';
import 'package:marriage_game/ui/settings/about.dart';
import 'package:marriage_game/ui/settings/feedback.dart';
import 'package:marriage_game/ui/settings/house_rules_screen.dart';
import 'package:marriage_game/ui/settings/how_to_play_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/house_rules.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/table/table_screen.dart';
import 'package:marriage_game/ui/telemetry/crash_reports.dart';
import 'package:marriage_game/ui/theme/table_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<ProviderContainer> pumpHome(
  WidgetTester tester, {
  Map<String, Object>? saved,
  List<Override> overrides = const [],
  DateTime Function()? clock,
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
        // The app's own stake tables, read straight from the data file:
        // loading through the asset bundle doesn't finish in fake time.
        stakeTablesProvider.overrideWith(
          (ref) =>
              StakeTables.fromJson(File(StakeTables.asset).readAsStringSync()),
        ),
        economyConfigProvider.overrideWith(
          (ref) => EconomyConfig.fromJson(
            File(EconomyConfig.asset).readAsStringSync(),
          ),
        ),
        if (clock != null) clockProvider.overrideWithValue(clock),
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

  testWidgets('the top bar shows gems, a new player starting with 3', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('gem-balance')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('screen readers hear what each balance counts', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, saved: {'coins.balance': 12345});

    expect(find.bySemanticsLabel('12,345 coins'), findsOneWidget);
    expect(find.bySemanticsLabel('3 gems'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('gems saved earlier show, without more starting gems', (
    tester,
  ) async {
    await pumpHome(
      tester,
      saved: {'gems.balance': 1234, 'gems.startingGiven': true},
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('gem-balance')),
        matching: find.text('1,234'),
      ),
      findsOneWidget,
    );
  });

  group('Hourly gift', () {
    final noon = DateTime(2026, 10, 17, 12);
    String label(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('gift-label'))).data!;

    testWidgets('a new player\'s first gift is ready, and tapping it opens '
        'the cards', (tester) async {
      await pumpHome(tester, clock: () => noon);
      expect(label(tester), 'Collect');

      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gift-cards')), findsOneWidget);
    });

    testWidgets('the wait carries on from the last collection, even with '
        'the app closed, and the gift is ready when it runs out', (
      tester,
    ) async {
      var now = noon;
      await pumpHome(
        tester,
        clock: () => now,
        saved: {
          'gift.collectedAt': noon
              .subtract(const Duration(minutes: 20))
              .millisecondsSinceEpoch,
          'gift.count': 1,
        },
      );
      expect(label(tester), '40:00');

      // Tapping before it's ready opens nothing.
      await tester.tap(find.byKey(const Key('hourly-gift')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gift-cards')), findsNothing);

      now = now.add(const Duration(minutes: 40));
      await tester.pump(const Duration(seconds: 1));
      expect(label(tester), 'Collect');
    });

    testWidgets('screen readers hear whether it\'s ready', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(
        tester,
        clock: () => noon,
        saved: {
          'gift.collectedAt': noon
              .subtract(const Duration(minutes: 50))
              .millisecondsSinceEpoch,
        },
      );

      expect(
        find.bySemanticsLabel('Next hourly gift in 10:00'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    test('countdowns read as minutes and seconds, or hours past an hour', () {
      expect(countdownText(const Duration(minutes: 59, seconds: 7)), '59:07');
      expect(countdownText(const Duration(milliseconds: 400)), '0:01');
      expect(
        countdownText(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05',
      );
    });
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

  group('Stake tables', () {
    testWidgets('Quick Play deals five at the 5 table for a new player', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      expect(find.text('4 bots · Easy · 5 table'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-play')));
      await tester.pumpAndSettle();

      expect(container.read(tableProvider).view.opponents, hasLength(4));
      expect(container.read(botDifficultyProvider), BotDifficulty.easy);
      expect(container.read(matchSetupProvider).stake, 5);
    });

    testWidgets('Quick Play deals the table last chosen', (tester) async {
      final container = await pumpHome(
        tester,
        saved: {
          'lobby.stake': 100,
          'coins.balance': 50000,
          'stakes.gamesPlayed': '{"5": 50, "10": 50, "25": 75, "50": 75}',
        },
      );
      expect(find.text('4 bots · Medium · 100 table'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-play')));
      await tester.pumpAndSettle();

      expect(container.read(matchSetupProvider).stake, 100);
      expect(container.read(botDifficultyProvider), BotDifficulty.medium);
    });

    testWidgets('Single Player shows every stake, with locks and progress', (
      tester,
    ) async {
      await pumpHome(tester, saved: {'stakes.gamesPlayed': '{"5": 32}'});

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stake-5')), findsOneWidget);
      expect(find.byKey(const Key('stake-5-lock')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('stake-5-min'))).data,
        'Open to all',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('stake-10-lock')),
          matching: find.text('32/50 games'),
        ),
        findsOneWidget,
      );
      expect(find.text('Min 1K'), findsOneWidget);
      // The last tier is far along the row.
      await tester.scrollUntilVisible(
        find.byKey(const Key('stake-100000')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('stake-tiles')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Min 10M'), findsOneWidget);
    });

    testWidgets('Single Player plays the chosen table with the chosen '
        'players, its bots at the table\'s level', (tester) async {
      final container = await pumpHome(
        tester,
        saved: {'stakes.gamesPlayed': '{"5": 50}'},
      );

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stake-10')));
      await tester.tap(find.byKey(const Key('players-3')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Each point is worth 10 coins'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      expect(container.read(tableProvider).view.opponents, hasLength(2));
      expect(container.read(matchSetupProvider).stake, 10);
      expect(container.read(botDifficultyProvider), BotDifficulty.easy);
      expect(container.read(settingsProvider).stake, 10);
      // Only the easy level's own bots sit at an easy table.
      for (final bot in container.read(tableProvider).view.opponents) {
        expect(
          BotPersonality.named(bot.name)?.difficulty,
          BotDifficulty.easy,
          reason: bot.name,
        );
      }
    });

    testWidgets('a locked table can be looked at but not played', (
      tester,
    ) async {
      await pumpHome(tester, saved: {'stakes.gamesPlayed': '{"5": 32}'});

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stake-10')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('setup-play')))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Play 18 more games at the 5 table to unlock it.'),
        findsOneWidget,
      );
    });

    testWidgets('an unlocked table needs its minimum balance to play', (
      tester,
    ) async {
      await pumpHome(
        tester,
        saved: {'stakes.gamesPlayed': '{"5": 50}', 'coins.balance': 999},
      );

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stake-10')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('setup-play')))
            .onPressed,
        isNull,
      );
      expect(find.text('Needs 1,000 coins to join.'), findsOneWidget);
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

    testWidgets('the table picker fits a small phone', (tester) async {
      await pumpHome(tester);
      tester.view.physicalSize = const Size(667, 375);
      await tester.pump();

      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('setup-play')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('players-5')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('stake-5')).hitTestable(), findsOneWidget);
    });

    test('the setup sums up as bots, level and table', () {
      expect(describeSetup(const MatchSetup(playerCount: 2)), '1 bot · Medium');
      expect(
        describeSetup(const MatchSetup(difficulty: BotDifficulty.hard)),
        '4 bots · Hard',
      );
      expect(
        describeSetup(
          const MatchSetup(difficulty: BotDifficulty.hard, stake: 25000),
        ),
        '4 bots · Hard · 25K table',
      );
      expect(
        describeSetup(
          const MatchSetup(stake: 5, rules: HouseRules(mode: GameMode.kidnap)),
        ),
        '4 bots · Medium · 5 table · Kidnap',
      );
    });

    test('the felt names the mode and the stake', () {
      expect(feltLabel(GameMode.kidnap, 1000), 'KIDNAP · 1K/PT');
      expect(feltLabel(GameMode.standard, 5), 'STANDARD · 5/PT');
      expect(feltLabel(GameMode.murder, null), 'MURDER');
      expect(feltLabel(GameMode.standard, null), isNull);
    });

    test('every mode has a name and its own description', () {
      expect(GameMode.values.map(modeName), ['Standard', 'Kidnap', 'Murder']);
      expect(GameMode.values.map(describeMode).toSet(), hasLength(3));
    });

    testWidgets('Single Player plays the chosen mode, named on the felt and '
        'on Quick Play', (tester) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byKey(const Key('single-player')));
      await tester.pumpAndSettle();
      expect(find.text(describeMode(GameMode.standard)), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-kidnap')));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).rules.mode, GameMode.kidnap);
      expect(find.text(describeMode(GameMode.kidnap)), findsOneWidget);

      await tester.tap(find.byKey(const Key('setup-play')));
      await tester.pumpAndSettle();
      expect(container.read(matchSetupProvider).rules.mode, GameMode.kidnap);
      expect(container.read(gameConfigProvider).mode, GameMode.kidnap);
      expect(find.text('KIDNAP · 5/PT'), findsOneWidget);

      await tester.tap(find.byKey(const Key('back-button')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('leave-confirm')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('leave-confirm')));
        await tester.pumpAndSettle();
      }
      if (find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('4 bots · Easy · 5 table · Kidnap'), findsOneWidget);
    });

    test('stakes and balances are written short', () {
      expect(formatStake(5), '5');
      expect(formatStake(250), '250');
      expect(formatStake(1000), '1K');
      expect(formatStake(2500), '2.5K');
      expect(formatStake(100000), '100K');
      expect(formatStake(10000000), '10M');
      expect(formatStake(2500000), '2.5M');
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
      find.byKey(const Key('house-rules-button')).hitTestable(),
      findsOneWidget,
    );
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
    expect(find.byKey(const Key('felt-label')), findsNothing);
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

  testWidgets('house rules chosen before a game apply to the next match', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('quick-play')));
    await tester.pumpAndSettle();
    expect(container.read(matchSetupProvider).rules, const HouseRules());
    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('leave-confirm')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('leave-confirm')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('single-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('house-rules-button')));
    await tester.pumpAndSettle();
    expect(find.byType(HouseRulesScreen), findsOneWidget);
    for (final rule in [
      'rule-man-cards',
      'rule-superman',
      'rule-alter-maal',
      'rule-joker-penalty',
    ]) {
      await tester.ensureVisible(find.byKey(Key(rule)));
      await tester.tap(find.byKey(Key(rule)));
      await tester.pump();
    }
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('setup-play')));
    // Pumped for a while rather than settled: a joker in the hand glows
    // for as long as it's held.
    await tester.pump(const Duration(seconds: 2));
    final config = container.read(gameConfigProvider);
    expect(config.manCardsEnabled, isTrue);
    expect(config.supermanCardEnabled, isTrue);
    expect(config.alterIsMaal, isFalse);
    expect(config.jokerDiscardPenaltyEnabled, isFalse);
  });

  testWidgets('the settings popover no longer holds a house rule', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setting-joker-penalty')), findsNothing);
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

  testWidgets('a debug build offers a test crash where reports are sent', (
    tester,
  ) async {
    var crashes = 0;
    await pumpHome(
      tester,
      overrides: [testCrashProvider.overrideWithValue(() => crashes++)],
    );

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-test-crash')));

    expect(crashes, 1);
  });

  testWidgets('without crash reporting there\'s no test crash', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setting-test-crash')), findsNothing);
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
