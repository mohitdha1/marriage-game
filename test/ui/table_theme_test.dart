import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/table/card_back_art.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/theme/table_felt.dart';
import 'package:marriage_game/ui/theme/table_theme.dart';

ProviderContainer containerWith(InMemoryPreferences store) {
  final container = ProviderContainer(
    overrides: [preferencesProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// The app showing a card back on the table felt, with [theme] saved as
/// the player's choice.
Future<void> pumpThemed(WidgetTester tester, TableThemeId theme) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(
          InMemoryPreferences({'settings.tableTheme': theme.name}),
        ),
      ],
      child: const MarriageApp(
        home: TableFelt(child: Center(child: CardBack(width: 60))),
      ),
    ),
  );
}

void main() {
  group('Table themes', () {
    test('there are three, each with its own name and look', () {
      expect(TableThemeId.values, hasLength(3));
      expect(TableThemeId.values.map((t) => t.label).toSet(), hasLength(3));
      expect(TableThemeId.values.map((t) => t.theme).toSet(), hasLength(3));
    });

    test('only Dashain has the kite pattern', () {
      expect(TableTheme.classic.motif, 0);
      expect(TableTheme.midnight.motif, 0);
      expect(TableTheme.dashain.motif, greaterThan(0));
    });

    test('blending runs from one theme to the other', () {
      const from = TableTheme.classic;
      const to = TableTheme.midnight;

      expect(from.lerp(to, 0).accent, from.accent);
      expect(from.lerp(to, 1).accent, to.accent);
      expect(from.lerp(to, 1).felt, to.felt);
      expect(from.lerp(to, 1).wood, to.wood);
      expect(from.lerp(to, 0.5).panel, Color.lerp(from.panel, to.panel, 0.5));
      expect(from.lerp(null, 0.5), same(from));
    });

    test('copyWith changes only what it is given', () {
      final copy = TableTheme.classic.copyWith(accent: Colors.pink);

      expect(copy.accent, Colors.pink);
      expect(copy.felt, TableTheme.classic.felt);
      expect(copy.cardBack, TableTheme.classic.cardBack);
    });

    testWidgets('without a theme attached, Classic is used', (tester) async {
      late TableTheme found;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              found = TableTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, same(TableTheme.classic));
    });
  });

  group('Felt', () {
    test('only the table has a rim, and each theme has its own wood', () {
      expect(
        TableThemeId.values.map((t) => t.theme.wood).toSet(),
        hasLength(3),
      );
      expect(TableTheme.dashain.inlay, isNotNull);
      expect(TableTheme.classic.inlay, isNull);
    });

    test('repaints only when the theme or the rim changes', () {
      const classic = FeltPainter(theme: TableTheme.classic, rim: true);

      expect(
        classic.shouldRepaint(
          const FeltPainter(theme: TableTheme.classic, rim: true),
        ),
        isFalse,
      );
      expect(
        classic.shouldRepaint(
          const FeltPainter(theme: TableTheme.midnight, rim: true),
        ),
        isTrue,
      );
      expect(
        classic.shouldRepaint(
          const FeltPainter(theme: TableTheme.classic, rim: false),
        ),
        isTrue,
      );
    });

    testWidgets('paints every theme, with and without a rim', (tester) async {
      for (final id in TableThemeId.values) {
        for (final rim in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [id.theme]),
              home: TableFelt(rim: rim, child: const SizedBox()),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$id, rim: $rim');
        }
      }
    });

    testWidgets('the felt is kept apart from what moves over it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: TableFelt(child: SizedBox())),
      );

      expect(
        find.ancestor(
          of: find.byKey(const Key('felt')),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });

  group('Card back pattern', () {
    const red = CardBackPainter(
      field: [Color(0xFFB71C1C), Color(0xFF6D1010)],
      ink: Color(0xFF8E1B1B),
    );

    test('repaints only when its colours change', () {
      expect(
        red.shouldRepaint(
          const CardBackPainter(
            field: [Color(0xFFB71C1C), Color(0xFF6D1010)],
            ink: Color(0xFF8E1B1B),
          ),
        ),
        isFalse,
      );
      expect(
        red.shouldRepaint(
          CardBackPainter(
            field: TableTheme.midnight.cardBack,
            ink: Color(0xFF8E1B1B),
          ),
        ),
        isTrue,
      );
      expect(
        red.shouldRepaint(
          const CardBackPainter(
            field: [Color(0xFFB71C1C), Color(0xFF6D1010)],
            ink: Color(0xFF000000),
          ),
        ),
        isTrue,
      );
    });

    testWidgets('paints at any size, down to the tiniest card', (tester) async {
      for (final width in [12.0, 28.0, 60.0, 120.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: CardBack(width: width)),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });
  });

  group('Choosing a theme', () {
    test('Classic is the default', () {
      expect(
        containerWith(InMemoryPreferences()).read(settingsProvider).tableTheme,
        TableThemeId.classic,
      );
    });

    test('the choice is saved and read back on the next launch', () {
      final store = InMemoryPreferences();
      containerWith(
        store,
      ).read(settingsProvider.notifier).setTableTheme(TableThemeId.dashain);

      expect(
        containerWith(store).read(settingsProvider).tableTheme,
        TableThemeId.dashain,
      );
    });

    test('a saved name that is no longer a theme falls back to Classic', () {
      final store = InMemoryPreferences({'settings.tableTheme': 'neon'});

      expect(
        containerWith(store).read(settingsProvider).tableTheme,
        TableThemeId.classic,
      );
    });

    for (final id in TableThemeId.values) {
      testWidgets('${id.label} colours the felt and the card backs', (
        tester,
      ) async {
        await pumpThemed(tester, id);
        final theme = id.theme;

        final felt =
            tester.widget<CustomPaint>(find.byKey(const Key('felt'))).painter!
                as FeltPainter;
        expect(felt.theme, same(theme));

        final back = tester.widget<CustomPaint>(
          find.byKey(const Key('card-back-pattern')),
        );
        final painter = back.painter! as CardBackPainter;
        expect(painter.field, theme.cardBack);
        expect(painter.ink, theme.cardBackEdge);
      });
    }
  });
}
