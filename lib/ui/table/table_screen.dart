import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/round.dart';
import '../state/table_controller.dart';
import '../state/table_state.dart';
import 'hand_fan.dart';
import 'opening_picker.dart';
import 'opponent_seat.dart';
import 'table_center.dart';

/// The main game screen, in landscape: opponents around the top and sides,
/// the stock and discard pile in the middle, and the human player's hand
/// fanned along the bottom, with a Sort button and a line saying what to do
/// next. Moves the engine refuses pop up as a message with its reason.
class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tableProvider);
    final table = state.view;
    final controller = ref.read(tableProvider.notifier);

    ref.listen(tableProvider.select((s) => s.noticeId), (previous, next) {
      final notice = ref.read(tableProvider).notice;
      if (notice == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(notice),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });

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
              final choice = state.openingChoice;
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
                      alignment: Alignment.topLeft,
                      child: FilledButton.tonalIcon(
                        key: const Key('sort-button'),
                        onPressed: controller.sortHand,
                        icon: const Icon(Icons.sort),
                        label: const Text('Sort'),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TableCenter(
                            stockCount: table.stockCount,
                            topDiscard: table.topDiscard,
                            cardWidth: cardWidth,
                            onStockTap: () => controller.draw(DrawSource.stock),
                            onDiscardPileTap: controller.tapDiscardPile,
                            onCardDropped: controller.discard,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLine(state),
                            key: const Key('status-line'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: HandFan(
                        cards: state.hand,
                        selected: state.selected,
                        cardWidth: cardWidth,
                        onCardTap: controller.toggleSelected,
                        onDraw: controller.draw,
                      ),
                    ),
                    if (choice != null)
                      Positioned.fill(
                        child: ColoredBox(
                          color: const Color(0x99000000),
                          child: Center(
                            child: OpeningPicker(
                              tunnellas: choice,
                              onConfirm: controller.chooseOpeningTunnellas,
                            ),
                          ),
                        ),
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

/// What the human player should do next, in a few words.
String statusLine(TableState state) {
  final table = state.view;
  final winner = table.winner;
  if (winner != null) return '${winner.name} won the round.';
  if (state.openingChoice != null) return 'Choose your opening tunnellas.';
  if (!table.isYourTurn) return 'Waiting for the other players…';
  if (!table.youHaveDrawn) {
    return 'Your turn: tap the stock or the discard pile.';
  }
  return 'Select a card, then tap the discard pile.';
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
