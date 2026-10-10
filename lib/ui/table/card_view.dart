import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../theme/table_theme.dart';
import 'suit_icon.dart';

/// Width ÷ height of a standard playing card (2.5" × 3.5").
const cardAspectRatio = 2.5 / 3.5;

/// A face-up card: rank and suit in the corner, a large suit in the middle.
/// Placeholder art until the Phase 3 card faces.
class CardFace extends StatelessWidget {
  const CardFace(
    this.card, {
    super.key,
    required this.width,
    this.highlighted = false,
    this.wild = false,
    this.groupColor,
  });

  final PlayingCard card;
  final double width;

  /// Draws a bright border, for a selected card.
  final bool highlighted;

  /// Marks the card as a joker with a softly pulsing gold glow.
  final bool wild;

  /// Colour of the strip along the top of a card in a grouped set.
  final Color? groupColor;

  bool get _isRed => card.suit == Suit.hearts || card.suit == Suit.diamonds;

  @override
  Widget build(BuildContext context) {
    final color = _isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    final face = _CardShape(
      width: width,
      color: Colors.white,
      highlighted: highlighted,
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
                SizedBox(height: width * 0.03),
                SuitIcon(card.suit, size: width * 0.2, color: color),
              ],
            ),
          ),
          if (groupColor != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: width * 0.07,
              child: ColoredBox(color: groupColor!),
            ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: width * 0.25),
              child: SuitIcon(card.suit, size: width * 0.42, color: color),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: wild ? '$card, joker' : card.toString(),
      excludeSemantics: true,
      child: wild ? JokerGlow(width: width, child: face) : face,
    );
  }
}

/// A slow, soft gold glow pulsing around a joker's edge: easy to spot on red
/// and black cards alike, without drawing the eye away from play. Holds
/// steady when the device asks for reduced motion.
class JokerGlow extends StatefulWidget {
  const JokerGlow({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  static const gold = Color(0xFFFFC400);

  @override
  State<JokerGlow> createState() => _JokerGlowState();
}

class _JokerGlowState extends State<JokerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pulse
        ..stop()
        ..value = 0.6;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          key: const Key('joker-glow'),
          position: DecorationPosition.background,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.1),
            boxShadow: [
              BoxShadow(
                color: JokerGlow.gold.withValues(alpha: 0.35 + 0.45 * t),
                blurRadius: width * (0.12 + 0.14 * t),
                spreadRadius: width * (0.01 + 0.03 * t),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A face-down card.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return _CardShape(
      width: width,
      color: theme.cardBackEdge,
      child: Padding(
        padding: EdgeInsets.all(width * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x99FFFFFF)),
            borderRadius: BorderRadius.circular(width * 0.06),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.cardBack,
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
    this.highlighted = false,
  });

  final double width;
  final Color color;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / cardAspectRatio,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: highlighted
            ? Border.all(color: const Color(0xFFFFC107), width: 2.5)
            : Border.all(color: const Color(0x33000000)),
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
