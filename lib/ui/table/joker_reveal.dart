import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/joker.dart';
import 'card_view.dart';
import 'suit_icon.dart';

/// The moment the human player sees the joker: the tiplu flips face up, with
/// a banner naming the cards that are now wild.
class JokerReveal extends StatefulWidget {
  const JokerReveal({super.key, required this.jokers, required this.onDone});

  final Jokers jokers;
  final VoidCallback onDone;

  @override
  State<JokerReveal> createState() => _JokerRevealState();
}

class _JokerRevealState extends State<JokerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jokers = widget.jokers;
    const cardWidth = 90.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _flip,
              builder: (context, _) {
                // Turn the card about its vertical axis. Past halfway the
                // face is showing, so it's turned a further half-turn to
                // avoid drawing it mirrored.
                final angle = Curves.easeInOut.transform(_flip.value) * pi;
                final faceUp = angle > pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(faceUp ? angle - pi : angle),
                  child: faceUp
                      ? CardFace(jokers.tiplu, width: cardWidth, wild: true)
                      : const CardBack(width: cardWidth),
                );
              },
            ),
            const SizedBox(height: 12),
            SuitText(
              'The joker is ${jokers.tiplu}',
              key: const Key('reveal-title'),
              redColor: redSuitColor,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            SuitText(
              'Jhiplu ${jokers.jhiplu} · Poplu ${jokers.poplu} · '
              'Alter ${jokers.alter} · every ${jokers.tiplu.rank.label} is '
              'wild',
              redColor: redSuitColor,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: widget.onDone, child: const Text('Got it')),
          ],
        ),
      ),
    );
  }
}
