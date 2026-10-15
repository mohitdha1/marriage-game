import 'dart:math';

import 'card.dart';
import 'game_config.dart';
import 'joker.dart';
import 'player_hand.dart';
import 'round_log.dart';
import 'scoring.dart';
import 'shoe.dart';
import 'table_event.dart';
import 'win_check.dart';

/// Where a player takes their card from at the start of a turn.
enum DrawSource { stock, discardPile }

/// One round of Marriage: the table state plus every action a player can
/// take, in order.
///
/// 1. **Deal:** each player gets their cards, and the next stock card is
///    turned up to start the discard pile.
/// 2. **Opening shows:** every player shows their dealt tunnellas
///    ([showOpeningTunnellas]) before anyone draws.
/// 3. **Turns,** starting at `firstSeat` and going round the table: [draw]
///    from the stock or the discard pile, optionally show, then [discard] —
///    or [declareWin] to finish the round with that final discard.
///
/// The joker isn't chosen at the deal. The first player to show picks any
/// card from the stock (`tipluPosition`, counted from the top) to be the
/// tiplu. It goes face down under the stock and is never drawn, so this
/// class simply takes it out of the stock. A printed joker (a man card or
/// the Superman) can't be the tiplu: the picker keeps it aside as maal and
/// picks again ([pickTiplu]).
///
/// Read state from here and act through this class's methods, not through
/// the [PlayerHand]s directly, so the table rules are always applied.
///
/// Every change is written to [log], so a round can be saved as its [start]
/// and log, and played again to the same point with [Round.replay].
class Round {
  /// Shuffles a fresh shoe with [random], deals, and turns up the first
  /// discard. [random] is also used whenever the stock needs reshuffling.
  factory Round.deal({
    required GameConfig config,
    required Random random,
    int firstSeat = 0,
  }) {
    final shoe = Shoe.fromConfig(config)..shuffle(random);
    final hands = shoe.deal(config);
    final stock = [...shoe.cards];
    final firstDiscard = stock.removeLast();
    return Round.fromCards(
      config: config,
      random: random,
      hands: hands,
      stock: stock,
      discardPile: [firstDiscard],
      firstSeat: firstSeat,
    );
  }

  /// Starts a round from cards that have already been dealt: [hands] by
  /// seat, and [stock] and [discardPile] with their top card last. Useful for
  /// tests and for restoring a saved game.
  Round.fromCards({
    required this.config,
    required Random random,
    required List<List<PlayingCard>> hands,
    required List<PlayingCard> stock,
    required List<PlayingCard> discardPile,
    int firstSeat = 0,
  }) : _random = random,
       _hands = [for (final cards in hands) PlayerHand(cards)],
       _stock = [...stock],
       _discardPile = [...discardPile],
       _currentSeat = firstSeat,
       _jokerDiscards = List.filled(hands.length, 0),
       start = RoundStart(
         hands: hands,
         stock: stock,
         discardPile: discardPile,
         firstSeat: firstSeat,
       ) {
    if (hands.length != config.playerCount) {
      throw ArgumentError.value(
        hands.length,
        'hands',
        'must have one hand per player (${config.playerCount})',
      );
    }
    if (firstSeat < 0 || firstSeat >= hands.length) {
      throw ArgumentError.value(firstSeat, 'firstSeat', 'is not a seat');
    }
  }

  /// Plays [log] again from [start], ending where the round it came from
  /// was when the log was taken. [random] is used only for reshuffles
  /// after the log runs out. Throws as the move would have if an entry
  /// isn't allowed, as when the log doesn't belong to [start].
  factory Round.replay({
    required GameConfig config,
    required Random random,
    required RoundStart start,
    required List<RoundLogEntry> log,
  }) {
    final round = Round.fromCards(
      config: config,
      random: random,
      hands: start.hands,
      stock: start.stock,
      discardPile: start.discardPile,
      firstSeat: start.firstSeat,
    );
    for (final entry in log) {
      switch (entry) {
        case OpeningMove(:final seat, :final tunnellas):
          round.showOpeningTunnellas(seat, tunnellas);
        case DrawMove(:final source):
          round.draw(source);
        case ShowMove(
          kind: ShowKind.pureSets,
          :final sets,
          :final tipluPosition,
        ):
          round.showPureSets(sets, tipluPosition: tipluPosition);
        case ShowMove(
          kind: ShowKind.doublees,
          :final sets,
          :final tipluPosition,
        ):
          round.showDoublees(sets, tipluPosition: tipluPosition);
        case PickTipluMove(:final position):
          round.pickTiplu(position);
        case DiscardMove(:final card):
          round.discard(card);
        case WinMove(:final card):
          round.declareWin(card);
        case StockShuffle(:final stock):
          round._refillStock(stock);
      }
    }
    return round;
  }

