import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../../engine/round.dart';
import '../state/table_state.dart';
import 'card_view.dart';
import 'hand_fan.dart';

/// The middle of the table: the face-down stock and the face-up discard
/// pile, side by side.
///
/// Tap the stock to draw from it, or the discard pile to take its top card,
/// or — once a card is drawn — to discard the selected card. Dragging
/// either pile draws from it as the drag begins, and the drawn card follows
/// the finger ([drawnCard]) to be placed in the hand. A card dragged from
/// the hand onto the discard pile is discarded.
class TableCenter extends StatelessWidget {
  const TableCenter({
    super.key,
    required this.stockCount,
    required this.topDiscard,
    required this.cardWidth,
    this.onStockTap,
    this.onDiscardPileTap,
    this.onCardDropped,
    this.onPileDragStarted,
    this.onPileDragEnded,
    this.drawnCard,
    this.stockKey,
    this.discardKey,
  });

  final int stockCount;
  final PlayingCard? topDiscard;
  final double cardWidth;
  final VoidCallback? onStockTap;
  final VoidCallback? onDiscardPileTap;

  /// Called with the id of a hand card dropped on the discard pile, and the
  /// card's centre where it was let go, in global coordinates.
  final void Function(int cardId, Offset droppedAt)? onCardDropped;

  /// Called when a pile starts being dragged.
  final void Function(DrawSource source)? onPileDragStarted;

  /// Called when a dragged pile card is let go, with the card's centre
  /// where it was let go, in global coordinates, and whether the hand took
  /// it.
  final void Function(DrawSource source, Offset releasedAt, bool placed)?
  onPileDragEnded;

  /// The card drawn by the drag under way, once known. Until then a card
  /// dragged from the stock shows its back; once known, it flips face up.
  final ValueListenable<PlayingCard?>? drawnCard;

  /// Keys marking where the stock and discard pile are, for animations.
  final GlobalKey? stockKey;
  final GlobalKey? discardKey;

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
          child: KeyedSubtree(
            key: stockKey,
            child: stockCount == 0
                ? CardSlot(width: cardWidth)
                : _pileDraggable(
                    DrawSource.stock,
                    shown: null,
                    childWhenDragging: _StackedBacks(width: cardWidth),
                    child: _StackedBacks(width: cardWidth),
                  ),
          ),
        ),
        SizedBox(width: cardWidth * 0.6),
        // Takes a card dragged straight up as well as one picked up with a
        // long press.
        DragTarget<Object>(
          onWillAcceptWithDetails: (details) =>
              details.data is HandCard || details.data is QuickDiscard,
          onAcceptWithDetails: (details) {
            final card = switch (details.data) {
              final HandCard card => card,
              QuickDiscard(:final card) => card,
              _ => null,
            };
            if (card == null) return;
            final centre = Offset(
              cardWidth / 2,
              cardWidth / cardAspectRatio / 2,
            );
            onCardDropped?.call(card.id, details.offset + centre);
          },
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
              child: KeyedSubtree(
                key: discardKey,
                child: discard == null
                    ? face
                    : _pileDraggable(
                        DrawSource.discardPile,
                        shown: discard,
                        childWhenDragging: CardSlot(width: cardWidth),
                        child: face,
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// The [source] pile as something to drag, showing [shown] (its back
  /// when `null`) under the finger until the drawn card is known.
  Widget _pileDraggable(
    DrawSource source, {
    required PlayingCard? shown,
    required Widget childWhenDragging,
    required Widget child,
  }) {
    final centre = Offset(cardWidth / 2, cardWidth / cardAspectRatio / 2);
    return Draggable<PileDraw>(
      data: PileDraw(source),
      feedback: Material(
        color: Colors.transparent,
        child: _DrawnCard(drawn: drawnCard, shown: shown, width: cardWidth),
      ),
      childWhenDragging: childWhenDragging,
      onDragStarted: () => onPileDragStarted?.call(source),
      onDragEnd: (details) => onPileDragEnded?.call(
        source,
        details.offset + centre,
        details.wasAccepted,
      ),
      child: child,
    );
  }
}

/// The card under the finger while a pile is dragged: [shown] (a back
/// when `null`) until [drawn] says which card was drawn, then that card,
/// turned face up with a flip if it was face down.
class _DrawnCard extends StatefulWidget {
  const _DrawnCard({
    required this.drawn,
    required this.shown,
    required this.width,
  });

  final ValueListenable<PlayingCard?>? drawn;
  final PlayingCard? shown;
  final double width;

  @override
  State<_DrawnCard> createState() => _DrawnCardState();
}

class _DrawnCardState extends State<_DrawnCard>
    with SingleTickerProviderStateMixin {
  late final _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    widget.drawn?.addListener(_drawnChanged);
  }

  var _checkedDrawn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A card drawn on this device is already known as the drag begins.
    if (_checkedDrawn) return;
    _checkedDrawn = true;
    _drawnChanged();
  }

  @override
  void dispose() {
    widget.drawn?.removeListener(_drawnChanged);
    _flip.dispose();
    super.dispose();
  }

  void _drawnChanged() {
    if (widget.drawn?.value == null || widget.shown != null) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    reduceMotion ? _flip.value = 1 : _flip.forward();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final drawn = widget.drawn;
    if (drawn == null) return _face(widget.shown);
    return ValueListenableBuilder(
      valueListenable: drawn,
      builder: (context, card, _) => AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          if (widget.shown != null) return _face(card ?? widget.shown);
          // Turns edge-on showing the back, then on round showing the face.
          final angle = Curves.easeInOut.transform(_flip.value) * pi;
          final faceUp = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(faceUp ? angle - pi : angle),
            child: faceUp && card != null
                ? CardFace(card, width: width)
                : CardBack(width: width),
          );
        },
      ),
    );
  }

  Widget _face(PlayingCard? card) => card == null
      ? CardBack(width: widget.width)
      : CardFace(card, width: widget.width);
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
