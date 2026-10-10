import 'package:flutter/material.dart';

import '../../engine/card.dart';

/// Red for hearts and diamonds, as printed on a white card.
const redSuitColor = Color(0xFFC62828);

/// A lighter red that still reads well on the dark green table.
const redSuitOnDark = Color(0xFFFF6B6B);

/// A card suit drawn as a vector shape.
///
/// Drawn rather than typed, because Android renders the ♠ ♥ ♦ ♣ characters
/// as colour emoji, which clash with the cards and the rest of the text.
class SuitIcon extends StatelessWidget {
  const SuitIcon(
    this.suit, {
    super.key,
    required this.size,
    required this.color,
  });

  final Suit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: suit.name,
      child: CustomPaint(
        size: Size.square(size),
        painter: _SuitPainter(suit, color),
      ),
    );
  }
}

/// Text in which any suit symbols (as in "Took 9♣, threw K♥") are drawn as
/// [SuitIcon]s: red for hearts and diamonds, and the text's own colour for
/// spades and clubs. Screen readers still read the original [text].
class SuitText extends StatelessWidget {
  const SuitText(
    this.text, {
    super.key,
    this.style,
    this.redColor = redSuitOnDark,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;

  /// The colour for hearts and diamonds.
  final Color redColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  static final _suitSymbols = {
    for (final suit in Suit.values) suit.symbol: suit,
  };

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = resolved.fontSize ?? 14;
    final spans = <InlineSpan>[];
    final plain = StringBuffer();
    for (final character in text.characters) {
      final suit = _suitSymbols[character];
      if (suit == null) {
        plain.write(character);
        continue;
      }
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain.toString()));
        plain.clear();
      }
      final isRed = suit == Suit.hearts || suit == Suit.diamonds;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SuitIcon(
            suit,
            size: fontSize * 0.85,
            color: isRed ? redColor : (resolved.color ?? Colors.black),
          ),
        ),
      );
    }
    if (plain.isNotEmpty) spans.add(TextSpan(text: plain.toString()));

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: text,
    );
  }
}

/// Paints one suit, filling a square.
class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width, size.height);
    canvas.drawPath(suitShape(suit), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuitPainter old) =>
      old.suit != suit || old.color != color;
}

/// [suit]'s outline in a 1 × 1 square.
Path suitShape(Suit suit) => switch (suit) {
  Suit.diamonds =>
    Path()
      ..moveTo(0.5, 0.02)
      ..lineTo(0.88, 0.5)
      ..lineTo(0.5, 0.98)
      ..lineTo(0.12, 0.5)
      ..close(),
  Suit.hearts =>
    Path()
      ..moveTo(0.5, 0.94)
      ..cubicTo(0.18, 0.70, 0.0, 0.50, 0.04, 0.30)
      ..cubicTo(0.09, 0.08, 0.40, 0.04, 0.5, 0.26)
      ..cubicTo(0.60, 0.04, 0.91, 0.08, 0.96, 0.30)
      ..cubicTo(1.0, 0.50, 0.82, 0.70, 0.5, 0.94)
      ..close(),
  Suit.spades =>
    Path()
      ..moveTo(0.5, 0.02)
      ..cubicTo(0.80, 0.30, 1.0, 0.42, 0.96, 0.60)
      ..cubicTo(0.92, 0.80, 0.62, 0.82, 0.53, 0.66)
      ..cubicTo(0.56, 0.80, 0.62, 0.92, 0.70, 0.98)
      ..lineTo(0.30, 0.98)
      ..cubicTo(0.38, 0.92, 0.44, 0.80, 0.47, 0.66)
      ..cubicTo(0.38, 0.82, 0.08, 0.80, 0.04, 0.60)
      ..cubicTo(0.0, 0.42, 0.20, 0.30, 0.5, 0.02)
      ..close(),
  // Three leaves and a stem, joined into one outline. Adding them to one
  // path would leave a gap where the stem meets the leaves, because their
  // outlines run in opposite directions and cancel out there.
  Suit.clubs => Path.combine(
    PathOperation.union,
    Path()
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.27), radius: 0.22))
      ..addOval(Rect.fromCircle(center: const Offset(0.26, 0.56), radius: 0.22))
      ..addOval(
        Rect.fromCircle(center: const Offset(0.74, 0.56), radius: 0.22),
      ),
    Path()
      ..moveTo(0.46, 0.38)
      ..cubicTo(0.45, 0.75, 0.40, 0.90, 0.30, 0.98)
      ..lineTo(0.70, 0.98)
      ..cubicTo(0.60, 0.90, 0.55, 0.75, 0.54, 0.38)
      ..close(),
  ),
};
