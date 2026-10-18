import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/avatar_look.dart';
import 'package:marriage_game/ui/home/player_avatar.dart';

Future<void> pumpAvatar(WidgetTester tester, PlayerAvatar avatar) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: avatar)),
      ),
    );

/// The painter drawing the face, if the avatar has one.
AvatarPainter? faceOf(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(PlayerAvatar),
      matching: find.byType(CustomPaint),
    ),
  )) {
    if (paint.painter case final AvatarPainter painter) return painter;
  }
  return null;
}

void main() {
  test('initials are the first letters of up to two words', () {
    expect(initialsOf('Mohit'), 'M');
    expect(initialsOf('ram bahadur thapa'), 'RB');
    expect(initialsOf('  Gita  '), 'G');
    expect(initialsOf(''), '?');
  });

  test('there are twenty looks to choose from, all different', () {
    final looks = AvatarLook.presets;

    expect(looks, hasLength(20));
    expect({
      for (final l in looks)
        (l.background, l.skin, l.hair, l.hairColor, l.shirt, l.extra),
    }, hasLength(20));
  });

  testWidgets('a look is drawn as a face in a round frame', (tester) async {
    await pumpAvatar(
      tester,
      const PlayerAvatar(name: 'Gita', look: 7, radius: 30),
    );

    expect(faceOf(tester)?.look, AvatarLook.presets[7]);
    expect(find.text('G'), findsNothing);
    expect(tester.getSize(find.byType(PlayerAvatar)), const Size(60, 60));
    expect(find.bySemanticsLabel('Avatar of Gita'), findsOneWidget);
  });

  testWidgets('without a look, the initials show instead', (tester) async {
    for (final look in [null, -1, 99]) {
      await pumpAvatar(tester, PlayerAvatar(name: 'Ram Bahadur', look: look));

      expect(faceOf(tester), isNull, reason: '$look');
      expect(find.text('RB'), findsOneWidget, reason: '$look');
    }
  });

  testWidgets('every look draws at any size without trouble', (tester) async {
    for (final radius in [8.0, 16.0, 48.0]) {
      await pumpAvatar(tester, PlayerAvatar(name: 'x', radius: radius));
      await tester.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (var i = 0; i < AvatarLook.presets.length; i++)
                PlayerAvatar(name: 'x', look: i, radius: radius),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
