import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/joker.dart';
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
    this.groupOf,
    this.jokers,
    this.onCardTap,
    this.onDraw,
  });

  final List<HandCard> cards;
  final double cardWidth;

  /// Ids of the selected cards.
  final Set<int> selected;

  /// Which grouped set a card belongs to, if any. Grouped cards get a
  /// coloured strip, and a small gap separates each group from the next.
  final int? Function(int cardId)? groupOf;

  /// The jokers, once seen; wild cards are then marked with a badge.
  final Jokers? jokers;

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

  /// Extra space between groups, as a share of a card's width.
  static const _groupGap = 0.25;

  /// Strip colours for grouped sets, reused if there are more groups.
  static const groupColors = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFE53935),
    Color(0xFF6D4C41),
  ];

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

        int? group(int i) => groupOf?.call(cards[i].id);
        // A gap goes wherever one card and the next aren't in the same group,
        // as long as at least one of them is grouped.
        final gapBefore = [
          for (var i = 0; i < n; i++)
            i > 0 &&
                group(i) != group(i - 1) &&
                (group(i) != null || group(i - 1) != null),
        ];
        final gapCount = gapBefore.where((g) => g).length;
        final gap = cardWidth * _groupGap;

        final usableWidth =
            constraints.maxWidth - 2 * overhangX - gap * gapCount;
        final spacing = n == 1
            ? 0.0
            : min(cardWidth * _maxSpacing, (usableWidth - cardWidth) / (n - 1));
        final offsets = <double>[];
        for (var i = 0; i < n; i++) {
          offsets.add(
            i == 0 ? 0 : offsets[i - 1] + spacing + (gapBefore[i] ? gap : 0),
          );
        }
        // Cards sit on a circle; its radius follows from the spacing and the
        // turn between neighbours.
        final radius = spacing / turn;
        final drops = [
          for (var i = 0; i < n; i++) radius * (1 - cos((i - middle) * turn)),
        ];
        final fanWidth = offsets.last + cardWidth;
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
                  left: left + offsets[i],
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
                      wild: jokers?.isWild(cards[i].card) ?? false,
                      groupColor: switch (group(i)) {
                        null => null,
                        final g => groupColors[g % groupColors.length],
                      },
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
    required this.wild,
    required this.groupColor,
    required this.onTap,
  });

  final HandCard handCard;
  final double width;
  final bool selected;
  final bool wild;
  final Color? groupColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = CardFace(
      handCard.card,
      width: width,
      highlighted: selected,
      wild: wild,
      groupColor: groupColor,
    );
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
