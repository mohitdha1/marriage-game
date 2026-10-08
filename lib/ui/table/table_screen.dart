import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/table_controller.dart';
import 'hand_fan.dart';
import 'opponent_seat.dart';
import 'table_center.dart';

/// The main game screen, in landscape: opponents around the top and sides,
/// the stock and discard pile in the middle, and the human player's hand
/// fanned along the bottom.
class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(tableProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 1.2,
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0D3B12)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxHeight * 0.17).clamp(
                40.0,
                100.0,
              );
              final seats = seatAlignments(table.opponents.length);
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    for (var i = 0; i < table.opponents.length; i++)
                      Align(
                        alignment: seats[i],
                        child: OpponentSeat(seat: table.opponents[i]),
                      ),
                    Align(
                      alignment: const Alignment(0, -0.3),
                      child: TableCenter(
                        stockCount: table.stockCount,
                        topDiscard: table.topDiscard,
                        cardWidth: cardWidth,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: HandFan(cards: table.hand, cardWidth: cardWidth),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where each opponent sits, clockwise from the human player's left, for 1
/// to 4 opponents.
List<Alignment> seatAlignments(int opponentCount) => switch (opponentCount) {
  1 => const [Alignment.topCenter],
  2 => const [Alignment(-0.5, -1), Alignment(0.5, -1)],
  3 => const [Alignment(-1, -0.4), Alignment.topCenter, Alignment(1, -0.4)],
  _ => const [
    Alignment(-1, -0.4),
    Alignment(-0.4, -1),
    Alignment(0.4, -1),
    Alignment(1, -0.4),
  ],
};
