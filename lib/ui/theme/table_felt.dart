import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'table_theme.dart';

/// The current [TableTheme]'s felt filling its space: the theme's colours
/// with a fine woven texture, darkening towards the edges, and the theme's
/// kites when it has them. With [rim], a wooden rail runs round the edge,
/// as on a card table.
///
/// The felt sits on its own layer, so cards moving over it don't make it
/// repaint.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key, required this.child, this.rim = false});

  final Widget child;
  final bool rim;

  /// How wide the wooden rim is.
  static const rimWidth = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            key: const Key('felt'),
            painter: FeltPainter(theme: theme, rim: rim),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints [TableFelt]: the felt, its texture and kites, and the rim.
class FeltPainter extends CustomPainter {
  const FeltPainter({required this.theme, required this.rim});

  final TableTheme theme;
  final bool rim;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(
          radius: 1.2,
          colors: theme.felt,
        ).createShader(area),
    );
    _weave(canvas, size);
    if (theme.motif > 0) _kites(canvas, size, theme.motif);
    // Light falls on the middle of the table; the edges sit in shadow.
    canvas.drawRect(
      area,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x59000000)],
          stops: [0, 0.55, 1],
        ).createShader(area),
    );
    if (rim) _rim(canvas, size);
  }

  /// Specks of lighter and darker thread, scattered the same way every
  /// time, so the felt looks woven rather than flat.
  void _weave(Canvas canvas, Size size) {
    final random = Random(11);
    final count = (size.width * size.height / 9).round();
    Float32List specks() {
      // x and y for each speck, one after the other.
      final points = Float32List(count * 2);
      for (var i = 0; i < points.length; i += 2) {
        points[i] = random.nextDouble() * size.width;
        points[i + 1] = random.nextDouble() * size.height;
      }
      return points;
    }

    canvas
      ..drawRawPoints(
        ui.PointMode.points,
        specks(),
        Paint()
          ..color = const Color(0x12FFFFFF)
          ..strokeWidth = 1.2,
      )
      ..drawRawPoints(
        ui.PointMode.points,
        specks(),
        Paint()
          ..color = const Color(0x1A000000)
          ..strokeWidth = 1.2,
      );
  }

  /// Faint diamond kites with tails, scattered in a loose grid, at
  /// [strength] from 0 to 1.
  void _kites(Canvas canvas, Size size, double strength) {
    const spacing = 150.0;
    const kite = 26.0;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.06 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    var row = 0;
    for (var y = spacing / 2; y < size.height + kite; y += spacing * 0.7) {
      // Every other row shifts half a step, so the kites don't line up.
      final shift = row.isOdd ? spacing / 2 : 0.0;
      for (var x = shift; x < size.width + kite; x += spacing) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y - kite)
            ..lineTo(x + kite * 0.7, y)
            ..lineTo(x, y + kite)
            ..lineTo(x - kite * 0.7, y)
            ..close()
            ..moveTo(x, y - kite)
            ..lineTo(x, y + kite)
            ..moveTo(x - kite * 0.7, y)
            ..lineTo(x + kite * 0.7, y)
            // The tail.
            ..moveTo(x, y + kite)
            ..quadraticBezierTo(
              x + kite * 0.5,
              y + kite * 1.5,
              x,
              y + kite * 2,
            ),
          paint,
        );
      }
      row++;
    }
  }

  /// A rounded wooden rail round the edge: grain running along it, a
  /// highlight where its outer edge catches the light, a dark lip on the
  /// inside, and the soft shadow it casts onto the felt.
  void _rim(Canvas canvas, Size size) {
    const width = TableFelt.rimWidth;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final inner = outer.deflate(width);
    final rail = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
    final wood = theme.wood;

    // The shadow on the felt, just inside the rail.
    canvas
      ..save()
      ..clipRRect(inner)
      ..drawRRect(
        inner,
        Paint()
          ..color = const Color(0x8C000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..restore();

    canvas
      ..save()
      ..clipPath(rail)
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: wood,
          ).createShader(Offset.zero & size),
      );
    // Grain: thin lines following the rail at random depths across it.
    final random = Random(5);
    for (var i = 0; i < 14; i++) {
      final depth = 1 + random.nextDouble() * (width - 2);
      canvas.drawRRect(
        outer.deflate(depth),
        Paint()
          ..color = wood.last.withValues(
            alpha: 0.18 + random.nextDouble() * 0.3,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4 + random.nextDouble() * 0.8,
      );
    }
    // Rounded over: light along the outer half, shade along the inner.
    canvas
      ..drawRRect(
        outer.deflate(width * 0.3),
        Paint()
          ..color = const Color(0x24FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 0.35,
      )
      ..drawRRect(
        outer.deflate(1),
        Paint()
          ..color = const Color(0x40FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(
        inner.inflate(1),
        Paint()
          ..color = wood.last
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    final inlay = theme.inlay;
    if (inlay != null) {
      canvas.drawRRect(
        outer.deflate(width * 0.45),
        Paint()
          ..color = inlay
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FeltPainter old) => old.theme != theme || old.rim != rim;
}
