import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/card.dart';
import '../../engine/round.dart';
import '../state/table_controller.dart';
import '../state/table_state.dart';
import '../state/table_view.dart';
import 'card_view.dart';
import 'hand_fan.dart';
import 'joker_reveal.dart';
import 'opening_picker.dart';
import 'opponent_seat.dart';
import 'table_center.dart';
import 'tiplu_picker.dart';

/// The main game screen, in landscape: opponents around the top and sides
/// (the one whose turn it is glows), the stock and discard pile in the
/// middle, and the human player's hand fanned along the bottom.
///
/// Under the piles, a status line says what to do next, and buttons appear
/// when they're useful: Group and Show to show sets and see the joker, Win to
/// finish the round. Moves the engine refuses pop up with its reason.
class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  /// Room kept clear on either side of the status line, for the seats and,
  /// lower down, the laid-down sets and action buttons.
  static const _sideClearance = 200.0;

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
              final jokers = table.yourJokers;
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    for (var i = 0; i < table.opponents.length; i++)
                      Align(
                        alignment: seats[i],
                        child: OpponentSeat(
                          seat: table.opponents[i],
                          isCurrentTurn:
                              table.winner == null &&
                              table.currentSeat == table.opponents[i].seat,
                          lastMove: state.botMoves[table.opponents[i].seat],
                        ),
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
                      alignment: Alignment.topRight,
                      child: _JokerChip(table: table),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.3),
                      child: Column(
                        key: const Key('table-centre'),
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
                          ConstrainedBox(
                            // Keep clear of the seats at the sides.
                            constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth - 2 * _sideClearance,
                            ),
                            child: Text(
                              statusLine(state),
                              key: const Key('status-line'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Just above the hand, clear of the space a selected card
                    // lifts into: laid-down sets on the left, buttons on the
                    // right.
                    if (table.you.laidDown.isNotEmpty)
                      Align(
                        alignment: const Alignment(-1, 0.05),
                        child: _LaidDownSets(sets: table.you.laidDown),
                      ),
                    Align(
                      alignment: const Alignment(1, 0.05),
                      child: _ActionBar(state: state, controller: controller),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: HandFan(
                        cards: state.hand,
                        selected: state.selected,
                        groupOf: state.groupOf,
                        jokers: jokers,
                        cardWidth: cardWidth,
                        onCardTap: controller.toggleSelected,
                        onDraw: controller.draw,
                      ),
                    ),
                    if (choice != null)
                      _Overlay(
                        child: OpeningPicker(
                          tunnellas: choice,
                          onConfirm: controller.chooseOpeningTunnellas,
                        ),
                      ),
                    if (state.pickingTiplu)
                      _Overlay(
                        child: TipluPicker(
                          stockCount: table.stockCount,
                          onPick: controller.pickTiplu,
                          onCancel: controller.cancelTipluPick,
                        ),
                      ),
                    if (state.revealingJoker && jokers != null)
                      _Overlay(
                        child: JokerReveal(
                          jokers: jokers,
                          onDone: controller.dismissReveal,
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
  if (!table.isYourTurn) {
    final thinking = table.opponents.where(
      (seat) => seat.seat == table.currentSeat,
    );
    return thinking.isEmpty
        ? 'Waiting for the other players…'
        : '${thinking.single.name} is thinking…';
  }
  if (!table.youHaveDrawn) return 'Your turn: draw a card.';
  if (table.youHaveSeenJoker) return 'Discard a card, or win.';
  return 'Select a card to discard.';
}

/// The buttons that make sense right now: grouping and showing sets before
/// the joker is seen, and winning after.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.controller});

  final TableState state;
  final TableController controller;

  @override
  Widget build(BuildContext context) {
    final table = state.view;
    final selected = state.singleSelected;
    final buttons = [
      if (!table.youHaveSeenJoker && state.selected.length >= 2)
        _button('group-button', 'Group', controller.groupSelected),
      if (state.groups.isNotEmpty)
        _button('clear-groups-button', 'Ungroup', controller.clearGroups),
      if (!table.youHaveSeenJoker &&
          table.isYourTurn &&
          state.groups.isNotEmpty)
        _button('show-button', 'Show', controller.showGroups),
      if (table.youHaveSeenJoker && table.isYourTurn && table.youHaveDrawn)
        _button(
          'win-button',
          'Win',
          selected != null && state.winningDiscards.contains(selected.id)
              ? controller.declareWin
              : null,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('action-bar'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final button in buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: button,
            ),
        ],
      ),
    );
  }

  Widget _button(String key, String label, VoidCallback? onPressed) =>
      FilledButton.tonal(
        key: Key(key),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(label),
      );
}

/// The joker, once the human player has seen it, in the top corner.
class _JokerChip extends StatelessWidget {
  const _JokerChip({required this.table});

  final TableView table;

  @override
  Widget build(BuildContext context) {
    final jokers = table.yourJokers;
    final String label;
    if (jokers != null) {
      label = 'Joker';
    } else if (table.isJokerChosen) {
      label = 'Joker hidden';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('joker-chip'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          if (jokers != null) ...[
            const SizedBox(width: 6),
            CardFace(jokers.tiplu, width: 24, wild: true),
          ],
        ],
      ),
    );
  }
}

/// The human player's laid-down sets, as small cards.
class _LaidDownSets extends StatelessWidget {
  const _LaidDownSets({required this.sets});

  final List<List<PlayingCard>> sets;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('your-laid-down-sets'),
      constraints: const BoxConstraints(maxWidth: 220),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final set in sets)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final card in set) CardFace(card, width: 18)],
            ),
        ],
      ),
    );
  }
}

/// Dims the table behind a dialog-like panel.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(child: child),
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
