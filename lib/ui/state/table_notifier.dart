import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/card.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import 'table_state.dart';

/// The table as one person sees and handles it, whatever plays the game
/// behind it: the engine on this device, or a host across the network.
///
/// Everything that only ever happens on the person's own device lives here:
/// selecting, sorting, moving and grouping cards, closing pickers, and
/// keeping each card's place in the hand as the game's view of it changes.
/// So do the checks made before a move is sent anywhere. The moves
/// themselves ([draw], [discard], [submitOpening], [submitShow],
/// [submitWin]) are left to whatever plays the game.
abstract class TableNotifier extends Notifier<TableState> {
  var _nextCardId = 0;

  // The game's side.

  /// Draws from [source] to start the turn.
  void draw(DrawSource source);

  /// Discards the card with [cardId] to end the turn. Completes once any
  /// bots have taken their turns after it.
  Future<void> discard(int cardId);

  /// Makes the opening show with [tunnellas].
  void submitOpening(List<List<PlayingCard>> tunnellas);

  /// Shows [sets], made of the hand cards with [ids], to see the joker;
  /// the first to show also picks the tiplu at [tipluPosition].
  void submitShow({
    required ShowKind kind,
    required List<List<PlayingCard>> sets,
    required Set<int> ids,
    required int? tipluPosition,
  });

  /// Wins the round by discarding the hand card [winning].
  void submitWin(HandCard winning);

  /// Deals the next round once the current one is over.
  void startNextRound();

  /// Whether this device deals the rounds. A device that has joined a game
  /// hosted elsewhere waits for the host to deal.
  bool get dealsRounds => true;

  /// Completes once any bots that are playing have finished their turns.
  Future<void> get botsSettled;

  /// Whether throwing a joker away after seeing it costs a penalty.
  bool get jokerPenaltyEnabled;

  // The person's own side.

  /// Shows [notice] to the person.
  void postNotice(String notice) => state = state.copyWith(notice: notice);

  /// Whether the person may move now; if not, says why.
  bool checkYourTurn() {
    if (state.passingTo case final seat?) {
      postNotice('Pass the device to ${state.seatNames[seat]} first.');
      return false;
    }
    final view = state.view;
    if (view.isYourTurn) return true;
    postNotice(
      view.winner != null
          ? 'The round is over.'
          : 'Wait for ${state.seatNames[view.currentSeat]} to play.',
    );
    return false;
  }

  /// The card with [id] in the hand, if it's there.
  PlayingCard? cardWithId(int id) {
    for (final handCard in state.hand) {
      if (handCard.id == id) return handCard.card;
    }
    return null;
  }

  /// Brings the on-screen hand in line with [held], the cards the game says
  /// the person holds: cards still held keep their place and id, cards that
  /// have left are dropped, and new cards are added at the right-hand end.
  List<HandCard> reconcile(List<PlayingCard> held, List<HandCard> shown) {
    final left = [...held];
    final kept = <HandCard>[];
    for (final handCard in shown) {
      if (left.remove(handCard.card)) kept.add(handCard);
    }
    return [...kept, for (final card in left) HandCard(_nextCardId++, card)];
  }

  /// Starts card ids afresh, for a new round's hand.
  void resetCardIds() => _nextCardId = 0;

  /// Uncovers the table once the person it was passed to has the device.
  void takeOver() {
    if (state.passingTo == null) return;
    state = state.copyWith(passingTo: () => null);
  }

  /// Selects [cardId] if it isn't selected, or deselects it if it is.
  void toggleSelected(int cardId) {
    final selected = {...state.selected};
    if (!selected.remove(cardId)) selected.add(cardId);
    state = state.copyWith(selected: selected);
  }

  /// Moves the card with [cardId] to [newIndex] in the hand, where it stays
  /// until it's moved again or the hand is sorted.
  void moveCard(int cardId, int newIndex) {
    final hand = [...state.hand];
    final from = hand.indexWhere((c) => c.id == cardId);
    if (from < 0) return;
    final card = hand.removeAt(from);
    hand.insert(newIndex.clamp(0, hand.length), card);
    state = state.copyWith(hand: hand);
  }

