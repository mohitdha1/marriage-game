import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_personality.dart';
import '../../bots/bot_player.dart';
import '../../engine/card.dart';
import '../../engine/game_config.dart';
import '../../engine/hand_arrangement.dart';
import '../../engine/melds.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/scoring.dart';
import '../../engine/win_check.dart';
import '../home/coins.dart';
import 'table_state.dart';
import 'table_view.dart';

/// Who plays a match: one person against bots, or several [people] passing
/// this device round the table.
@immutable
class MatchSetup {
  /// One person against [playerCount] − 1 bots at [difficulty].
  const MatchSetup({
    this.playerCount = 5,
    this.difficulty = BotDifficulty.medium,
  }) : people = const [];

  /// [people], named in seat order, taking turns on this device; no bots.
  MatchSetup.passAndPlay(List<String> people)
    : playerCount = people.length,
      difficulty = BotDifficulty.medium,
      people = List.unmodifiable(people);

  /// How many play, people and bots together.
  final int playerCount;

  /// How well the bots play, when there are bots.
  final BotDifficulty difficulty;

  /// The people sharing this device, by seat; empty against bots.
  final List<String> people;

  bool get isPassAndPlay => people.isNotEmpty;
}

/// Quick Play's setup: a full table of five against Medium bots.
const quickPlaySetup = MatchSetup();

/// The setup the next match starts with. Whatever starts a match chooses it:
/// Quick Play its own, a custom game the player's choices.
final matchSetupProvider = NotifierProvider<MatchSetupController, MatchSetup>(
  MatchSetupController.new,
);

class MatchSetupController extends Notifier<MatchSetup> {
  @override
  MatchSetup build() => quickPlaySetup;

  void choose(MatchSetup setup) => state = setup;
}

/// Settings for the current game: as many players as its setup says. Tests
/// override it.
final gameConfigProvider = Provider<GameConfig>(
  (ref) => GameConfig(playerCount: ref.watch(matchSetupProvider).playerCount),
);

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

/// How well the bots play, as the game's setup says.
final botDifficultyProvider = Provider<BotDifficulty>(
  (ref) => ref.watch(matchSetupProvider).difficulty,
);

/// How long a bot "thinks" before each move: a slightly different pause
/// every time, so bots feel human. Tests override it with no pause.
final botThinkingTimeProvider = Provider<Duration Function()>((ref) {
  final random = ref.watch(randomProvider);
  return () => Duration(milliseconds: 700 + random.nextInt(701));
});

/// The seat the person using this device plays in a game against bots.
const humanSeat = 0;

/// The table as the person whose view it is sees it.
final tableProvider = NotifierProvider<TableController, TableState>(
  TableController.new,
);

/// Owns the engine's [Round], applies the human player's moves to it, and
/// publishes a fresh [TableState] after each one. The engine stays the single
/// source of truth: every move goes through it, and when it refuses one, its
/// reason is shown to the player as a notice.
///
/// Every seat is a person or a [BotPlayer] with its own personality: one
/// person against bots, or several people passing this device round. Bots
/// play one at a time after a short thinking pause, and the table is
/// published after each bot's move, so the people watch the game unfold.
/// Nobody can move while a bot is thinking.
///
/// The table shows one person's view at a time: their hand, groups and
/// selection. Each person's are kept on their own [_Desk] while someone
/// else's turn is showing.
class TableController extends Notifier<TableState> {
  late Round Function(int firstSeat) _newRound;
  late Round _round;
  late Map<int, BotPlayer> _bots;

  /// The seats people play, and their names (empty against bots, where the
  /// one person is "You").
  late Set<int> _people;
  late List<String> _peopleNames;

  /// Whose view the table shows: the person playing now, or the last one to
  /// play while bots take their turns.
  var _viewer = humanSeat;

  /// Everyone else's private table, kept while it isn't their view.
  final _desks = <int, _Desk>{};
  late Duration Function() _thinkingTime;
  late MatchScore _match;
  Future<void>? _botsPlaying;
  var _nextCardId = 0;
  var _firstSeat = 0;
  var _roundNumber = 1;
  var _roundRecorded = false;

