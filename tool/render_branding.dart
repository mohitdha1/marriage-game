// Draws the app icon and splash logo with the game's own card faces and
// saves them as PNGs in assets/branding/, for flutter_launcher_icons and
// flutter_native_splash to turn into each platform's files. Also draws the
// store's feature graphic into docs/store/.
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
import 'package:image/image.dart' as img;
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

/// The store's 1024 × 500 banner: the name and a line about the game beside
/// the pair, on the Classic table.
class FeatureGraphic extends StatelessWidget {
  const FeatureGraphic({super.key});

  @override
  Widget build(BuildContext context) => TableFelt(
    rim: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marriage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'The Nepali card game, against smart bots',
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 380,
            child: Transform.translate(
              offset: const Offset(0, 20),
              child: const FannedPair(scale: 0.22),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> save(
  WidgetTester tester,
  Widget art,
  String path, {
  Size frame = const Size.square(size),
}) async {
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
            child: SizedBox.fromSize(size: frame, child: art),
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
    // A JPEG when asked for one: the store's banner has no see-through
    // parts, and its felt makes a PNG much larger.
    final List<int> bytes;
    if (path.endsWith('.jpg')) {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      bytes = img.encodeJpg(
        img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: rgba!.buffer,
          numChannels: 4,
        ),
        quality: 90,
      );
    } else {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
    }
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
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
    await save(
      tester,
      const FeatureGraphic(),
      'docs/store/feature-graphic.jpg',
      frame: const Size(1024, 500),
    );
  });
}
