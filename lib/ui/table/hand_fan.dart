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
/// the hand (or onto the pile): while it's held over the hand, the other
/// cards slide aside to show where it will go, and a card in a grouped set
/// brings its whole set. Any card let go over the hand moves to that spot,
/// however it was picked up. A card dragged in from the stock or the
/// discard pile ([placingId]) opens a gap the same way, and drops into it.
class HandFan extends StatefulWidget {
  const HandFan({
    super.key,
    required this.cards,
    required this.cardWidth,
    this.selected = const {},
    this.groupOf,
    this.jokers,
    this.onCardTap,
    this.placingId,
    this.onPlaceDrawn,
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

  /// The id of the card just drawn from a pile that is still being dragged
  /// in, if any. It keeps a gap open where it would land, and is drawn by
  /// whatever is dragging it.
  final int? placingId;

  /// Called when the card being dragged in from a pile is let go over the
  /// fan, with the position it was dropped at.
  final void Function(int newIndex)? onPlaceDrawn;

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
  State<HandFan> createState() => _HandFanState();
}

class _HandFanState extends State<HandFan> {
  /// The card being dragged, if any.
  int? _dragging;

  /// The slot the dragged card is held over in the hand, if it is.
  int? _hoverSlot;

  /// How long the other cards take to slide aside for a held card.
  static const _slide = Duration(milliseconds: 120);

  /// The cards that move with [cardId]: its grouped set, or just the card.
  Set<int> _movingWith(int cardId) {
    final group = widget.groupOf?.call(cardId);
    if (group == null) return {cardId};
    return {
      for (final c in widget.cards)
        if (widget.groupOf!(c.id) == group) c.id,
    };
  }

  void _dragStarted(int cardId) => setState(() => _dragging = cardId);

  @override
  void didUpdateWidget(HandFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A card that left the hand mid-drag (discarded onto the pile) is no
    // longer being held over it.
    if (_dragging case final id? when !widget.cards.any((c) => c.id == id)) {
      _dragging = null;
      _hoverSlot = null;
    }
  }

  void _dragEnded() => setState(() {
    _dragging = null;
    _hoverSlot = null;
  });

  /// The id of the hand card a drag carries, if it carries one.
  static int? _cardIdIn(Object? data) => switch (data) {
    HandCard(:final id) => id,
    QuickDiscard(card: HandCard(:final id)) => id,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.cardWidth;
    final cardHeight = cardWidth / cardAspectRatio;
    final lift = cardHeight * HandFan._lift;
    final selected = widget.selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.cards.length;
        if (n == 0) return SizedBox(height: cardHeight + lift);

        final gap = cardWidth * HandFan._groupGap;
        int? groupOfCard(HandCard c) => widget.groupOf?.call(c.id);

        // Each card's distance from the fan's left edge, for [cards] in
        // that order. A gap goes wherever one card and the next aren't in
        // the same group, as long as at least one of them is grouped.
        List<double> offsetsFor(List<HandCard> cards) {
          final gapBefore = [
            for (var i = 0; i < n; i++)
              i > 0 &&
                  groupOfCard(cards[i]) != groupOfCard(cards[i - 1]) &&
                  (groupOfCard(cards[i]) != null ||
                      groupOfCard(cards[i - 1]) != null),
          ];
          final gapCount = gapBefore.where((g) => g).length;
          final usableWidth = constraints.maxWidth - gap * gapCount;
          final spacing = n == 1
              ? 0.0
              : min(
                  cardWidth * HandFan._maxSpacing,
                  (usableWidth - cardWidth) / (n - 1),
                );
          final offsets = <double>[];
          for (var i = 0; i < n; i++) {
            offsets.add(
              i == 0 ? 0 : offsets[i - 1] + spacing + (gapBefore[i] ? gap : 0),
            );
          }
          return offsets;
        }

        double leftFor(List<double> offsets) =>
            (constraints.maxWidth - (offsets.last + cardWidth)) / 2;

        // Slots are measured on the hand as it stands, so they don't shift
        // under the finger while the other cards slide aside.
        final standing = offsetsFor(widget.cards);
        final standingLeft = leftFor(standing);

        // Where a card held at [globalTopLeft] would go: the slot whose
        // centre is nearest the card's centre.
        int slotAt(Offset globalTopLeft) {
          final box = context.findRenderObject()! as RenderBox;
          final centre = box.globalToLocal(globalTopLeft).dx + cardWidth / 2;
          double distance(int i) =>
              (standingLeft + standing[i] + cardWidth / 2 - centre).abs();
          var nearest = 0;
          for (var i = 1; i < n; i++) {
            if (distance(i) < distance(nearest)) nearest = i;
          }
          return nearest;
        }

        // While a card is held over the hand, the hand is shown as it would
        // be with the card (and its set) dropped there.
        final dragging = _dragging;
        final hoverSlot = _hoverSlot;
        final cards = dragging != null && hoverSlot != null
            ? withCardsMoved(widget.cards, _movingWith(dragging), hoverSlot)
            : widget.cards;
        final offsets = offsetsFor(cards);
        final left = leftFor(offsets);
        // Room above the cards for a selected card to lift into.
        final top = lift;
        final slide =
            dragging == null || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _slide;

        final fan = SizedBox(
          height: top + cardHeight * (1 - widget.hiddenBelow),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  key: ValueKey(cards[i].id),
                  duration: slide,
                  curve: Curves.easeOut,
                  left: left + offsets[i],
                  top: top - (selected.contains(cards[i].id) ? lift : 0),
                  child: _HandCardView(
                    key: widget.cardKey?.call(cards[i].id),
                    hidden: widget.hiddenIds.contains(cards[i].id),
                    handCard: cards[i],
                    width: cardWidth,
                    selected: selected.contains(cards[i].id),
                    wild:
                        cards[i].card.isSuperman ||
                        (widget.jokers?.isWild(cards[i].card) ?? false),
                    groupColor: switch (groupOfCard(cards[i])) {
                      null => null,
                      final g =>
                        HandFan.groupColors[g % HandFan.groupColors.length],
                    },
                    onTap: widget.onCardTap == null
                        ? null
                        : () => widget.onCardTap!(cards[i].id),
                    onDragStarted: () => _dragStarted(cards[i].id),
                    onDragEnded: _dragEnded,
                    onReleased: (at, {required flicked}) {
                      final id = cards[i].id;
                      flicked
                          ? widget.onFlick?.call(id, at)
                          : widget.onDropMissed?.call(id, at);
                    },
                  ),
                ),
            ],
          ),
        );

