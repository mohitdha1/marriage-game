import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/preferences.dart';
import '../state/table_state.dart';

/// The tips of the first-time guide, in the order a new player meets them.
enum GuideStep {
  /// Draw a card. Done once the player draws.
  draw,

  /// Discard by dragging up or flicking. Done once the player discards.
  discard,

  /// Make sets with Group, then Show to see the joker.
  sets,

  /// What wild cards do now, and how to win.
  joker;

  /// Whether the tip goes away by itself once the player does the move,
  /// rather than with a Got it button.
  bool get doneByPlaying => this == draw || this == discard;
}

/// The guide's tip to show for [state], given the tips already [done], or
/// `null` for none. A tip only shows while it applies: on the player's own
/// turn, with no picker or reveal open, and nothing else to finish first.
GuideStep? guideStepFor(TableState state, Set<GuideStep> done) {
  final view = state.view;
  final busy =
      view.winner != null ||
      state.openingChoice != null ||
      state.pickingTiplu ||
      state.revealingJoker;
  if (busy || !view.isYourTurn) return null;

  if (!done.contains(GuideStep.draw)) {
    return view.youHaveDrawn ? null : GuideStep.draw;
  }
  if (!done.contains(GuideStep.discard)) {
    return view.youHaveDrawn ? GuideStep.discard : null;
  }
  if (!done.contains(GuideStep.sets)) return GuideStep.sets;
  if (!done.contains(GuideStep.joker) && view.youHaveSeenJoker) {
    return GuideStep.joker;
  }
  return null;
}

/// Which of the guide's tips the player has finished, saved between
/// launches so each tip shows only once.
final guideProvider = NotifierProvider<GuideController, Set<GuideStep>>(
  GuideController.new,
);

class GuideController extends Notifier<Set<GuideStep>> {
  static const _done = 'guide.done';

  PreferencesStore get _store => ref.read(preferencesProvider);

  @override
  Set<GuideStep> build() {
    final saved = ref.watch(preferencesProvider).getString(_done) ?? '';
    final byName = GuideStep.values.asNameMap();
    return {for (final name in saved.split(',')) ?byName[name]};
  }

  /// Marks [step] as finished.
  void complete(GuideStep step) {
    if (state.contains(step)) return;
    _save({...state, step});
  }

  /// Finishes every tip at once.
  void skip() => _save(GuideStep.values.toSet());

  /// Starts the guide over, for the player's next game.
  void restart() => _save({});

  void _save(Set<GuideStep> done) {
    state = done;
    _store.setString(_done, done.map((s) => s.name).join(','));
  }
}
