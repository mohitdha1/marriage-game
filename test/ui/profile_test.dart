import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/ui/home/home_screen.dart';
import 'package:marriage_game/ui/home/player_avatar.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';

import 'home_screen_test.dart' show pumpHome;

const notChosen = {'profile.chosen': false};

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('player-badge')));
  await tester.pumpAndSettle();
}

String? errorShown(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('profile-name')))
    .decoration
    ?.errorText;

void main() {
  late ProviderContainer container;

  group('The first launch', () {
    testWidgets('asks for a name and avatar before the home screen', (
      tester,
    ) async {
      container = await pumpHome(tester, saved: notChosen);

      expect(find.byKey(const Key('profile-setup')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byKey(const Key('profile-looks')), findsOneWidget);
      for (var i = 0; i < 20; i++) {
        expect(find.byKey(Key('look-$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      // Five to a row, every look on screen without scrolling.
      final first = tester.getRect(find.byKey(const Key('look-0')));
      expect(tester.getRect(find.byKey(const Key('look-4'))).top, first.top);
      expect(
        tester.getRect(find.byKey(const Key('look-5'))).top,
        greaterThan(first.top),
      );
      final screen = Offset.zero & tester.view.physicalSize;
      for (var i = 0; i < 20; i++) {
        final rect = tester.getRect(find.byKey(Key('look-$i')));
        expect(screen.contains(rect.bottomRight), isTrue, reason: 'look $i');
      }
    });

    testWidgets('Continue saves both and opens the home screen, for good', (
      tester,
    ) async {
      container = await pumpHome(tester, saved: notChosen);

      await tester.enterText(find.byKey(const Key('profile-name')), '  Asha  ');
      await tester.tap(find.byKey(const Key('look-5')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final profile = container.read(playerDataProvider).value!.profile;
      expect(profile.name, 'Asha');
      expect(profile.look, 5);
      expect(profile.chosen, isTrue);
      expect(
        tester
            .widget<PlayerAvatar>(
              find.descendant(
                of: find.byKey(const Key('player-badge')),
                matching: find.byType(PlayerAvatar),
              ),
            )
            .look,
        5,
      );
    });

    testWidgets('a player from before profiles starts from their old name', (
      tester,
    ) async {
      await pumpHome(tester, saved: {...notChosen, 'profile.name': 'Mohit'});

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('profile-name')))
            .controller
            ?.text,
        'Mohit',
      );
    });

    testWidgets('a name that breaks the rules is refused, saying why', (
      tester,
    ) async {
      container = await pumpHome(tester, saved: notChosen);

      for (final (name, why) in [
        ('A', 'Use at least 2 characters.'),
        ('bitch', 'Please choose a different name.'),
        ('Hi!', 'Use letters, numbers, spaces and . _ - only.'),
      ]) {
        await tester.enterText(find.byKey(const Key('profile-name')), name);
        await tester.tap(find.byKey(const Key('profile-save')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-setup')), findsOneWidget);
        expect(errorShown(tester), why, reason: name);
      }
      expect(container.read(playerDataProvider).value!.profile.chosen, isFalse);
    });

    testWidgets('the name field takes no more than 16 characters', (
      tester,
    ) async {
      await pumpHome(tester, saved: notChosen);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('profile-name')))
            .maxLength,
        16,
      );
    });
  });

  group('The profile', () {
    testWidgets('changes the name and avatar, kept after closing', (
      tester,
    ) async {
      container = await pumpHome(tester);
      await openProfile(tester);

      await tester.enterText(find.byKey(const Key('profile-name')), 'राम');
      await tester.tap(find.byKey(const Key('look-19')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-dialog')), findsNothing);
      final profile = container.read(playerDataProvider).value!.profile;
      expect(profile.name, 'राम');
      expect(profile.look, 19);
      expect(find.text('राम'), findsOneWidget);
    });

    testWidgets('a bad name stays in the dialog, with nothing saved', (
      tester,
    ) async {
      container = await pumpHome(tester);
      await openProfile(tester);

      await tester.enterText(find.byKey(const Key('profile-name')), 'a55');
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-dialog')), findsOneWidget);
      expect(errorShown(tester), 'Please choose a different name.');
      expect(container.read(playerDataProvider).value!.profile.name, 'Player');
    });

    testWidgets('fits a small phone held sideways', (tester) async {
      await pumpHome(tester);
      tester.view.physicalSize = const Size(667, 375);
      await tester.pump();
      await openProfile(tester);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('profile-save')));
      expect(
        find.byKey(const Key('profile-save')).hitTestable(),
        findsOneWidget,
      );
    });
  });
}
