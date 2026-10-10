import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_personality.dart';
import '../../bots/bot_player.dart';
import '../../engine/card.dart';
import '../../engine/game_config.dart';
import '../../engine/melds.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/scoring.dart';
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
final roundFactoryProvider = Provider<Round Function(int firstSeat)>((ref) {
  final config = ref.watch(gameConfigProvider);
  final random = ref.watch(randomProvider);
  return (firstSeat) =>
      Round.deal(config: config, random: random, firstSeat: firstSeat);
});

/// How well the bots play. Medium for Quick Play; the lobby will let players
/// choose.
final botDifficultyProvider = Provider<BotDifficulty>(
  (ref) => BotDifficulty.medium,
);

/// How long a bot "thinks" before each move: a slightly different pause
/// every time, so bots feel human. Tests override it with no pause.
final botThinkingTimeProvider = Provider<Duration Function()>((ref) {
  final random = ref.watch(randomProvider);
  return () => Duration(milliseconds: 700 + random.nextInt(701));
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
/// Every other seat is a [BotPlayer] with its own personality. Bots play one
/// at a time after a short thinking pause, and the table is published after
/// each bot's move, so the player watches the game unfold. The human player
/// can't move while a bot is thinking.
class TableController extends Notifier<TableState> {
  late Round Function(int firstSeat) _newRound;
  late Round _round;
  late Map<int, BotPlayer> _bots;
  late Duration Function() _thinkingTime;
  late MatchScore _match;
  Future<void>? _botsPlaying;
  var _nextCardId = 0;
  var _firstSeat = 0;
  var _roundNumber = 1;
  var _roundRecorded = false;

  @override
  TableState build() {
    _newRound = ref.watch(roundFactoryProvider);
    _thinkingTime = ref.watch(botThinkingTimeProvider);
    _firstSeat = 0;
    _roundNumber = 1;
    _round = _newRound(_firstSeat);
    _match = MatchScore(_round.hands.length);

    // The same bots play every round of the match.
    final random = ref.watch(randomProvider);
    final difficulty = ref.watch(botDifficultyProvider);
    final botSeats = [
      for (var seat = 0; seat < _round.hands.length; seat++)
        if (seat != humanSeat) seat,
    ];
    final personalities = BotPersonality.pick(botSeats.length, random);
    _bots = {
      for (var i = 0; i < botSeats.length; i++)
        botSeats[i]: BotPlayer(
          difficulty: difficulty,
          personality: personalities[i],
          random: random,
        ),
    };

    return _setUpRound();
  }

  /// Deals the next round once the current one is over. The first player
  /// moves one seat round the table, and match totals carry on.
  void startNextRound() {
    if (!_round.isOver) return;
    _firstSeat = (_firstSeat + 1) % _round.hands.length;
    _roundNumber++;
    _round = _newRound(_firstSeat);
    state = _setUpRound();
  }

  /// Makes the opening shows for the newly dealt [_round] and returns its
  /// first state.
  TableState _setUpRound() {
    _botsPlaying = null;
    _nextCardId = 0;
    _roundRecorded = false;

    for (final MapEntry(key: seat, value: bot) in _bots.entries) {
      _round.showOpeningTunnellas(
        seat,
        bot.openingTunnellas(_round.hands[seat].cards),
      );
    }

    // The human player's tunnellas are shown for them, unless they hold
    // more than 3 and have to choose.
    final tunnellas = findTunnellas(_round.hands[humanSeat].cards);
    final mustChoose = tunnellas.length > PlayerHand.maxOpeningTunnellas;
    if (!mustChoose) {
      _round.showOpeningTunnellas(humanSeat, tunnellas);
      // If a bot goes first, start it once this first state is in place.
      Future.microtask(_playBots);
    }

    return TableState(
      view: _snapshot(),
      hand: _reconcile(const []),
      openingChoice: mustChoose ? tunnellas : null,
      roundNumber: _roundNumber,
      seatNames: [
        for (var seat = 0; seat < _round.hands.length; seat++) _nameOf(seat),
      ],
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
    );
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
    final shown = _act(
      () => _round.showOpeningTunnellas(humanSeat, [
        for (final i in picks) choice[i],
      ]),
    );
    if (shown) {
      state = state.copyWith(openingChoice: () => null);
      _playBots();
    }
  }

  /// Draws from [source] to start the human player's turn.
  void draw(DrawSource source) {
    if (!_checkYourTurn()) return;
    _act(() => _round.draw(source));
  }

  /// Discards the card with [cardId] to end the human player's turn; the
  /// bots then play until it's the human player's turn again. The returned
  /// future completes once they have.
  Future<void> discard(int cardId) async {
    final card = _cardWithId(cardId);
    if (card == null || !_checkYourTurn()) return;
    if (_act(() => _round.discard(card), removing: {cardId})) {
      await _playBots();
    }
  }

  /// Completes once any bots that are playing have finished their turns.
  Future<void> get botsSettled => _botsPlaying ?? Future.value();

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
    if (!_checkYourTurn()) return;
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
    if (!_checkYourTurn()) return;
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
  Future<void> tapDiscardPile() async {
    if (!_checkYourTurn()) return;
    if (!state.view.youHaveDrawn) {
      draw(DrawSource.discardPile);
      return;
    }
    final selected = state.singleSelected;
    if (selected == null) {
      _publish(notice: 'Select one card, then tap the discard pile.');
      return;
    }
    await discard(selected.id);
  }

  /// Whether the human player may move now; if not, says why.
  bool _checkYourTurn() {
    if (state.view.isYourTurn) return true;
    final winner = state.view.winner;
    _publish(
      notice: winner != null
          ? 'The round is over.'
          : 'Wait for ${_nameOf(_round.currentSeat)} to play.',
    );
    return false;
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

  /// Plays bot turns, with a thinking pause before each, until it's the
  /// human player's turn or the round is over. Only one run happens at a
  /// time; calling again while bots are playing joins the current run.
  Future<void> _playBots() =>
      _botsPlaying ??= _runBots().whenComplete(() => _botsPlaying = null);

  Future<void> _runBots() async {
    while (!_round.isOver && _round.currentSeat != humanSeat) {
      await Future<void>.delayed(_thinkingTime());
      if (!ref.mounted) return;
      final seat = _round.currentSeat;
      final turn = _bots[seat]!.takeTurn(_round);
      _publish(
        notice: turn.won ? '${_nameOf(seat)} won the round.' : null,
        botMoves: {...state.botMoves, seat: describeBotTurn(turn)},
      );
    }
  }

  void _publish({
    String? notice,
    Set<int> removed = const {},
    Map<int, String>? botMoves,
  }) {
    // Score a finished round once, however it ended.
    if (_round.isOver && !_roundRecorded) {
      _match.addRound(_round.score());
      _roundRecorded = true;
    }

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
      botMoves: botMoves,
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
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

  TableView _snapshot() => TableView.fromRound(
    _round,
    humanSeat: humanSeat,
    nameOf: _nameOf,
    avatarOf: (seat) => _bots[seat]?.personality.avatarColor,
  );

  String _nameOf(int seat) =>
      seat == humanSeat ? 'You' : _bots[seat]!.personality.name;
}

/// A bot's turn in a few words, for its seat: "Took 7♣, threw 9♦".
String describeBotTurn(BotTurn turn) {
  final parts = [
    turn.drewFrom == DrawSource.discardPile ? 'took ${turn.drawn}' : 'drew',
    if (turn.shown.isNotEmpty) 'showed',
    if (turn.won) 'won!' else 'threw ${turn.discarded}',
  ];
  final text = parts.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}

/// The engine's reason for refusing a move, naming the card when there is
/// one.
String _explain(ArgumentError e) => switch (e.invalidValue) {
  PlayingCard card => '$card ${e.message}',
  _ => '${e.message}',
};
