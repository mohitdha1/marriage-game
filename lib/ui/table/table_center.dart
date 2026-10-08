import 'package:flutter/material.dart';

import '../../engine/card.dart';
import 'card_view.dart';

/// The middle of the table: the face-down stock and the face-up discard
/// pile, side by side.
class TableCenter extends StatelessWidget {
  const TableCenter({
    super.key,
    required this.stockCount,
    required this.topDiscard,
    required this.cardWidth,
  });

  final int stockCount;
  final PlayingCard? topDiscard;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final discard = topDiscard;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pile(
          label: 'Stock · $stockCount',
          labelKey: const Key('stock-count'),
          child: stockCount == 0
              ? CardSlot(width: cardWidth)
              : _StackedBacks(width: cardWidth),
        ),
        SizedBox(width: cardWidth * 0.6),
        _Pile(
          label: 'Discard',
          child: discard == null
              ? CardSlot(width: cardWidth)
              : CardFace(discard, width: cardWidth),
        ),
      ],
    );
  }
}

class _Pile extends StatelessWidget {
  const _Pile({required this.label, required this.child, this.labelKey});

  final String label;
  final Key? labelKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 4),
        Text(
          label,
          key: labelKey,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// A few card backs offset slightly, so the stock reads as a pile.
class _StackedBacks extends StatelessWidget {
  const _StackedBacks({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    const layers = 3;
    const shift = 2.0;
    return SizedBox(
      width: width + shift * (layers - 1),
      height: width / cardAspectRatio + shift * (layers - 1),
      child: Stack(
        children: [
          for (var i = 0; i < layers; i++)
            Positioned(
              left: shift * i,
              top: shift * (layers - 1 - i),
              child: CardBack(width: width),
            ),
        ],
      ),
    );
  }
}
