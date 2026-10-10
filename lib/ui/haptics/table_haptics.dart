import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/table_event.dart';
import '../state/table_controller.dart';
import 'haptics.dart';

/// Vibrates as the game unfolds: a gentle tap when another player's move
/// makes it the human player's turn, and two firm taps when they win a
/// round. A round that starts on their turn doesn't tap.
class TableHaptics extends ConsumerWidget {
  const TableHaptics({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      tableProvider.select(
        (s) => (
          round: s.roundNumber,
          events: s.view.events,
          yourTurn: s.view.isYourTurn,
          you: s.view.you.seat,
        ),
      ),
      (previous, next) {
        if (previous == null || previous.round != next.round) return;
        final haptics = ref.read(hapticsProvider);
        final youWon = next.events
            .skip(previous.events.length)
            .any((e) => e is WonRound && e.seat == next.you);
        if (youWon) {
          haptics.buzz(Buzz.win);
        } else if (next.yourTurn && !previous.yourTurn) {
          haptics.buzz(Buzz.yourTurn);
        }
      },
    );
    return child;
  }
}