  final GameConfig config;

  /// The cards the round was dealt from.
  final RoundStart start;

  final Random _random;
  final List<PlayerHand> _hands;
  final List<PlayingCard> _stock;
  final List<PlayingCard> _discardPile;
  final List<int> _jokerDiscards;
  final List<TableEvent> _events = [];
  final List<RoundLogEntry> _log = [];
  int _currentSeat;
  Jokers? _jokers;
  PlayingCard? _takenFromDiscardPile;
  int? _winner;
  bool _needsTipluPick = false;

  /// Every player's hand, by seat.
  List<PlayerHand> get hands => List.unmodifiable(_hands);

  /// The seat whose turn it is.
  int get currentSeat => _currentSeat;

  PlayerHand get _currentHand => _hands[_currentSeat];

  /// How many cards are left to draw from the stock.
  int get stockCount => _stock.length;

  /// How many cards are in the discard pile.
  int get discardPileCount => _discardPile.length;

  /// The face-up card a player could take instead of drawing from the stock,
  /// or `null` if the discard pile is empty.
  PlayingCard? get topDiscard =>
      _discardPile.isEmpty ? null : _discardPile.last;

  /// Whether the tiplu has been picked yet (by the first player to show).
  bool get isJokerChosen => _jokers != null;

  /// Whether the current player picked a printed joker as the tiplu and must
  /// pick again with [pickTiplu] before anything else happens.
  bool get needsTipluPick => _needsTipluPick;

  /// The jokers as seen by [seat]: `null` until that player has shown and
  /// the tiplu has been picked.
  Jokers? jokersFor(int seat) {
    final jokers = _jokers;
    return jokers == null ? null : _hands[seat].visibleJokers(jokers);
  }

  /// How many wild cards each seat has discarded after seeing the joker,
  /// counting the Superman whenever it was discarded (always 0 when [GameConfig.jokerDiscardPenaltyEnabled] is off).
  List<int> get jokerDiscards => List.unmodifiable(_jokerDiscards);

  /// Everything every player has seen happen so far, oldest first.
  List<TableEvent> get events => List.unmodifiable(_events);

  /// Every change made to the round since [start], oldest first.
  List<RoundLogEntry> get log => List.unmodifiable(_log);

  bool get isOver => _winner != null;

  /// The card the current player took from the discard pile this turn,
  /// which they must keep until their next turn; `null` if they drew from
  /// the stock or haven't drawn yet.
  PlayingCard? get takenFromDiscardPile => _takenFromDiscardPile;

  /// The seat that won, or `null` while the round is still being played.
  int? get winner => _winner;

  /// Makes [seat]'s opening show of their dealt tunnellas. See
  /// [PlayerHand.showOpeningTunnellas].
  void showOpeningTunnellas(int seat, List<List<PlayingCard>> tunnellas) {
    _checkNotOver();
    _hands[seat].showOpeningTunnellas(tunnellas);
    _log.add(OpeningMove(seat, _copySets(tunnellas)));
    if (tunnellas.isNotEmpty) {
      _events.add(OpenedTunnellas(seat, _copySets(tunnellas)));
    }
  }

