import 'package:flutter/material.dart';

import '../../engine/card.dart';
import 'card_view.dart';
import 'suit_icon.dart';

/// A shown set as a compact chip, such as "♠A23" or "♣KKK". Tap it to see the
/// set as full-size cards.
class SetChip extends StatelessWidget {
  const SetChip(this.cards, {super.key});

  final List<PlayingCard> cards;

  /// "♠A23" when every card shares a suit; otherwise each card in full.
  static String label(List<PlayingCard> cards) {
    if (cards.first.suit case final suit?
        when cards.every((card) => card.suit == suit)) {
      return '${suit.symbol}${cards.map((card) => card.rank!.label).join()}';
    }
    return cards.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => _EnlargedSet(cards),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xEEFFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SuitText(
          label(cards),
          redColor: redSuitColor,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Several shown sets as chips, laid out along [direction].
class SetChips extends StatelessWidget {
  const SetChips(this.sets, {super.key, this.direction = Axis.vertical});

  final List<List<PlayingCard>> sets;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      direction: direction,
      spacing: 3,
      runSpacing: 3,
      children: [for (final set in sets) SetChip(set)],
    );
  }
}

/// A shown set at full size, for reading it properly.
class _EnlargedSet extends StatelessWidget {
  const _EnlargedSet(this.cards);

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('enlarged-set'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CardFace(card, width: 64),
              ),
          ],
        ),
      ),
    );
  }
}
