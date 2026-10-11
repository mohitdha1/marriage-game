import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/joker.dart';
import '../../engine/round.dart';
import '../state/table_state.dart';
import 'card_view.dart';

/// The player's cards in an overlapping row, large enough to read and tap
/// easily: each card shows its left edge, with its rank and suit, and the
/// last shows in full. The row overlaps more as the hand grows, so a full
/// 21–22 card hand fits across a landscape screen. The bottom
/// [hiddenBelow] of each card may run off the screen's edge, which leaves
/// the cards large without crowding the table.
///
/// Tapping a card selects it (it lifts and gets a bright border). Dragging a
/// card straight up and letting go over the discard pile, or flicking it
/// upwards, discards it. Long-pressing a card picks it up to move it within
/// the hand (or onto the pile). Dropping the stock or the discard pile onto
/// the fan draws from it.
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
    this.onReorder,
    this.onFlick,
    this.onDropMissed,
    this.hiddenIds = const {},
    this.cardKey,
    this.hiddenBelow = 0,
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

  /// Called when a card is long-pressed and dropped back on the fan, with
  /// the position it was dropped at.
  final void Function(int cardId, int newIndex)? onReorder;

  /// Called when a card is flicked upwards, with the centre of the card
  /// where it was let go, in global coordinates.
  final void Function(int cardId, Offset releasedAt)? onFlick;

  /// Called when a dragged card is let go somewhere that doesn't take it,
  /// with the centre of the card where it was let go.
  final void Function(int cardId, Offset releasedAt)? onDropMissed;

  /// How fast, in logical pixels a second, an upward release must be to
  /// count as a flick.
  static const flickSpeed = 700.0;

  /// Ids of cards that keep their place in the fan but aren't drawn yet,
  /// such as a card still flying in from a pile.
  final Set<int> hiddenIds;

  /// A key for each card's widget, so other parts of the table can find
  /// where a card sits.
  final GlobalKey Function(int cardId)? cardKey;

  /// The share of each card's height below the bottom of the row, left to
  /// run off the edge of the screen.
  final double hiddenBelow;

  /// Largest gap between neighbouring cards, as a share of a card's width,
  /// so small hands still overlap a little.
  static const _maxSpacing = 0.75;

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
  Widget build(BuildContext context) => _fan();

  Widget _fan() {
    final cardHeight = cardWidth / cardAspectRatio;
    final lift = cardHeight * _lift;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cards.length;
        if (n == 0) return SizedBox(height: cardHeight + lift);

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

        final usableWidth = constraints.maxWidth - gap * gapCount;
        final spacing = n == 1
            ? 0.0
            : min(cardWidth * _maxSpacing, (usableWidth - cardWidth) / (n - 1));
        final offsets = <double>[];
        for (var i = 0; i < n; i++) {
          offsets.add(
            i == 0 ? 0 : offsets[i - 1] + spacing + (gapBefore[i] ? gap : 0),
          );
        }
        final fanWidth = offsets.last + cardWidth;
        final left = (constraints.maxWidth - fanWidth) / 2;
        // Room above the cards for a selected card to lift into.
        final top = lift;

        // Where a card dropped on the fan should go: the slot whose centre is
        // nearest the drop.
        int slotAt(Offset globalDropTopLeft) {
          final box = context.findRenderObject()! as RenderBox;
          final dropCentre =
              box.globalToLocal(globalDropTopLeft).dx + cardWidth / 2;
          var nearest = 0;
          for (var i = 1; i < n; i++) {
            final here = (left + offsets[i] + cardWidth / 2 - dropCentre).abs();
            final best = (left + offsets[nearest] + cardWidth / 2 - dropCentre)
                .abs();
            if (here < best) nearest = i;
          }
          return nearest;
        }

        final fan = SizedBox(
          height: top + cardHeight * (1 - hiddenBelow),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  key: ValueKey(cards[i].id),
                  left: left + offsets[i],
                  top: top - (selected.contains(cards[i].id) ? lift : 0),
                  child: _HandCardView(
                    key: cardKey?.call(cards[i].id),
                    hidden: hiddenIds.contains(cards[i].id),
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
                    onReleased: (at, {required flicked}) {
                      final id = cards[i].id;
                      flicked
                          ? onFlick?.call(id, at)
                          : onDropMissed?.call(id, at);
                    },
                  ),
                ),
            ],
          ),
        );

        // A pile dropped on the fan draws from it; a hand card dropped on
        // the fan moves to where it was dropped.
        return DragTarget<DrawSource>(
          onAcceptWithDetails: (details) => onDraw?.call(details.data),
          builder: (context, candidates, rejected) => DragTarget<HandCard>(
            onAcceptWithDetails: (details) =>
                onReorder?.call(details.data.id, slotAt(details.offset)),
            builder: (context, candidates, rejected) => fan,
          ),
        );
      },
    );
  }
}

/// A hand card being dragged straight up to be discarded, as opposed to a
/// [HandCard] picked up with a long press to be moved. The discard pile
/// takes both; the hand only takes a [HandCard], so a card dragged up and
/// let go over the hand isn't mistaken for a move.
class QuickDiscard {
  const QuickDiscard(this.card);

  final HandCard card;
}

/// One card in the hand: tap to select; drag up or flick to discard;
/// long-press and drag to move it within the hand or onto the discard pile.
class _HandCardView extends StatelessWidget {
  const _HandCardView({
    super.key,
    required this.handCard,
    required this.width,
    required this.selected,
    required this.wild,
    required this.groupColor,
    required this.onTap,
    required this.onReleased,
    this.hidden = false,
  });

  final HandCard handCard;
  final double width;
  final bool selected;
  final bool wild;
  final Color? groupColor;
  final VoidCallback? onTap;

  /// Called when a drag ends without anything taking the card, with the
  /// card's centre where it was let go and whether it was flicked upwards.
  final void Function(Offset at, {required bool flicked}) onReleased;

  /// Keeps the card's space but draws nothing there.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return SizedBox(width: width, height: width / cardAspectRatio);
    }
    final face = CardFace(
      handCard.card,
      width: width,
      highlighted: selected,
      wild: wild,
      groupColor: groupColor,
    );
    final lifted = Material(
      color: Colors.transparent,
      child: CardFace(handCard.card, width: width, highlighted: true),
    );
    final dimmed = Opacity(opacity: 0.3, child: face);
    final centre = Offset(width / 2, width / cardAspectRatio / 2);

    void ended(DraggableDetails details, {required bool canFlick}) {
      if (details.wasAccepted) return;
      final upward = -details.velocity.pixelsPerSecond.dy;
      onReleased(
        details.offset + centre,
        flicked: canFlick && upward >= HandFan.flickSpeed,
      );
    }

    // A drag that starts straight up discards; holding still first (the
    // long press) picks the card up to move it instead. Sideways drags
    // without the long press do nothing, so moving a finger along the hand
    // never throws a card away.
    return Draggable<QuickDiscard>(
      data: QuickDiscard(handCard),
      affinity: Axis.vertical,
      feedback: lifted,
      childWhenDragging: dimmed,
      onDragEnd: (details) => ended(details, canFlick: true),
      child: LongPressDraggable<HandCard>(
        data: handCard,
        delay: const Duration(milliseconds: 250),
        feedback: lifted,
        childWhenDragging: dimmed,
        onDragEnd: (details) => ended(details, canFlick: false),
        child: GestureDetector(onTap: onTap, child: face),
      ),
    );
  }
}