  /// Starts the current player's turn by taking a card from [source], and
  /// returns it. If the stock is empty, the discard pile (apart from its top
  /// card) is shuffled to make a new stock first.
  PlayingCard draw(DrawSource source) {
    _checkNotOver();
    _checkEveryoneOpened();
    _checkNoTipluPick();

    final PlayingCard card;
    switch (source) {
      case DrawSource.stock:
        _refillStockIfEmpty();
        if (_stock.isEmpty) throw StateError('No cards left to draw');
        card = _stock.last;
      case DrawSource.discardPile:
        if (_discardPile.isEmpty) {
          throw StateError('The discard pile is empty');
        }
        card = _discardPile.last;
    }

    // The hand checks it's a legal time to draw before anything moves.
    _currentHand.draw(card);
    if (source == DrawSource.stock) {
      _stock.removeLast();
    } else {
      _discardPile.removeLast();
      _takenFromDiscardPile = card;
    }
    _log.add(DrawMove(source));
    _events.add(
      DrewCard(
        _currentSeat,
        source,
        source == DrawSource.discardPile ? card : null,
      ),
    );
    return card;
  }

  /// The current player shows pure sets to see the joker. See
  /// [PlayerHand.showPureSets]. The first player to show must also pass
  /// [tipluPosition] to pick the tiplu; later players must not.
  void showPureSets(List<List<PlayingCard>> sets, {int? tipluPosition}) {
    _showThenPickTiplu(
      tipluPosition,
      ShowKind.pureSets,
      sets,
      () => _currentHand.showPureSets(sets),
    );
  }

  /// The current player shows 7 doublees to see the joker. See
  /// [PlayerHand.showDoublees]. [tipluPosition] works as in [showPureSets].
  void showDoublees(List<List<PlayingCard>> pairs, {int? tipluPosition}) {
    _showThenPickTiplu(
      tipluPosition,
      ShowKind.doublees,
      pairs,
      () => _currentHand.showDoublees(pairs),
    );
  }

  /// The current player picks the tiplu again, at [position] in the stock
  /// counted from the top, after their first pick was a printed joker.
  /// Another printed joker is kept aside too, and the pick goes on.
  void pickTiplu(int position) {
    _checkNotOver();
    if (!_needsTipluPick) throw StateError('There is no tiplu to pick');
    _refillStockIfEmpty();
    _checkTipluPosition(position);
    _takeTiplu(position);
    _log.add(PickTipluMove(position));
  }

  /// Ends the current player's turn by discarding [card], and passes the
  /// turn to the next seat.
  void discard(PlayingCard card) {
    _checkNotOver();
    _checkNoTipluPick();
    _discardFromCurrentHand(card);
    _log.add(DiscardMove(card));
    _events.add(DiscardedCard(_currentSeat, card));
    _currentSeat = (_currentSeat + 1) % _hands.length;
  }

  /// The current player finishes the round by discarding [card], if what's
  /// left in their hand is a winning hand:
  ///
  /// * after showing pure sets, every remaining card splits into sequences,
  ///   trials or tunnellas (jokers allowed);
  /// * after showing doublees, the remaining cards hold an 8th doublee.
  ///
  /// A player can draw, show, and win all in the same turn.
  void declareWin(PlayingCard card) {
    _checkNotOver();
    _checkNoTipluPick();
    final hand = _currentHand;
    if (!hand.hasSeenJoker) {
      throw StateError('Must see the joker before winning');
    }
    if (!hand.hasDrawn) {
      throw StateError('Must draw before winning');
    }
    _checkCanDiscard(card);
    final remaining = [...hand.cards];
    if (!remaining.remove(card)) {
      throw ArgumentError.value(card, 'card', 'is not in the hand');
    }

    final jokers = _jokers!;
    final isWinningHand = switch (hand.showKind!) {
      ShowKind.pureSets => canSplitIntoSets(remaining, jokers),
      ShowKind.doublees => containsDoubleeWithJokers(remaining, jokers),
    };
    if (!isWinningHand) {
      throw ArgumentError.value(
        card,
        'card',
        'does not leave a winning hand when discarded',
      );
    }

    _discardFromCurrentHand(card);
    _winner = _currentSeat;
    _log.add(WinMove(card));
    _events.add(WonRound(_currentSeat, card));
  }