        // A card dragged in from a pile, like a hand card moved within the
        // hand, shows where it would land while it's held over the fan.
        void hoverDrawn(Offset globalTopLeft) {
          final id = widget.placingId;
          if (id == null) return;
          final slot = slotAt(globalTopLeft);
          if (id != _dragging || slot != _hoverSlot) {
            setState(() {
              _dragging = id;
              _hoverSlot = slot;
            });
          }
        }

        // A card dragged in from a pile drops where it was let go. A hand
        // card let go over the fan moves there too, whether it was picked
        // up with a long press or started off upwards.
        return DragTarget<PileDraw>(
          onMove: (details) => hoverDrawn(details.offset),
          onLeave: (_) => _dragEnded(),
          onAcceptWithDetails: (details) {
            if (widget.placingId != null) {
              widget.onPlaceDrawn?.call(slotAt(details.offset));
            }
            _dragEnded();
          },
          builder: (context, candidates, rejected) => DragTarget<Object>(
            onWillAcceptWithDetails: (details) =>
                _cardIdIn(details.data) != null,
            onMove: (details) {
              if (_cardIdIn(details.data) == null) return;
              final slot = slotAt(details.offset);
              if (slot != _hoverSlot) setState(() => _hoverSlot = slot);
            },
            onLeave: (_) => setState(() => _hoverSlot = null),
            onAcceptWithDetails: (details) {
              final id = _cardIdIn(details.data)!;
              widget.onReorder?.call(id, slotAt(details.offset));
            },
            builder: (context, candidates, rejected) => fan,
          ),
        );
      },
    );
  }
}

/// A card being dragged from the [source] pile, drawn as the drag began.
class PileDraw {
  const PileDraw(this.source);

  final DrawSource source;
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
    required this.onDragStarted,
    required this.onDragEnded,
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

  /// Called when the card is picked up, and when it's let go, whatever
  /// happens to it.
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

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
      onDragEnded();
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
      onDragStarted: onDragStarted,
      onDragEnd: (details) => ended(details, canFlick: true),
      child: LongPressDraggable<HandCard>(
        data: handCard,
        delay: const Duration(milliseconds: 250),
        feedback: lifted,
        childWhenDragging: dimmed,
        onDragStarted: onDragStarted,
        onDragEnd: (details) => ended(details, canFlick: false),
        // A quick sideways swipe is claimed here and does nothing, so it
        // never turns into a drag; moving a card takes the long press.
        child: GestureDetector(
          onTap: onTap,
          onHorizontalDragStart: (_) {},
          child: face,
        ),
      ),
    );
  }
}
