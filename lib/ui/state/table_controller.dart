import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../console/simple_bot.dart';
import '../../engine/card.dart';
import '../../engine/game_config.dart';
import '../../engine/melds.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/win_check.dart';
import 'table_state.dart';
import 'table_view.dart';

/// Settings for the current game. Overridden in tests and, later, by the
/// lobby's custom-game options.
final gameConfigProvider = Provider<GameConfig>((ref) => GameConfig());

/// The random source for shuffling and bot choices. Tests override it with a
/// seeded [Random] so games are repeatable.
final randomProvider = Provider<Random>((ref) => Random());

/// Starts a new round. Tests override it to deal known cards.
final roundFactoryProvider = Provider<Round Function()>((ref) {
  final config = ref.watch(gameConfigProvider);
  final random = ref.watch(randomProvider);
  return () => Round.deal(config: config, random: random);
});

/// The seat the person using this device plays.
const humanSeat = 0;

/// The table as the human player sees it.
final tableProvider = NotifierProvider<TableController, TableState>(
  TableController.new,
);

/// Owns the engine's [Round], applies the human player's moves to it, and
/// publishes a fresh [TableState] after each one. The engine stays the single
/// source of truth: every move goes through it, and when it refuses one, its
/// reason is shown to the player as a notice.
///
/// Bot seats are played by the console's [SimpleBot] for now; real bots
/// arrive in Phase 2 step 4.
class TableController extends Notifier<TableState> {
  late Round _round;
  late SimpleBot _bot;
  var _nextCardId = 0;

  @override
  TableState build() {
    _round = ref.watch(roundFactoryProvider)();
    _bot = SimpleBot(ref.watch(randomProvider));
    _nextCardId = 0;

    for (var seat = 0; seat < _round.hands.length; seat++) {
      if (seat == humanSeat) continue;
      _round.showOpeningTunnellas(
        seat,
        _bot.openingTunnellas(_round.hands[seat].cards),
      );
    }

    // The human player's tunnellas are shown for them, unless they hold
    // more than 3 and have to choose.
    final tunnellas = findTunnellas(_round.hands[humanSeat].cards);
    final mustChoose = tunnellas.length > PlayerHand.maxOpeningTunnellas;
    if (!mustChoose) {
      _round.showOpeningTunnellas(humanSeat, tunnellas);
      _playBots();
    }

    return TableState(
      view: _snapshot(),
      hand: _reconcile(const []),
      openingChoice: mustChoose ? tunnellas : null,
    );
  }

  /// Selects [cardId] if it isn't selected, or deselects it if it is.
  void toggleSelected(int cardId) {
    final selected = {...state.selected};
    if (!selected.remove(cardId)) selected.add(cardId);
    state = state.copyWith(selected: selected);
  }

  /// Sorts the hand by suit, then rank.
  void sortHand() {
    final sorted = [...state.hand]
      ..sort((a, b) {
        final bySuit = a.card.suit.index.compareTo(b.card.suit.index);
        return bySuit != 0
            ? bySuit
            : a.card.rank.order.compareTo(b.card.rank.order);
      });
    state = state.copyWith(hand: sorted);
  }

  /// Makes the opening show with the tunnellas at [picks] (indexes into
  /// [TableState.openingChoice]).
  void chooseOpeningTunnellas(List<int> picks) {
    final choice = state.openingChoice;
    if (choice == null) return;
    if (picks.length != PlayerHand.maxOpeningTunnellas ||
        picks.toSet().length != picks.length ||
        picks.any((i) => i < 0 || i >= choice.length)) {
      _publish(notice: 'Choose 3 different tunnellas.');
      return;
    }
    var shown = false;
    _act(() {
      _round.showOpeningTunnellas(humanSeat, [
        for (final i in picks) choice[i],
      ]);
      shown = true;
      _playBots();
    });
    if (shown) state = state.copyWith(openingChoice: () => null);
  }

