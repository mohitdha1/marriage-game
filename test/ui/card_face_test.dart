import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/ui/table/card_face_art.dart';
import 'package:marriage_game/ui/table/card_view.dart';

const numberRanks = [
  Rank.two,
  Rank.three,
  Rank.four,
  Rank.five,
  Rank.six,
  Rank.seven,
  Rank.eight,
  Rank.nine,
  Rank.ten,
];

Future<void> pumpFace(WidgetTester tester, PlayingCard card) => tester
    .pumpWidget(MaterialApp(home: Center(child: CardFace(card, width: 80))));

void main() {
  group('pipLayout', () {
    test('a number card has as many pips as its number', () {
      for (final rank in numberRanks) {
        expect(pipLayout(rank), hasLength(rank.order), reason: '$rank');
      }
    });

    test('aces and court cards have no pips', () {
      for (final rank in [Rank.ace, Rank.jack, Rank.queen, Rank.king]) {
        expect(pipLayout(rank), isEmpty, reason: '$rank');
      }
    });

    test('every pattern but the seven looks the same turned upside down', () {
      // A printed seven's extra pip sits in the top half only.
      for (final rank in numberRanks.where((r) => r != Rank.seven)) {
        final pips = pipLayout(rank).toSet();
        final turned = {for (final pip in pips) Offset(1 - pip.dx, 1 - pip.dy)};
        // Compared with a little tolerance, for the thirds on 9 and 10.
        for (final pip in turned) {
          expect(
            pips.any((p) => (p - pip).distance < 1e-9),
            isTrue,
            reason: '$rank has no pip opposite $pip',
          );
        }
      }
    });

    test(
      'pips stay in the left, middle and right columns, within the area',
      () {
        for (final rank in numberRanks) {
          for (final pip in pipLayout(rank)) {
            expect([0.0, 0.5, 1.0], contains(pip.dx));
            expect(pip.dy, inInclusiveRange(0, 1));
          }
        }
      },
    );
  });

  group('Court art', () {
    test('every jack, queen and king has its figure bundled', () {
      for (final suit in Suit.values) {
        for (final rank in [Rank.jack, Rank.queen, Rank.king]) {
          final path = courtArtAsset(PlayingCard(suit, rank));
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('the court art folder is bundled with the app', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/cards/court/'),
      );
    });

    test('isCourt is true for J, Q and K only', () {
      expect(Rank.values.where(isCourt), [Rank.jack, Rank.queen, Rank.king]);
    });
  });

  group('CardFace', () {
    testWidgets('a number card shows its rank in both corners, and pips', (
      tester,
    ) async {
      await pumpFace(tester, const PlayingCard(Suit.hearts, Rank.seven));

      expect(find.text('7'), findsNWidgets(2));
      expect(find.byKey(const Key('pips')), findsOneWidget);
      expect(find.byKey(const Key('court-art')), findsNothing);
    });

    testWidgets('a court card shows its figure', (tester) async {
      await pumpFace(tester, const PlayingCard(Suit.spades, Rank.queen));

      expect(find.text('Q'), findsNWidgets(2));
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('court-art')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/cards/court/QS.jpg',
      );
      expect(find.byKey(const Key('pips')), findsNothing);
    });

    testWidgets('an ace has one large pip and no figure', (tester) async {
      await pumpFace(tester, const PlayingCard(Suit.clubs, Rank.ace));

      expect(find.text('A'), findsNWidgets(2));
      expect(find.byKey(const Key('pips')), findsNothing);
      expect(find.byKey(const Key('court-art')), findsNothing);
    });

    testWidgets('a man card shows M in both corners and a figure', (
      tester,
    ) async {
      await pumpFace(tester, const PlayingCard.man());

      expect(find.text('M'), findsNWidgets(2));
      expect(find.byKey(const Key('man-art')), findsOneWidget);
      expect(find.byKey(const Key('pips')), findsNothing);
      expect(find.bySemanticsLabel('Man'), findsOneWidget);
    });

    testWidgets('screen readers hear the card once, by name', (tester) async {
      await pumpFace(tester, const PlayingCard(Suit.diamonds, Rank.ten));

      expect(find.bySemanticsLabel('10♦'), findsOneWidget);
    });
  });
}
