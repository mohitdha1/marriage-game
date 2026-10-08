import 'package:flutter/material.dart';

import '../../engine/card.dart';

/// Width ÷ height of a standard playing card (2.5" × 3.5").
const cardAspectRatio = 2.5 / 3.5;

/// A face-up card: rank and suit in the corner, a large suit in the middle.
/// Placeholder art until the Phase 3 card faces.
class CardFace extends StatelessWidget {
  const CardFace(this.card, {super.key, required this.width});

  final PlayingCard card;
  final double width;

  bool get _isRed => card.suit == Suit.hearts || card.suit == Suit.diamonds;

  @override
  Widget build(BuildContext context) {
    final color = _isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    return Semantics(
      label: card.toString(),
      excludeSemantics: true,
      child: _CardShape(
        width: width,
        color: Colors.white,
        child: Stack(
          children: [
            Positioned(
              left: width * 0.08,
              top: width * 0.05,
              child: Column(
                children: [
                  Text(
                    card.rank.label,
                    style: TextStyle(
                      color: color,
                      fontSize: width * 0.28,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    card.suit.symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: width * 0.24,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: width * 0.25),
                child: Text(
                  card.suit.symbol,
                  style: TextStyle(color: color, fontSize: width * 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A face-down card.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return _CardShape(
      width: width,
      color: const Color(0xFF8E1B1B),
      child: Padding(
        padding: EdgeInsets.all(width * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x99FFFFFF)),
            borderRadius: BorderRadius.circular(width * 0.06),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB71C1C), Color(0xFF6D1010)],
            ),
          ),
        ),
      ),
    );
  }
}

/// An empty spot where a card could go, such as an empty discard pile.
class CardSlot extends StatelessWidget {
  const CardSlot({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / cardAspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
          borderRadius: BorderRadius.circular(width * 0.1),
        ),
      ),
    );
  }
}

/// The rounded, shadowed rectangle every card is drawn on.
class _CardShape extends StatelessWidget {
  const _CardShape({
    required this.width,
    required this.color,
    required this.child,
  });

  final double width;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / cardAspectRatio,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: const Color(0x33000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 3,
            offset: Offset(1, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
