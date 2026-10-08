import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../state/table_state.dart';
import 'card_view.dart';

/// The human player's cards, overlapped and fanned along a gentle arc so a
/// full 21–22 card hand fits across a landscape screen.
///
/// Tapping a card selects it (it lifts and gets a bright border); a card can
/// also be dragged onto the discard pile. Dropping the stock or the discard
/// pile onto the fan draws from it.
class HandFan extends StatelessWidget {
  const HandFan({
    super.key,
    required this.cards,
    required this.cardWidth,
    this.selected = const {},
    this.onCardTap,
    this.onDraw,
  });

  final List<HandCard> cards;
  final double cardWidth;

  /// Ids of the selected cards.
  final Set<int> selected;

  final void Function(int cardId)? onCardTap;

  /// Called when a pile is dragged onto the fan.
  final void Function(DrawSource source)? onDraw;

  /// Largest gap between neighbouring cards, as a share of a card's width,
  /// so small hands still overlap a little.
  static const _maxSpacing = 0.75;

  /// Most a card turns relative to its neighbour, in radians.
  static const _maxTurn = 0.02;

  /// How far a selected card lifts, as a share of a card's height.
  static const _lift = 0.2;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DrawSource>(
      onAcceptWithDetails: (details) => onDraw?.call(details.data),
      builder: (context, candidates, rejected) => _fan(),
    );
  }

  Widget _fan() {
    final cardHeight = cardWidth / cardAspectRatio;
    final lift = cardHeight * _lift;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cards.length;
        if (n == 0) return SizedBox(height: cardHeight + lift);

        final turn = min(_maxTurn, 0.4 / n);
        final middle = (n - 1) / 2;
        final outerAngle = middle * turn;
        // A tilted card is wider and taller than an upright one. Reserve that
        // overhang so the outermost cards stay inside the fan.
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
        // Room above the cards for a selected card to lift into.
        final top = lift + overhangY;

        return SizedBox(
          height: top + cardHeight + drops.reduce(max) + overhangY,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  key: ValueKey(cards[i].id),
                  left: left + spacing * i,
                  top:
                      top +
                      drops[i] -
                      (selected.contains(cards[i].id) ? lift : 0),
                  child: Transform.rotate(
                    angle: (i - middle) * turn,
                    child: _HandCardView(
                      handCard: cards[i],
                      width: cardWidth,
                      selected: selected.contains(cards[i].id),
                      onTap: onCardTap == null
                          ? null
                          : () => onCardTap!(cards[i].id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One card in the hand: tap to select, drag to discard.
class _HandCardView extends StatelessWidget {
  const _HandCardView({
    required this.handCard,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final HandCard handCard;
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = CardFace(handCard.card, width: width, highlighted: selected);
    return Draggable<HandCard>(
      data: handCard,
      feedback: Material(
        color: Colors.transparent,
        child: CardFace(handCard.card, width: width, highlighted: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: face),
      child: GestureDetector(onTap: onTap, child: face),
    );
  }
}
