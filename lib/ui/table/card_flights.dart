import 'package:flutter/material.dart';

import '../../engine/card.dart';
import 'card_view.dart';

/// How long a card takes to glide from one place to another.
const cardFlightTime = Duration(milliseconds: 300);

/// Where things are on the table, so cards can be animated between them.
/// Each key goes on the widget it names.
class TableAnchors {
  final stock = GlobalKey(debugLabel: 'stock');
  final discardPile = GlobalKey(debugLabel: 'discard pile');
  final hand = GlobalKey(debugLabel: 'hand');
  final _seats = <int, GlobalKey>{};

  /// The key for the opponent at [seat].
  GlobalKey seat(int seat) =>
      _seats.putIfAbsent(seat, () => GlobalKey(debugLabel: 'seat $seat'));
}

/// A layer over the table that draws cards gliding between places: drawn
/// from a pile into a hand or seat, or discarded onto the pile.
///
/// Purely decorative: the game state has already changed by the time a card
/// flies, and nothing here can be tapped.
class CardFlightLayer extends StatefulWidget {
  const CardFlightLayer({super.key, required this.cardWidth});

  final double cardWidth;

  @override
  State<CardFlightLayer> createState() => CardFlightLayerState();
}

class CardFlightLayerState extends State<CardFlightLayer>
    with TickerProviderStateMixin {
  final _flights = <_Flight>[];

  /// Flies a card from the widget at [from] to the widget at [to], starting
  /// after [delay]. Shows [face] face up, or a card back when it's `null`.
  /// [from] can be replaced by [fromPoint] and [to] by [toRect]: spots on
  /// the table in global coordinates. Calls [onLanded] when the card arrives
  /// (straight away if either place can't be found).
  void fly({
    GlobalKey? from,
    Offset? fromPoint,
    GlobalKey? to,
    Rect? toRect,
    PlayingCard? face,
    Duration delay = Duration.zero,
    VoidCallback? onLanded,
  }) {
    final start = fromPoint ?? (from == null ? null : _centreOf(from));
    final end = toRect?.center ?? (to == null ? null : _centreOf(to));
    final box = context.findRenderObject() as RenderBox?;
    if (start == null || end == null || box == null || !box.hasSize) {
      onLanded?.call();
      return;
    }

    final total = delay + cardFlightTime;
    final controller = AnimationController(vsync: this, duration: total);
    final flight = _Flight(
      from: box.globalToLocal(start),
      to: box.globalToLocal(end),
      face: face,
      progress: CurvedAnimation(
        parent: controller,
        curve: Interval(
          delay.inMicroseconds / total.inMicroseconds,
          1,
          curve: Curves.easeInOut,
        ),
      ),
      startsAt: delay.inMicroseconds / total.inMicroseconds,
      controller: controller,
    );
    setState(() => _flights.add(flight));
    controller.forward().whenComplete(() {
      onLanded?.call();
      if (!mounted) return;
      setState(() => _flights.remove(flight));
      controller.dispose();
    });
  }

  Offset? _centreOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  void dispose() {
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.cardWidth;
    final height = width / cardAspectRatio;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final flight in _flights)
            AnimatedBuilder(
              key: ObjectKey(flight),
              animation: flight.controller,
              builder: (context, child) {
                // Hidden until its delay is over.
                if (flight.controller.value < flight.startsAt) {
                  return const SizedBox.shrink();
                }
                final at = Offset.lerp(
                  flight.from,
                  flight.to,
                  flight.progress.value,
                )!;
                return Positioned(
                  left: at.dx - width / 2,
                  top: at.dy - height / 2,
                  child: child!,
                );
              },
              child: flight.face == null
                  ? CardBack(width: width, key: const Key('flying-card'))
                  : CardFace(
                      flight.face!,
                      width: width,
                      key: const Key('flying-card'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Flight {
  _Flight({
    required this.from,
    required this.to,
    required this.face,
    required this.progress,
    required this.startsAt,
    required this.controller,
  });

  final Offset from;
  final Offset to;
  final PlayingCard? face;
  final Animation<double> progress;

  /// The share of [controller]'s run spent waiting before take-off.
  final double startsAt;
  final AnimationController controller;
}
