// Draws the app icon and splash logo with the game's own card faces and
// saves them as PNGs in assets/branding/, for flutter_launcher_icons and
// flutter_native_splash to turn into each platform's files.
//
// Run from the project folder:
//   flutter test tool/render_branding.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/ui/table/card_face_art.dart';
import 'package:marriage_game/ui/table/card_view.dart';
import 'package:marriage_game/ui/theme/table_felt.dart';
import 'package:marriage_game/ui/theme/table_theme.dart';

import '../test/ui/real_fonts.dart';

/// The size every image is drawn at.
const size = 1024.0;

const queen = PlayingCard(Suit.hearts, Rank.queen);
const king = PlayingCard(Suit.hearts, Rank.king);

/// The queen and king of hearts, fanned. [scale] is the cards' width as a
/// share of the image.
class FannedPair extends StatelessWidget {
  const FannedPair({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final width = size * scale;
    Widget card(PlayingCard card, double turn, double shift) =>
        Transform.translate(
          offset: Offset(shift * width, 0),
          child: Transform.rotate(
            angle: turn,
            alignment: Alignment.bottomCenter,
            child: CardFace(card, width: width),
          ),
        );
    return Stack(
      alignment: Alignment.center,
      children: [card(queen, -0.22, -0.2), card(king, 0.22, 0.2)],
    );
  }
}

/// The full icon: the pair on the Classic felt.
class FullIcon extends StatelessWidget {
  const FullIcon({super.key});

  @override
  Widget build(BuildContext context) => const TableFelt(
    child: Padding(
      padding: EdgeInsets.only(top: size * 0.06),
      child: Center(child: FannedPair(scale: 0.4)),
    ),
  );
}

/// The pair alone on a clear background, at [scale].
///
/// Android's adaptive icon already insets its foreground to the part every
/// launcher's mask shows, so its pair is as large as on the full icon. The
/// splash logo is masked to its middle two thirds, so its pair is smaller.
class PairAlone extends StatelessWidget {
  const PairAlone({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: size * scale * 0.15),
    child: Center(child: FannedPair(scale: scale)),
  );
}

Future<void> save(WidgetTester tester, Widget art, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        extensions: const [TableTheme.classic],
      ),
      home: Material(
        type: MaterialType.transparency,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(dimension: size, child: art),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final card in [queen, king]) {
      await precacheImage(
        AssetImage(courtArtAsset(card)),
        tester.element(find.byKey(key)),
      );
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  stdout.writeln(path);
}

void main() {
  testWidgets('render the branding', (tester) async {
    await loadRealFonts();
    tester.view
      ..physicalSize = const Size.square(size)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await save(tester, const FullIcon(), 'assets/branding/icon.png');
    await save(
      tester,
      const PairAlone(scale: 0.4),
      'assets/branding/foreground.png',
    );
    await save(
      tester,
      const PairAlone(scale: 0.27),
      'assets/branding/splash.png',
    );
  });
}
