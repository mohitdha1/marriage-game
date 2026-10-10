import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/card.dart';
import 'suit_icon.dart';

/// Where the pips of a number card sit, as on a printed deck: each pip's
/// centre within the pip area, with x 0 (left column), 0.5 (middle) or 1
/// (right), and y from 0 (top) to 1 (bottom). Empty for aces and court
/// cards, which aren't drawn with pips.
List<Offset> pipLayout(Rank rank) {
  const left = 0.0, middle = 0.5, right = 1.0;
  List<Offset> sides(List<double> rows) => [
    for (final y in rows) ...[Offset(left, y), Offset(right, y)],
  ];
  return switch (rank) {
    Rank.two => const [Offset(middle, 0), Offset(middle, 1)],
    Rank.three => const [
      Offset(middle, 0),
      Offset(middle, 0.5),
      Offset(middle, 1),
    ],
    Rank.four => sides([0, 1]),
    Rank.five => [
      ...sides([0, 1]),
      const Offset(middle, 0.5),
    ],
    Rank.six => sides([0, 0.5, 1]),
    Rank.seven => [
      ...sides([0, 0.5, 1]),
      const Offset(middle, 0.25),
    ],
    Rank.eight => [
      ...sides([0, 0.5, 1]),
      const Offset(middle, 0.25),
      const Offset(middle, 0.75),
    ],
    Rank.nine => [
      ...sides([0, 1 / 3, 2 / 3, 1]),
      const Offset(middle, 0.5),
    ],
    Rank.ten => [
      ...sides([0, 1 / 3, 2 / 3, 1]),
      const Offset(middle, 1 / 6),
      const Offset(middle, 5 / 6),
    ],
    Rank.jack || Rank.queen || Rank.king || Rank.ace => const [],
  };
}

/// Whether [rank] is a jack, queen or king.
bool isCourt(Rank rank) =>
    rank == Rank.jack || rank == Rank.queen || rank == Rank.king;

/// The figure panel for a jack, queen or king, from Byron Knoll's
/// public-domain vector playing cards (see the README's credits).
String courtArtAsset(PlayingCard card) {
  assert(isCourt(card.rank), '$card has no court figure');
  final suit = switch (card.suit) {
    Suit.clubs => 'C',
    Suit.diamonds => 'D',
    Suit.hearts => 'H',
    Suit.spades => 'S',
  };
  return 'assets/cards/court/${card.rank.label}$suit.jpg';
}

/// Loads every court figure ahead of time, so the first jack, queen or king
/// dealt appears at once rather than a frame later.
Future<void> precacheCourtArt(BuildContext context) => Future.wait([
  for (final suit in Suit.values)
    for (final rank in [Rank.jack, Rank.queen, Rank.king])
      precacheImage(
        AssetImage(courtArtAsset(PlayingCard(suit, rank))),
        context,
      ),
]);

/// Paints a number card's pips at [pipLayout]'s positions, each [pipSize]
/// across, within the painted area. Pips in the bottom half are upside down,
/// as on a printed card.
class PipPainter extends CustomPainter {
  PipPainter({
    required this.suit,
    required this.pips,
    required this.pipSize,
    required this.color,
  });

  final Suit suit;
  final List<Offset> pips;
  final double pipSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = suitShape(suit);
    final paint = Paint()..color = color;
    for (final pip in pips) {
      canvas
        ..save()
        ..translate(pip.dx * size.width, pip.dy * size.height);
      if (pip.dy > 0.5) canvas.rotate(pi);
      canvas
        ..translate(-pipSize / 2, -pipSize / 2)
        ..scale(pipSize)
        ..drawPath(shape, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(PipPainter old) =>
      old.suit != suit ||
      old.pips != pips ||
      old.pipSize != pipSize ||
      old.color != color;
}
