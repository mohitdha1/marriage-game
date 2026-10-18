import 'dart:math';

import 'package:flutter/material.dart';

/// A banner over the table naming the round's winner, shown in the moment
/// before the scoreboard opens. When the human player won, confetti falls
/// too.
///
/// With reduced motion the banner simply appears and no confetti falls.
class WinCelebration extends StatefulWidget {
  const WinCelebration({
    super.key,
    required this.winnerName,
    required this.youWon,
    this.title,
    this.alignment = Alignment.center,
  });

  final String winnerName;
  final bool youWon;

  /// The banner's words, in place of naming the round's winner.
  final String? title;

  /// Where the banner sits in the space the celebration covers.
  final AlignmentGeometry alignment;

  /// How long the banner takes to pop in.
  static const popTime = Duration(milliseconds: 400);

  /// How long the confetti takes to fall.
  static const confettiTime = Duration(milliseconds: 1500);

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: WinCelebration.popTime,
  );
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: WinCelebration.confettiTime,
  );

  /// Every piece of confetti, scattered the same way each time.
  final _confetti = _Confetti.scatter(Random(7), 70);

  var _started = false;
  var _stillScreen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _stillScreen = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_stillScreen) {
      _pop.value = 1;
    } else {
      _pop.forward();
      if (widget.youWon) _fall.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      key: const Key('win-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.youWon
              ? const [Color(0xFFFFD54F), Color(0xFFFF8F00)]
              : const [Color(0xFF546E7A), Color(0xFF37474F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        widget.title ??
            (widget.youWon ? 'You won!' : '${widget.winnerName} won the round'),
        style: TextStyle(
          color: widget.youWon ? const Color(0xFF3E2723) : Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return IgnorePointer(
      child: Stack(
        children: [
          if (widget.youWon && !_stillScreen)
            Positioned.fill(
              child: CustomPaint(
                key: const Key('confetti'),
                painter: _ConfettiPainter(_confetti, _fall),
              ),
            ),
          Align(
            alignment: widget.alignment,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
              child: FadeTransition(opacity: _pop, child: banner),
            ),
          ),
        ],
      ),
    );
  }
}

/// One piece of confetti: where it starts across the top (0–1), how far it
/// drifts sideways, how fast it falls and spins, and its colour.
class _Confetti {
  const _Confetti({
    required this.x,
    required this.drift,
    required this.speed,
    required this.spin,
    required this.color,
  });

  static const _colors = [
    Color(0xFFE53935),
    Color(0xFFFFB300),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFFFFFFF),
  ];

  static List<_Confetti> scatter(Random random, int count) => [
    for (var i = 0; i < count; i++)
      _Confetti(
        x: random.nextDouble(),
        drift: (random.nextDouble() - 0.5) * 0.2,
        speed: 0.8 + random.nextDouble() * 0.6,
        spin: (random.nextDouble() - 0.5) * 20,
        color: _colors[i % _colors.length],
      ),
  ];

  final double x;
  final double drift;
  final double speed;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress) : super(repaint: progress);

  final List<_Confetti> pieces;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    final paint = Paint();
    for (final piece in pieces) {
      // Starts just above the top edge and falls past the bottom.
      final y = (t * piece.speed * 1.2 - 0.1) * size.height;
      final x = (piece.x + piece.drift * t) * size.width;
      paint.color = piece.color.withValues(alpha: 1 - t * 0.5);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(piece.spin * t)
        ..drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.pieces != pieces || old.progress != progress;
}
