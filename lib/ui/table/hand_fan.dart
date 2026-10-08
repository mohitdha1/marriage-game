import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/card.dart';
import 'card_view.dart';

/// The human player's cards, overlapped and fanned along a gentle arc so a
/// full 21–22 card hand fits across a landscape screen.
class HandFan extends StatelessWidget {
  const HandFan({super.key, required this.cards, required this.cardWidth});

  final List<PlayingCard> cards;
  final double cardWidth;

  /// Largest gap between neighbouring cards, as a share of a card's width,
  /// so small hands still overlap a little.
  static const _maxSpacing = 0.75;

  /// Most a card turns relative to its neighbour, in radians.
  static const _maxTurn = 0.02;

  @override
  Widget build(BuildContext context) {
    final cardHeight = cardWidth / cardAspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cards.length;
        if (n == 0) return SizedBox(height: cardHeight);

        final turn = min(_maxTurn, 0.4 / n);
        final middle = (n - 1) / 2;
        final outerAngle = middle * turn;
        // A tilted card is wider and taller than an upright one. Reserve that
        // overhang so the outermost cards stay fully on screen.
        final overhangX =
            (cardWidth * cos(outerAngle) +
                cardHeight * sin(outerAngle) -
                cardWidth) /
            2;
        final overhangY =
            (cardWidth * sin(outerAngle) +
                cardHeight * cos(outerAngle) -
                cardHeight) /
            2;

        final usableWidth = constraints.maxWidth - 2 * overhangX;
        final spacing = n == 1
            ? 0.0
            : min(cardWidth * _maxSpacing, (usableWidth - cardWidth) / (n - 1));
        // Cards sit on a circle; its radius follows from the spacing and the
        // turn between neighbours.
        final radius = spacing / turn;
        final drops = [
          for (var i = 0; i < n; i++) radius * (1 - cos((i - middle) * turn)),
        ];
        final fanWidth = spacing * (n - 1) + cardWidth;
        final left = (constraints.maxWidth - fanWidth) / 2;

        return SizedBox(
          height: cardHeight + drops.reduce(max) + 2 * overhangY,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: left + spacing * i,
                  top: drops[i] + overhangY,
                  child: Transform.rotate(
                    angle: (i - middle) * turn,
                    child: CardFace(cards[i], width: cardWidth),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