  /// Draws from [source] to start the human player's turn.
  void draw(DrawSource source) => _act(() => _round.draw(source));

  /// Discards the card with [cardId] to end the human player's turn; the
  /// bots then play until it's the human player's turn again.
  void discard(int cardId) {
    final card = _cardWithId(cardId);
    if (card == null) return;
    _act(() {
      _round.discard(card);
      _playBots();
    }, removing: {cardId});
  }

  /// Groups the selected cards into a set to show. Grouped cards move
  /// together to the left of the hand, in the order the groups were made.
  void groupSelected() {
    if (state.selected.length < 2) {
      _publish(notice: 'Select 2 or more cards to group.');
      return;
    }
    final newGroup = [
      for (final handCard in state.hand)
        if (state.selected.contains(handCard.id)) handCard.id,
    ];
    final groups = [
      for (final group in state.groups)
        [
          for (final id in group)
            if (!state.selected.contains(id)) id,
        ],
      newGroup,
    ].where((group) => group.isNotEmpty).toList();
    state = state.copyWith(
      groups: groups,
      hand: _groupedFirst(state.hand, groups),
      selected: {},
    );
  }

  /// Breaks up every group.
  void clearGroups() => state = state.copyWith(groups: []);

  /// Shows the grouped sets to see the joker. If nobody has picked the tiplu
  /// yet, the player picks it first ([pickTiplu]), then the sets are shown.
  void showGroups() {
    if (state.groups.isEmpty) {
      _publish(notice: 'Group your sets first, then tap Show.');
      return;
    }
    if (!state.view.isJokerChosen) {
      state = state.copyWith(pickingTiplu: true);
      return;
    }
    _showGroups(tipluPosition: null);
  }

  /// Picks the stock card at [position] (0 is the top) as the tiplu, and
  /// shows the grouped sets.
  void pickTiplu(int position) {
    state = state.copyWith(pickingTiplu: false);
    _showGroups(tipluPosition: position);
  }

  void cancelTipluPick() => state = state.copyWith(pickingTiplu: false);

  /// Closes the joker reveal.
  void dismissReveal() => state = state.copyWith(revealingJoker: false);

  /// Finishes the round by discarding the selected card, if that leaves a
  /// winning hand.
  void declareWin() {
    final selected = state.singleSelected;
    if (selected == null) {
      _publish(notice: 'Select the card to discard, then tap Win.');
      return;
    }
    _act(() => _round.declareWin(selected.card), removing: {selected.id});
  }

  void _showGroups({required int? tipluPosition}) {
    final sets = [
      for (final group in state.groups)
        [for (final id in group) _cardWithId(id)!],
    ];
    final ids = {for (final group in state.groups) ...group};
    final isDoublees =
        sets.length == PlayerHand.doubleesToShow &&
        sets.every((set) => set.length == 2);
    final shown = _act(() {
      if (isDoublees) {
        _round.showDoublees(sets, tipluPosition: tipluPosition);
      } else {
        _round.showPureSets(sets, tipluPosition: tipluPosition);
      }
    }, removing: ids);
    if (shown) {
      state = state.copyWith(groups: [], revealingJoker: true);
    }
  }

  /// Tapping the discard pile takes its top card at the start of a turn, or
  /// discards the selected card once the player has drawn.
  void tapDiscardPile() {
    if (!state.view.youHaveDrawn) {
      draw(DrawSource.discardPile);
      return;
    }
    final selected = state.singleSelected;
    if (selected == null) {
      _publish(notice: 'Select one card, then tap the discard pile.');
      return;
    }
    discard(selected.id);
  }

  PlayingCard? _cardWithId(int id) {
    for (final handCard in state.hand) {
      if (handCard.id == id) return handCard.card;
    }
    return null;
  }

