import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../theme/table_theme.dart';
import 'card_back_art.dart';
import 'card_face_art.dart';
import 'suit_icon.dart';

/// Width ÷ height of a standard playing card (2.5" × 3.5").
const cardAspectRatio = 2.5 / 3.5;

/// Ink colour of a man card, unlike either suit colour.
const manCardColor = Color(0xFF6A1B9A);

/// A face-up card, laid out like a printed one: rank and suit in the top
/// left corner and, upside down, the bottom right; the pips of a number
/// card in their usual pattern; one large pip on an ace; and the court
/// figure on a jack, queen or king. A man card shows "M" in its corners and
/// a figure in the middle.
///
/// The corner rank is large, because in an overlapping hand the top left
/// corner is often all that shows of a card.
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
    final color = card.isMan
        ? manCardColor
        : _isRed
        ? redSuitColor
        : const Color(0xFF1A1A1A);
    final height = width / cardAspectRatio;
    final index = _CornerIndex(card: card, width: width, color: color);
    final face = _CardShape(
      width: width,
      highlighted: highlighted,
      child: Stack(
        children: [
          _centre(width, height, color),
          Positioned(left: width * 0.05, top: width * 0.05, child: index),
          Positioned(
            right: width * 0.05,
            bottom: width * 0.05,
            child: Transform.rotate(angle: pi, child: index),
          ),
          if (groupColor != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: width * 0.07,
              child: ColoredBox(color: groupColor!),
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

  /// The middle of the card, between the corner indexes.
  Widget _centre(double width, double height, Color color) {
    final (suit, rank) = (card.suit, card.rank);
    if (suit == null || rank == null) {
      return Center(
        child: Icon(
          Icons.person,
          key: const Key('man-art'),
          size: width * 0.55,
          color: color,
        ),
      );
    }
    if (rank == Rank.ace) {
      return Center(
        child: SuitIcon(suit, size: width * 0.5, color: color),
      );
    }
    if (isCourt(rank)) {
      return Center(
        child: SizedBox(
          key: const Key('court-art'),
          // Narrow enough to leave the corner indexes clear.
          width: width * 0.5,
          child: Image.asset(
            courtArtAsset(card),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }
    return Positioned.fromRect(
      rect: Rect.fromLTRB(
        width * 0.36,
        height * 0.2,
        width * 0.64,
        height * 0.8,
      ),
      child: CustomPaint(
        key: const Key('pips'),
        painter: PipPainter(
          suit: suit,
          pips: pipLayout(rank),
          pipSize: width * 0.14,
          color: color,
        ),
      ),
    );
  }
}

/// A card's rank above its suit, kept within the narrow strip beside the
/// pips: a wide rank such as 10 shrinks to fit.
class _CornerIndex extends StatelessWidget {
  const _CornerIndex({
    required this.card,
    required this.width,
    required this.color,
  });

  final PlayingCard card;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * 0.2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.rank?.label ?? 'M',
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: width * 0.28,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -width * 0.02,
              ),
            ),
          ),
          if (card.suit case final suit?) ...[
            SizedBox(height: width * 0.02),
            SuitIcon(suit, size: width * 0.17, color: color),
          ],
        ],
      ),
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

/// A face-down card: a white margin round a printed field in the current
/// [TableTheme]'s colours (see [CardBackPainter]).
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return _CardShape(
      width: width,
      child: Padding(
        padding: EdgeInsets.all(width * 0.07),
        // Its own layer, so the detailed pattern is painted once and reused
        // while the card moves, rather than repainted every frame.
        child: RepaintBoundary(
          child: CustomPaint(
            key: const Key('card-back-pattern'),
            size: Size.infinite,
            painter: CardBackPainter(
              field: theme.cardBack,
              ink: theme.cardBackEdge,
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

/// The rounded, shadowed piece of card stock every card is drawn on, with a
/// faint sheen.
class _CardShape extends StatelessWidget {
  const _CardShape({
    required this.width,
    required this.child,
    this.highlighted = false,
  });

  final double width;
  final Widget child;
  final bool highlighted;

  /// Card stock: bright white where the light catches it, a touch warmer
  /// towards the far corner.
  static const _paper = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFAF8F3), Color(0xFFF1EDE4)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / cardAspectRatio,
      decoration: BoxDecoration(
        gradient: _paper,
        borderRadius: BorderRadius.circular(width * 0.08),
        border: highlighted
            ? Border.all(color: const Color(0xFFFFC107), width: 2.5)
            : Border.all(color: const Color(0x38000000), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 1,
            offset: Offset(0, 0.5),
          ),
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 5,
            offset: Offset(1, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