  /// The order Sort puts suits in: alternating black and red, so
  /// neighbouring suits are easy to tell apart.
  static const sortedSuits = [
    Suit.spades,
    Suit.hearts,
    Suit.clubs,
    Suit.diamonds,
  ];

  /// Sorts the hand by suit (♠ ♥ ♣ ♦), then by rank within each suit.
  /// Grouped sets stay together at the front, in the order they were made.
  void sortHand() {
    final byId = {for (final handCard in state.hand) handCard.id: handCard};
    final groupedCards = [
      for (final group in state.groups)
        for (final id in group) byId[id]!,
    ];
    final loose = [
      for (final handCard in state.hand)
        if (!groupedCards.contains(handCard)) handCard,
    ]..sort(_bySuitThenRank);
    state = state.copyWith(hand: [...groupedCards, ...loose]);
  }

  static int _bySuitThenRank(HandCard a, HandCard b) {
    final bySuit = sortedSuits
        .indexOf(a.card.suit)
        .compareTo(sortedSuits.indexOf(b.card.suit));
    return bySuit != 0
        ? bySuit
        : a.card.rank.order.compareTo(b.card.rank.order);
  }

  /// Groups the selected cards into a set to show. Grouped cards move
  /// together to the left of the hand, in the order the groups were made.
  void groupSelected() {
    if (state.selected.length < 2) {
      postNotice('Select 2 or more cards to group.');
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

  /// Makes the opening show with the tunnellas at [picks] (indexes into
  /// [TableState.openingChoice]).
  void chooseOpeningTunnellas(List<int> picks) {
    final choice = state.openingChoice;
    if (choice == null) return;
    if (picks.length != PlayerHand.maxOpeningTunnellas ||
        picks.toSet().length != picks.length ||
        picks.any((i) => i < 0 || i >= choice.length)) {
      postNotice('Choose 3 different tunnellas.');
      return;
    }
    submitOpening([for (final i in picks) choice[i]]);
  }

  /// Shows the grouped sets to see the joker. If nobody has picked the tiplu
  /// yet, the person picks it first ([pickTiplu]), then the sets are shown.
  void showGroups() {
    if (!checkYourTurn()) return;
    if (state.groups.isEmpty) {
      postNotice('Group your sets first, then tap Show.');
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

  void _showGroups({required int? tipluPosition}) {
    final sets = [
      for (final group in state.groups)
        [for (final id in group) cardWithId(id)!],
    ];
    final isDoublees =
        sets.length == PlayerHand.doubleesToShow &&
        sets.every((set) => set.length == 2);
    submitShow(
      kind: isDoublees ? ShowKind.doublees : ShowKind.pureSets,
      sets: sets,
      ids: {for (final group in state.groups) ...group},
      tipluPosition: tipluPosition,
    );
  }

  /// Finishes the round by discarding the selected card, if that leaves a
  /// winning hand.
  void declareWin() {
    if (!checkYourTurn()) return;
    final selected = state.singleSelected;
    if (selected == null) {
      postNotice('Select the card to discard, then tap Win.');
      return;
    }
    submitWin(selected);
  }

  /// Tapping the discard pile takes its top card at the start of a turn, or
  /// discards the selected card once the person has drawn.
  Future<void> tapDiscardPile() async {
    if (!checkYourTurn()) return;
    if (!state.view.youHaveDrawn) {
      draw(DrawSource.discardPile);
      return;
    }
    final selected = state.singleSelected;
    if (selected == null) {
      postNotice('Select one card, then tap the discard pile.');
      return;
    }
    await discard(selected.id);
  }

  /// Whether discarding the card with [cardId] now would cost the person
  /// the joker-discard penalty: it's their turn to discard, the penalty is
  /// in play, they've seen the joker, and the card is wild.
  bool discardCostsPenalty(int cardId) {
    final view = state.view;
    final jokers = view.yourJokers;
    final card = cardWithId(cardId);
    return jokerPenaltyEnabled &&
        view.isYourTurn &&
        view.youHaveDrawn &&
        view.youHaveSeenJoker &&
        jokers != null &&
        card != null &&
        jokers.isWild(card);
  }
}