  @override
  TableState build() {
    // Read once: a match keeps the setup it started with, even if the
    // choices for the next game change meanwhile.
    _newRound = ref.read(roundFactoryProvider);
    _thinkingTime = ref.watch(botThinkingTimeProvider);
    _firstSeat = 0;
    _roundNumber = 1;
    _round = _newRound(_firstSeat);
    _match = MatchScore(_round.hands.length);

    final setup = ref.read(matchSetupProvider);
    final seats = [for (var seat = 0; seat < _round.hands.length; seat++) seat];
    _peopleNames = setup.people;
    _people = setup.isPassAndPlay ? seats.toSet() : {humanSeat};

    // The same bots play every round of the match.
    final random = ref.watch(randomProvider);
    final difficulty = ref.read(botDifficultyProvider);
    final botSeats = [
      for (final seat in seats)
        if (!_people.contains(seat)) seat,
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
    _desks.clear();

    for (final MapEntry(key: seat, value: bot) in _bots.entries) {
      _round.showOpeningTunnellas(
        seat,
        bot.openingTunnellas(_round.hands[seat].cards),
      );
    }

    // Each person's tunnellas are shown for them, unless they hold more
    // than 3 and have to choose.
    final choosing = <int>[];
    for (final seat in _inTurnOrder(_people)) {
      final tunnellas = findTunnellas(_round.hands[seat].cards);
      if (tunnellas.length > PlayerHand.maxOpeningTunnellas) {
        choosing.add(seat);
        _desks[seat] = _Desk(openingChoice: tunnellas);
      } else {
        _round.showOpeningTunnellas(seat, tunnellas);
      }
    }
    // The view opens on the first person who has to choose, or else on the
    // first person to play.
    _viewer = choosing.isNotEmpty
        ? choosing.first
        : _inTurnOrder(_people).first;
    final desk = _desks.remove(_viewer) ?? _Desk();
    if (choosing.isEmpty) {
      // If a bot goes first, start it once this first state is in place.
      Future.microtask(_advance);
    }

    return TableState(
      view: _snapshot(),
      hand: _reconcile(desk.hand),
      openingChoice: desk.openingChoice,
      roundNumber: _roundNumber,
      seatNames: [
        for (var seat = 0; seat < _round.hands.length; seat++) _nameOf(seat),
      ],
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
      handProgress: _handProgress(),
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
      () => _round.showOpeningTunnellas(_viewer, [
        for (final i in picks) choice[i],
      ]),
    );
    if (!shown) return;
    state = state.copyWith(openingChoice: () => null);
    // Anyone else who has to choose goes next; then play begins.
    final stillChoosing = _inTurnOrder(
      _people,
    ).where((seat) => _desks[seat]?.openingChoice != null);
    if (stillChoosing.isNotEmpty) {
      _switchTo(stillChoosing.first);
    } else {
      unawaited(_advance());
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
      await _advance();
    }
  }

  /// Whether discarding the card with [cardId] now would cost the person
  /// playing the joker-discard penalty: it's their turn to discard, the
  /// penalty is in play, they've seen the joker, and the card is wild.
  bool discardCostsPenalty(int cardId) {
    final view = state.view;
    final jokers = view.yourJokers;
    final card = _cardWithId(cardId);
    return _round.config.jokerDiscardPenaltyEnabled &&
        view.isYourTurn &&
        view.youHaveDrawn &&
        view.youHaveSeenJoker &&
        jokers != null &&
        card != null &&
        jokers.isWild(card);
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
      notice = _nameOf(winner) == 'You'
          ? 'You won the round!'
          : '${_nameOf(winner)} won the round.';
    }
    _publish(notice: notice, removed: accepted ? removing : const {});
    return accepted;
  }

  /// Plays any bots' turns, then turns the table to the person who plays
  /// next.
  Future<void> _advance() async {
    // With no bot to wait for, the table turns straight away.
    if (!_people.contains(_round.currentSeat)) await _playBots();
    if (!ref.mounted || _round.isOver) return;
    final next = _round.currentSeat;
    if (_people.contains(next) && next != _viewer) _switchTo(next);
  }

