import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/table_event.dart';
import '../state/table_controller.dart';
import 'sound_effects.dart';

/// The sound, if any, for something that happened at the table, heard from
/// [yourSeat]: every draw and discard snaps, and the end of a round plays a
/// jingle if they won or a gentler tone if someone else did.
Sfx? soundFor(TableEvent event, {required int yourSeat}) => switch (event) {
  DrewCard() || DiscardedCard() => Sfx.cardSnap,
  WonRound(:final seat) => seat == yourSeat ? Sfx.win : Sfx.roundOver,
  OpenedTunnellas() || ShowedSets() || StockReshuffled() || KeptAside() => null,
};

/// Plays the table's sounds as the game unfolds: a shuffle whenever a round
/// is dealt, a sound for each new event in the round's public history, and
/// a chime when another player's move makes it the human player's turn.
/// Sounds follow the engine's events, so bots' moves are heard too.
class TableSounds extends ConsumerStatefulWidget {
  const TableSounds({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TableSounds> createState() => _TableSoundsState();
}

class _TableSoundsState extends ConsumerState<TableSounds> {
  @override
  void initState() {
    super.initState();
    // The first round is dealt as the table appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(soundEffectsProvider).play(Sfx.shuffle);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        final sounds = ref.read(soundEffectsProvider);
        if (previous == null || previous.round != next.round) {
          sounds.play(Sfx.shuffle);
          return;
        }
        for (final event in next.events.skip(previous.events.length)) {
          final sound = soundFor(event, yourSeat: next.you);
          if (sound != null) sounds.play(sound);
        }
        if (next.yourTurn && !previous.yourTurn) sounds.play(Sfx.yourTurn);
      },
    );
    return widget.child;
  }
}
