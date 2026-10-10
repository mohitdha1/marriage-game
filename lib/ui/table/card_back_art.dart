import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints a card back's printed field: a [field] gradient crossed by a fine,
/// embossed diamond lattice with a dot at every crossing, a double frame
/// with a small diamond in each corner, and a rosette in a medallion at the
/// centre. Every measure scales with the painted width, so the pattern
/// looks the same on a full-size card and a tiny one.
class CardBackPainter extends CustomPainter {
  const CardBackPainter({required this.field, required this.ink});

  /// The field's colours, top left to bottom right.
  final List<Color> field;

  /// The darker colour the lattice is printed in.
  final Color ink;

  /// The light lines: the frame and the rosette.
  static const _light = Color(0xE6FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final area = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(area, Radius.circular(w * 0.06));

    canvas
      ..save()
      ..clipRRect(rounded)
      ..drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: field,
          ).createShader(area),
      );
    _lattice(canvas, size);
    canvas.restore();

    // A double frame just inside the field's edge.
    final frame = Paint()
      ..color = _light
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.014);
    final outer = rounded.deflate(w * 0.05);
    canvas
      ..drawRRect(outer, frame)
      ..drawRRect(
        rounded.deflate(w * 0.085),
        frame..strokeWidth = max(0.4, w * 0.006),
      );
    for (final corner in [
      outer.outerRect.topLeft,
      outer.outerRect.topRight,
      outer.outerRect.bottomLeft,
      outer.outerRect.bottomRight,
    ]) {
      final towardsCentre = (size.center(Offset.zero) - corner);
      final at = corner + towardsCentre / towardsCentre.distance * w * 0.1;
      _diamond(canvas, at, w * 0.045);
    }
    _rosette(canvas, size.center(Offset.zero), w * 0.26);
  }

  /// A small solid diamond centred on [at].
  void _diamond(Canvas canvas, Offset at, double half) {
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy - half)
        ..lineTo(at.dx + half * 0.7, at.dy)
        ..lineTo(at.dx, at.dy + half)
        ..lineTo(at.dx - half * 0.7, at.dy)
        ..close(),
      Paint()..color = _light,
    );
  }

  /// Two sets of diagonal lines crossing into small diamonds. Each dark line
  /// has a faint light one beside it, so the lattice looks embossed, and a
  /// dot marks every crossing.
  void _lattice(Canvas canvas, Size size) {
    final step = size.width * 0.11;
    final thickness = max(0.5, size.width * 0.012);
    final dark = Paint()
      ..color = ink.withValues(alpha: 0.85)
      ..strokeWidth = thickness;
    final light = Paint()
      ..color = const Color(0x2EFFFFFF)
      ..strokeWidth = thickness;
    final nudge = Offset(thickness, 0);
    final h = size.height;
    final reach = size.width + h;
    for (var d = -h; d < reach; d += step) {
      for (final (paint, shift) in [(light, nudge), (dark, Offset.zero)]) {
        canvas
          ..drawLine(Offset(d, 0) + shift, Offset(d + h, h) + shift, paint)
          ..drawLine(Offset(d + h, 0) + shift, Offset(d, h) + shift, paint);
      }
    }
    // Lines from x = d (falling) and x = d' (rising) cross half way between
    // them, so crossings sit on a grid half a step apart.
    final dot = Paint()..color = const Color(0x40FFFFFF);
    for (var y = 0.0; y <= h; y += step / 2) {
      final row = (y / (step / 2)).round();
      for (var x = row.isEven ? 0.0 : step / 2; x <= size.width; x += step) {
        canvas.drawCircle(Offset(x, y), thickness * 0.9, dot);
      }
    }
  }

  /// A medallion holding an eight-petalled flower.
  void _rosette(Canvas canvas, Offset centre, double radius) {
    canvas.drawCircle(centre, radius, Paint()..color = field.last);
    final line = Paint()
      ..color = _light
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, radius * 0.06);
    canvas
      ..drawCircle(centre, radius, line)
      ..drawCircle(centre, radius * 0.82, line..strokeWidth = radius * 0.03);

    final petal = Paint()..color = _light;
    for (var i = 0; i < 8; i++) {
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(i * pi / 4)
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(radius * 0.22, -radius * 0.35, 0, -radius * 0.7)
            ..quadraticBezierTo(-radius * 0.22, -radius * 0.35, 0, 0),
          petal,
        )
        ..restore();
    }
    canvas.drawCircle(centre, radius * 0.14, Paint()..color = field.first);
  }

  @override
  bool shouldRepaint(CardBackPainter old) =>
      old.ink != ink || !listEquals(old.field, field);
}