  /// Turns the table to [seat]'s view, keeping the current person's hand,
  /// groups and selection on their desk until it's their view again.
  void _switchTo(int seat) {
    _desks[_viewer] = _Desk(
      hand: state.hand,
      groups: state.groups,
      selected: state.selected,
      openingChoice: state.openingChoice,
    );
    _viewer = seat;
    final desk = _desks.remove(seat) ?? _Desk();
    state = state.copyWith(
      hand: desk.hand,
      groups: desk.groups,
      selected: desk.selected,
      openingChoice: () => desk.openingChoice,
      pickingTiplu: false,
      revealingJoker: false,
    );
    _publish();
  }

  /// [seats] in the order they play this round, from the first player.
  List<int> _inTurnOrder(Iterable<int> seats) {
    final count = _round.hands.length;
    return [
      for (var i = 0; i < count; i++)
        if (seats.contains((_firstSeat + i) % count)) (_firstSeat + i) % count,
    ];
  }

  /// Plays bot turns, with a thinking pause before each, until it's a
  /// person's turn or the round is over. Only one run happens at a
  /// time; calling again while bots are playing joins the current run.
  Future<void> _playBots() =>
      _botsPlaying ??= _runBots().whenComplete(() => _botsPlaying = null);

  Future<void> _runBots() async {
    while (!_round.isOver && !_people.contains(_round.currentSeat)) {
      await Future<void>.delayed(_thinkingTime());
      if (!ref.mounted) return;
      final seat = _round.currentSeat;
      final turn = _bots[seat]!.takeTurn(_round);
      _publish(notice: turn.won ? '${_nameOf(seat)} won the round.' : null);
    }
  }

  void _publish({String? notice, Set<int> removed = const {}}) {
    // Score a finished round once, however it ended.
    if (_round.isOver && !_roundRecorded) {
      final score = _round.score();
      _match.addRound(score);
      // Coins are the device owner's, won against bots; a game passed
      // round among friends doesn't touch them.
      if (_peopleNames.isEmpty) {
        ref.read(coinsProvider.notifier).addRoundResult(score.net[humanSeat]);
      }
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
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
      handProgress: _handProgress(),
      notice: notice,
    );
  }

  /// Ids of the cards in [hand] that would leave a winning hand if
  /// discarded now. Empty unless it's the viewer's turn, they've drawn and
  /// they've seen the joker.
  Set<int> _winningDiscards(List<HandCard> hand) {
    final player = _round.hands[_viewer];
    final jokers = _round.jokersFor(_viewer);
    final route = player.showKind;
    if (_round.isOver ||
        _round.currentSeat != _viewer ||
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
    final held = [..._round.hands[_viewer].cards];
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

  HandProgress _handProgress() =>
      handProgress(_round.hands[_viewer], _round.jokersFor(_viewer));

  TableView _snapshot() => TableView.fromRound(
    _round,
    humanSeat: _viewer,
    nameOf: _nameOf,
    avatarOf: (seat) => _bots[seat]?.personality.avatarColor,
  );

  String _nameOf(int seat) => switch (_bots[seat]) {
    final bot? => bot.personality.name,
    null when _peopleNames.isEmpty => 'You',
    null => _peopleNames[seat],
  };
}

/// One person's private table while someone else's view is showing: their
/// hand in the order they arranged it, their groups and selection, and the
/// opening tunnellas they still have to choose from.
class _Desk {
  _Desk({
    this.hand = const [],
    this.groups = const [],
    this.selected = const {},
    this.openingChoice,
  });

  final List<HandCard> hand;
  final List<List<int>> groups;
  final Set<int> selected;
  final List<List<PlayingCard>>? openingChoice;
}

/// The engine's reason for refusing a move, naming the card when there is
/// one.
String _explain(ArgumentError e) => switch (e.invalidValue) {
  PlayingCard card => '$card ${e.message}',
  _ => '${e.message}',
};