  /// Settles the finished round. See [scoreRound].
  RoundScore score() {
    final winner = _winner;
    if (winner == null) throw StateError('The round is not over yet');
    return scoreRound(
      hands: _hands,
      winner: winner,
      jokers: _jokers!,
      jokerDiscards: _jokerDiscards,
      mode: config.mode,
      alterIsMaal: config.alterIsMaal,
    );
  }

  void _showThenPickTiplu(
    int? tipluPosition,
    ShowKind kind,
    List<List<PlayingCard>> sets,
    void Function() show,
  ) {
    _checkNotOver();
    _checkEveryoneOpened();
    _checkNoTipluPick();
    if (_jokers != null) {
      if (tipluPosition != null) {
        throw ArgumentError.value(
          tipluPosition,
          'tipluPosition',
          'the tiplu has already been picked',
        );
      }
      show();
      _log.add(ShowMove(kind, _copySets(sets), null));
      _events.add(ShowedSets(_currentSeat, kind, _copySets(sets)));
      return;
    }

    // First to show: check the pick before showing, so a bad position
    // leaves everything untouched, then take the card only once the show
    // has succeeded.
    _refillStockIfEmpty();
    _checkTipluPosition(tipluPosition);
    show();
    _log.add(ShowMove(kind, _copySets(sets), tipluPosition));
    _events.add(ShowedSets(_currentSeat, kind, _copySets(sets)));
    _takeTiplu(tipluPosition!);
  }

  void _checkTipluPosition(int? position) {
    if (position == null || position < 0 || position >= _stock.length) {
      throw ArgumentError.value(
        position,
        'tipluPosition',
        'the first player to show must pick a stock position from 0 to '
            '${_stock.length - 1}',
      );
    }
  }

  /// Takes the card at [position] as the tiplu, or keeps it aside for the
  /// current player if it's a printed joker, who then picks again.
  void _takeTiplu(int position) {
    final card = _stock.removeAt(_stock.length - 1 - position);
    _needsTipluPick = card.isPrinted;
    if (card.isPrinted) {
      _currentHand.keepAside(card);
      _events.add(KeptAside(_currentSeat, card));
    } else {
      _jokers = Jokers(card);
    }
  }

  void _discardFromCurrentHand(PlayingCard card) {
    _checkCanDiscard(card);
    final hand = _currentHand;
    hand.discard(card);
    _discardPile.add(card);
    _takenFromDiscardPile = null;

    final jokers = _jokers;
    final seenWild = hand.hasSeenJoker && jokers != null && jokers.isWild(card);
    if (config.jokerDiscardPenaltyEnabled && (card.isSuperman || seenWild)) {
      _jokerDiscards[_currentSeat]++;
    }
  }

  void _checkCanDiscard(PlayingCard card) {
    if (card == _takenFromDiscardPile) {
      throw ArgumentError.value(
        card,
        'card',
        'was just taken from the discard pile and must be kept this turn',
      );
    }
  }

  /// When the stock runs out, everything in the discard pile except its top
  /// card is shuffled to become the new stock.
  void _refillStockIfEmpty() {
    if (_stock.isNotEmpty || _discardPile.length < 2) return;
    final shuffled = _discardPile.sublist(0, _discardPile.length - 1);
    fisherYatesShuffle(shuffled, _random);
    _refillStock(shuffled);
  }

  /// Makes [shuffled], the discards under the top card in a new order, the
  /// stock.
  void _refillStock(List<PlayingCard> shuffled) {
    final top = _discardPile.removeLast();
    _stock.addAll(shuffled);
    _discardPile
      ..clear()
      ..add(top);
    _log.add(StockShuffle(List.unmodifiable(shuffled)));
    _events.add(StockReshuffled(_currentSeat));
  }

  static List<List<PlayingCard>> _copySets(List<List<PlayingCard>> sets) =>
      List.unmodifiable(sets.map(List<PlayingCard>.unmodifiable));

  void _checkNotOver() {
    if (isOver) throw StateError('The round is over');
  }

  void _checkNoTipluPick() {
    if (_needsTipluPick) {
      throw StateError('The tiplu must be picked again first');
    }
  }

  void _checkEveryoneOpened() {
    if (!_hands.every((hand) => hand.hasOpened)) {
      throw StateError('Every player must make their opening show first');
    }
  }
}
