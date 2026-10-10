import 'package:flutter/material.dart';

import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/table_event.dart';
import 'set_chips.dart';
import 'suit_icon.dart';

/// One line of the move history, as everyone at the table saw it. Cards
/// drawn from the stock stay hidden; cards taken from the discard pile
/// don't.
String describeEvent(TableEvent event, String Function(int seat) nameOf) {
  final who = nameOf(event.seat);
  return switch (event) {
    OpenedTunnellas(:final tunnellas) =>
      '$who opened with ${tunnellas.map(SetChip.label).join(' ')}',
    DrewCard(source: DrawSource.stock) => '$who drew from the stock',
    DrewCard(:final card) => '$who took $card from the discard pile',
    ShowedSets(:final kind, :final sets) =>
      '$who showed ${sets.map(SetChip.label).join(' ')}'
          '${kind == ShowKind.doublees ? ' (doublees)' : ''}'
          ' and saw the joker',
    DiscardedCard(:final card) => '$who discarded $card',
    WonRound(:final card) => '$who discarded $card and won the round',
    StockReshuffled() => 'The stock ran out and the discards were shuffled',
  };
}

/// This round's moves, newest first, in a sheet that slides up from the
/// bottom of the table.
class MoveLog extends StatelessWidget {
  const MoveLog({super.key, required this.events, required this.nameOf});

  final List<TableEvent> events;
  final String Function(int seat) nameOf;

  @override
  Widget build(BuildContext context) {
    final newestFirst = events.reversed.toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'This round',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (newestFirst.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No moves yet.'),
            )
          else
            Flexible(
              child: ListView.builder(
                key: const Key('move-log'),
                shrinkWrap: true,
                itemCount: newestFirst.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  child: SuitText(
                    describeEvent(newestFirst[i], nameOf),
                    redColor: redSuitColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