  /// Runs [move] against the engine, turning a refused move into a notice,
  /// then publishes the new state. [removing] names the hand cards the move
  /// takes out of the hand, so the right copy goes when there are
  /// duplicates. Returns whether the engine accepted the move.
  bool _act(void Function() move, {Set<int> removing = const {}}) {
    String? notice;
    try {
      move();
    } on ArgumentError catch (e) {
      notice = _explain(e);
    } on StateError catch (e) {
      notice = e.message;
    }
    final accepted = notice == null;
    final winner = _round.winner;
    if (accepted && winner != null) {
      notice = winner == humanSeat
          ? 'You won the round!'
          : '${_nameOf(winner)} won the round.';
    }
    _publish(notice: notice, removed: accepted ? removing : const {});
    return accepted;
  }

  void _playBots() {
    while (!_round.isOver && _round.currentSeat != humanSeat) {
      _bot.takeTurn(_round);
    }
  }

  void _publish({String? notice, Set<int> removed = const {}}) {
    final hand = _reconcile([
      for (final handCard in state.hand)
        if (!removed.contains(handCard.id)) handCard,
    ]);
    final ids = {for (final c in hand) c.id};
    final groups = [
      for (final group in state.groups) group.where(ids.contains).toList(),
    ].where((group) => group.isNotEmpty).toList();
    state = state.copyWith(
      view: _snapshot(),
      hand: hand,
      selected: state.selected.where(ids.contains).toSet(),
      groups: groups,
      winningDiscards: _winningDiscards(hand),
      notice: notice,
    );
  }

  /// Ids of the cards in [hand] that would leave a winning hand if
  /// discarded now. Empty unless it's the human player's turn, they've drawn
  /// and they've seen the joker.
  Set<int> _winningDiscards(List<HandCard> hand) {
    final player = _round.hands[humanSeat];
    final jokers = _round.jokersFor(humanSeat);
    final route = player.showKind;
    if (_round.isOver ||
        _round.currentSeat != humanSeat ||
        !player.hasDrawn ||
        jokers == null ||
        route == null) {
      return {};
    }
    bool isWinningHand(List<PlayingCard> cards) => switch (route) {
      ShowKind.pureSets => canSplitIntoSets(cards, jokers),
      ShowKind.doublees => containsDoubleeWithJokers(cards, jokers),
    };

    final winning = <int>{};
    for (final candidate in hand) {
      final rest = [
        for (final handCard in hand)
          if (handCard.id != candidate.id) handCard.card,
      ];
      if (isWinningHand(rest)) winning.add(candidate.id);
    }
    return winning;
  }

  /// Brings the on-screen hand in line with the engine's: cards still held
  /// keep their place and id, cards that have left are dropped, and new
  /// cards are added at the right-hand end.
  List<HandCard> _reconcile(List<HandCard> shown) {
    final held = [..._round.hands[humanSeat].cards];
    final kept = <HandCard>[];
    for (final handCard in shown) {
      if (held.remove(handCard.card)) kept.add(handCard);
    }
    return [...kept, for (final card in held) HandCard(_nextCardId++, card)];
  }

  /// [hand] with the cards in [groups] moved to the front, group by group.
  static List<HandCard> _groupedFirst(
    List<HandCard> hand,
    List<List<int>> groups,
  ) {
    final byId = {for (final c in hand) c.id: c};
    final grouped = {for (final group in groups) ...group};
    return [
      for (final group in groups)
        for (final id in group) byId[id]!,
      for (final handCard in hand)
        if (!grouped.contains(handCard.id)) handCard,
    ];
  }

  TableView _snapshot() =>
      TableView.fromRound(_round, humanSeat: humanSeat, nameOf: _nameOf);

  /// Placeholder names until the Phase 2 bots get their own.
  static String _nameOf(int seat) => seat == humanSeat ? 'You' : 'Bot $seat';
}

/// The engine's reason for refusing a move, naming the card when there is
/// one.
String _explain(ArgumentError e) => switch (e.invalidValue) {
  PlayingCard card => '$card ${e.message}',
  _ => '${e.message}',
};
