import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/avatar_look.dart';

/// A round avatar in a gold frame: the drawn face numbered [look] among
/// [AvatarLook.presets], or, without one, the initials of [name] on
/// [color].
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.look,
    this.color = const Color(0xFFFFE0B2),
    this.radius = 20,
  });

  final String name;
  final int? look;
  final Color color;
  final double radius;

  /// The look numbered [look], if there is one.
  static AvatarLook? lookOf(int? look) =>
      look != null && look >= 0 && look < AvatarLook.presets.length
      ? AvatarLook.presets[look]
      : null;

  @override
  Widget build(BuildContext context) {
    final drawn = lookOf(look);
    final size = radius * 2;
    return Semantics(
      label: 'Avatar of $name',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: drawn == null
              ? _InitialsBackground(color)
              : AvatarPainter(drawn),
          foregroundPainter: const _GoldFrame(),
          child: drawn == null
              ? Center(
                  child: Text(
                    initialsOf(name),
                    style: TextStyle(
                      color: const Color(0xFF263238),
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.8,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Up to two initials of [name]: "Mohit" → "M", "Ram Bahadur" → "RB", and
/// "?" for no name.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

class _InitialsBackground extends CustomPainter {
  const _InitialsBackground(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 2,
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_InitialsBackground old) => old.color != color;
}

/// The round gold frame every avatar sits in.
class _GoldFrame extends CustomPainter {
  const _GoldFrame();

  @override
  void paint(Canvas canvas, Size size) {
    final width = max(1.5, size.shortestSide * 0.07);
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2 - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFC79100),
            Color(0xFFFFD54F),
            Color(0xFFB8860B),
            Color(0xFFFFE082),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GoldFrame old) => false;
}

/// Draws an [AvatarLook]: background, shoulders, face and hair, and any
/// extra, all inside a circle.
class AvatarPainter extends CustomPainter {
  const AvatarPainter(this.look);

  final AvatarLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset at(double x, double y) => Offset(x * s, y * s);
    Rect box(double x, double y, double w, double h) =>
        Rect.fromCenter(center: at(x, y), width: w * s, height: h * s);
    Paint fill(int color) => Paint()..color = Color(color);
    final skin = Color(look.skin);
    final shade = Color.lerp(skin, Colors.black, 0.18)!;
    final hair = fill(look.hairColor);
    const ink = Color(0xFF2B1B12);

    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & Size.square(s)));
    canvas.drawRect(Offset.zero & Size.square(s), fill(look.background));

    // Hair that falls behind the head.
    switch (look.hair) {
      case HairStyle.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            box(0.5, 0.52, 0.6, 0.6),
            Radius.circular(s * 0.2),
          ),
          hair,
        );
      case HairStyle.ponytail:
        canvas.drawOval(box(0.76, 0.46, 0.16, 0.34), hair);
      case HairStyle.bun:
        canvas.drawCircle(at(0.5, 0.17), s * 0.1, hair);
      default:
        break;
    }

    // Shoulders and neck.
    canvas.drawOval(box(0.5, 1.02, 0.9, 0.5), fill(look.shirt));
    canvas.drawRect(box(0.5, 0.71, 0.14, 0.16), Paint()..color = shade);
    if (look.extra == AvatarExtra.scarf) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box(0.5, 0.79, 0.4, 0.09),
          Radius.circular(s * 0.05),
        ),
        Paint()..color = Color.lerp(Color(look.shirt), Colors.white, 0.45)!,
      );
    }

    // Ears and face.
    final face = Paint()..color = skin;
    canvas.drawCircle(at(0.28, 0.48), s * 0.05, face);
    canvas.drawCircle(at(0.72, 0.48), s * 0.05, face);
    canvas.drawOval(box(0.5, 0.46, 0.44, 0.5), face);

    // Hair over the top of the head.
    final crown = box(0.5, 0.4, 0.48, 0.42);
    switch (look.hair) {
      case HairStyle.short ||
          HairStyle.long ||
          HairStyle.ponytail ||
          HairStyle.bun:
        canvas.drawArc(crown, pi, pi, true, hair);
        canvas.drawOval(box(0.4, 0.27, 0.26, 0.1), hair);
      case HairStyle.side:
        canvas.drawArc(crown, pi, pi, true, hair);
        canvas.drawPath(
          Path()
            ..moveTo(0.28 * s, 0.38 * s)
            ..quadraticBezierTo(0.45 * s, 0.24 * s, 0.7 * s, 0.33 * s)
            ..lineTo(0.7 * s, 0.26 * s)
            ..close(),
          hair,
        );
      case HairStyle.cropped:
        canvas.drawArc(box(0.5, 0.36, 0.44, 0.3), pi, pi, true, hair);
      case HairStyle.curly:
        for (var i = 0; i < 7; i++) {
          final a = pi + pi * i / 6;
          canvas.drawCircle(
            at(0.5 + 0.22 * cos(a), 0.36 + 0.17 * sin(a)),
            s * 0.075,
            hair,
          );
        }
      case HairStyle.bald:
        canvas.drawArc(
          box(0.5, 0.46, 0.46, 0.5),
          pi * 0.95,
          pi * 0.25,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04
            ..color = Color(look.hairColor),
        );
        canvas.drawArc(
          box(0.5, 0.46, 0.46, 0.5),
          pi * 1.8,
          pi * 0.25,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04
            ..color = Color(look.hairColor),
        );
    }

    // Eyes, brows, cheeks, nose and smile.
    final eye = Paint()..color = ink;
    canvas.drawCircle(at(0.41, 0.47), s * 0.028, eye);
    canvas.drawCircle(at(0.59, 0.47), s * 0.028, eye);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1, s * 0.022)
      ..color = ink;
    canvas.drawLine(at(0.37, 0.41), at(0.45, 0.405), line);
    canvas.drawLine(at(0.55, 0.405), at(0.63, 0.41), line);
    final blush = Paint()..color = const Color(0x40FF5252);
    canvas.drawCircle(at(0.36, 0.55), s * 0.035, blush);
    canvas.drawCircle(at(0.64, 0.55), s * 0.035, blush);
    canvas.drawArc(
      box(0.5, 0.52, 0.06, 0.05),
      0,
      pi,
      false,
      line..color = Color.lerp(shade, ink, 0.3)!,
    );
    canvas.drawArc(
      box(0.5, 0.58, 0.16, 0.09),
      0.15 * pi,
      0.7 * pi,
      false,
      line..color = ink,
    );

    // The extra.
    switch (look.extra) {
      case AvatarExtra.glasses:
        final frame = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, s * 0.022)
          ..color = const Color(0xFF263238);
        canvas.drawCircle(at(0.41, 0.47), s * 0.065, frame);
        canvas.drawCircle(at(0.59, 0.47), s * 0.065, frame);
        canvas.drawLine(at(0.475, 0.465), at(0.525, 0.465), frame);
      case AvatarExtra.topi:
        _drawTopi(canvas, s);
      case AvatarExtra.earrings:
        final gold = Paint()..color = const Color(0xFFFFC107);
        canvas.drawCircle(at(0.28, 0.55), s * 0.022, gold);
        canvas.drawCircle(at(0.72, 0.55), s * 0.022, gold);
      case AvatarExtra.moustache:
        canvas.drawPath(
          Path()
            ..moveTo(0.41 * s, 0.56 * s)
            ..quadraticBezierTo(0.5 * s, 0.515 * s, 0.59 * s, 0.56 * s)
            ..quadraticBezierTo(0.5 * s, 0.545 * s, 0.41 * s, 0.56 * s),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.03
            ..strokeCap = StrokeCap.round
            ..color = Color(look.hairColor),
        );
      case AvatarExtra.beard:
        canvas.drawPath(
          Path()
            ..moveTo(0.29 * s, 0.5 * s)
            ..quadraticBezierTo(0.3 * s, 0.74 * s, 0.5 * s, 0.75 * s)
            ..quadraticBezierTo(0.7 * s, 0.74 * s, 0.71 * s, 0.5 * s)
            ..quadraticBezierTo(0.66 * s, 0.62 * s, 0.5 * s, 0.63 * s)
            ..quadraticBezierTo(0.34 * s, 0.62 * s, 0.29 * s, 0.5 * s),
          Paint()..color = Color(look.hairColor).withValues(alpha: 0.9),
        );
      case AvatarExtra.scarf || AvatarExtra.none:
        break;
    }
    canvas.restore();
  }

  /// A dhaka topi: a soft cap, taller at the front, in a woven pattern.
  void _drawTopi(Canvas canvas, double s) {
    final cap = Path()
      ..moveTo(0.29 * s, 0.32 * s)
      ..lineTo(0.71 * s, 0.32 * s)
      ..lineTo(0.66 * s, 0.13 * s)
      ..quadraticBezierTo(0.5 * s, 0.1 * s, 0.36 * s, 0.17 * s)
      ..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFFF5F5F5));
    canvas.save();
    canvas.clipPath(cap);
    const weave = [
      Color(0xFFD32F2F),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFF9A825),
    ];
    final cell = s * 0.06;
    var i = 0;
    for (var y = 0.1 * s; y < 0.33 * s; y += cell) {
      for (var x = 0.28 * s; x < 0.72 * s; x += cell) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y + cell)
            ..lineTo(x + cell / 2, y)
            ..lineTo(x + cell, y + cell)
            ..close(),
          Paint()..color = weave[i++ % weave.length],
        );
      }
      i++;
    }
    canvas.restore();
    canvas.drawPath(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, s * 0.015)
        ..color = const Color(0x66000000),
    );
  }

  @override
  bool shouldRepaint(AvatarPainter old) => old.look != look;
}
