import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/table_event.dart';
import '../state/table_controller.dart';
import 'coach_mark.dart';
import 'guide.dart';

/// Shows the first-time guide's current tip over the table, and marks the
/// draw and discard tips done when the player makes those moves.
///
/// The tip sits where [statusLine] is: the gap between the piles and the
/// hand, where the table already says what to do next.
class TableGuideLayer extends ConsumerWidget {
  const TableGuideLayer({super.key, required this.statusLine});

  /// Links to the status line, which the tip is centred on.
  final LayerLink statusLine;

  /// Room kept clear at each side for the action buttons.
  static const sideClearance = 75.0;

  /// The widest a tip gets, on a large screen.
  static const maxWidth = 520.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tableProvider.select((s) => s.view.events), (previous, next) {
      // A new round starts its history afresh.
      final seen = previous == null || previous.length > next.length
          ? 0
          : previous.length;
      final guide = ref.read(guideProvider.notifier);
      final you = ref.read(tableProvider).view.you.seat;
      for (final event in next.skip(seen)) {
        if (event.seat != you) continue;
        switch (event) {
          case DrewCard():
            guide.complete(GuideStep.draw);
          case DiscardedCard() || WonRound():
            guide.complete(GuideStep.discard);
          case OpenedTunnellas() ||
              ShowedSets() ||
              StockReshuffled() ||
              KeptAside():
            break;
        }
      }
    });

    final step = guideStepFor(
      ref.watch(tableProvider),
      ref.watch(guideProvider),
    );
    if (step == null) return const SizedBox.shrink();
    final guide = ref.read(guideProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(maxWidth, constraints.maxWidth - 2 * sideClearance);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: width,
              child: CompositedTransformFollower(
                link: statusLine,
                showWhenUnlinked: false,
                targetAnchor: Alignment.center,
                followerAnchor: Alignment.center,
                // A little lower, into the room above the hand where a
                // selected card lifts: clear of the piles' labels above and
                // the Sort button beside it, even on a small phone.
                offset: const Offset(0, 11),
                child: CoachMark(
                  key: Key('guide-${step.name}'),
                  text: tipFor(step),
                  onSkip: guide.skip,
                  onGotIt: step.doneByPlaying
                      ? null
                      : () => guide.complete(step),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// What the guide says at [step]: short enough for one line on a small
/// phone.
String tipFor(GuideStep step) => switch (step) {
  GuideStep.draw => 'Your turn: tap the stock or the pile to draw.',
  GuideStep.discard => 'Drag a card up onto the pile, or flick it, to discard.',
  GuideStep.sets => 'Select cards, tap Group. With 3 pure sets, tap Show.',
  GuideStep.joker => 'Wild cards glow gold. Set every card, then discard.',
};
