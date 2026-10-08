import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../../engine/round.dart';
import '../state/table_state.dart';
import 'card_view.dart';

/// The middle of the table: the face-down stock and the face-up discard
/// pile, side by side.
///
/// Tap the stock (or drag it onto the hand) to draw from it. Tap the discard
/// pile to take its top card, or — once you've drawn — to discard the
/// selected card. A card dragged from the hand onto the discard pile is
/// discarded.
class TableCenter extends StatelessWidget {
  const TableCenter({
    super.key,
    required this.stockCount,
    required this.topDiscard,
    required this.cardWidth,
    this.onStockTap,
    this.onDiscardPileTap,
    this.onCardDropped,
  });

  final int stockCount;
  final PlayingCard? topDiscard;
  final double cardWidth;
  final VoidCallback? onStockTap;
  final VoidCallback? onDiscardPileTap;

  /// Called with the id of a hand card dropped on the discard pile.
  final void Function(int cardId)? onCardDropped;

  @override
  Widget build(BuildContext context) {
    final discard = topDiscard;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pile(
          key: const Key('stock'),
          label: 'Stock · $stockCount',
          labelKey: const Key('stock-count'),
          onTap: onStockTap,
          child: stockCount == 0
              ? CardSlot(width: cardWidth)
              : Draggable<DrawSource>(
                  data: DrawSource.stock,
                  feedback: CardBack(width: cardWidth),
                  childWhenDragging: _StackedBacks(width: cardWidth),
                  child: _StackedBacks(width: cardWidth),
                ),
        ),
        SizedBox(width: cardWidth * 0.6),
        DragTarget<HandCard>(
          onAcceptWithDetails: (details) =>
              onCardDropped?.call(details.data.id),
          builder: (context, candidates, rejected) {
            final face = discard == null
                ? CardSlot(width: cardWidth)
                : CardFace(
                    discard,
                    width: cardWidth,
                    highlighted: candidates.isNotEmpty,
                  );
            return _Pile(
              key: const Key('discard-pile'),
              label: 'Discard',
              onTap: onDiscardPileTap,
              child: discard == null
                  ? face
                  : Draggable<DrawSource>(
                      data: DrawSource.discardPile,
                      feedback: Material(
                        color: Colors.transparent,
                        child: CardFace(discard, width: cardWidth),
                      ),
                      childWhenDragging: CardSlot(width: cardWidth),
                      child: face,
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _Pile extends StatelessWidget {
  const _Pile({
    super.key,
    required this.label,
    required this.child,
    this.labelKey,
    this.onTap,
  });

  final String label;
  final Key? labelKey;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
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
