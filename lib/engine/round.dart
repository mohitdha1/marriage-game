import 'dart:math';

import 'card.dart';
import 'game_config.dart';
import 'joker.dart';
import 'player_hand.dart';
import 'scoring.dart';
import 'shoe.dart';
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
/// class simply takes it out of the stock.
///
/// Read state from here and act through this class's methods, not through
/// the [PlayerHand]s directly, so the table rules are always applied.
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
       _jokerDiscards = List.filled(hands.length, 0) {
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

  final GameConfig config;
  final Random _random;
  final List<PlayerHand> _hands;
  final List<PlayingCard> _stock;
  final List<PlayingCard> _discardPile;
  final List<int> _jokerDiscards;
  int _currentSeat;
  Jokers? _jokers;
  PlayingCard? _takenFromDiscardPile;
  int? _winner;

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

  /// The jokers as seen by [seat]: `null` until that player has shown and
  /// the tiplu has been picked.
  Jokers? jokersFor(int seat) {
    final jokers = _jokers;
    return jokers == null ? null : _hands[seat].visibleJokers(jokers);
  }

  /// How many wild cards each seat has discarded after seeing the joker
  /// (always 0 when [GameConfig.jokerDiscardPenaltyEnabled] is off).
  List<int> get jokerDiscards => List.unmodifiable(_jokerDiscards);

  bool get isOver => _winner != null;

  /// The seat that won, or `null` while the round is still being played.
  int? get winner => _winner;

  /// Makes [seat]'s opening show of their dealt tunnellas. See
  /// [PlayerHand.showOpeningTunnellas].
  void showOpeningTunnellas(int seat, List<List<PlayingCard>> tunnellas) {
    _checkNotOver();
    _hands[seat].showOpeningTunnellas(tunnellas);
  }

  /// Starts the current player's turn by taking a card from [source], and
  /// returns it. If the stock is empty, the discard pile (apart from its top
  /// card) is shuffled to make a new stock first.
  PlayingCard draw(DrawSource source) {
    _checkNotOver();
    _checkEveryoneOpened();

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
    return card;
  }

  /// The current player shows pure sets to see the joker. See
  /// [PlayerHand.showPureSets]. The first player to show must also pass
  /// [tipluPosition] to pick the tiplu; later players must not.
  void showPureSets(List<List<PlayingCard>> sets, {int? tipluPosition}) {
    _showThenPickTiplu(tipluPosition, () => _currentHand.showPureSets(sets));
  }

  /// The current player shows 7 doublees to see the joker. See
  /// [PlayerHand.showDoublees]. [tipluPosition] works as in [showPureSets].
  void showDoublees(List<List<PlayingCard>> pairs, {int? tipluPosition}) {
    _showThenPickTiplu(tipluPosition, () => _currentHand.showDoublees(pairs));
  }

  /// Ends the current player's turn by discarding [card], and passes the
  /// turn to the next seat.
  void discard(PlayingCard card) {
    _checkNotOver();
    _discardFromCurrentHand(card);
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
    );
  }

  void _showThenPickTiplu(int? tipluPosition, void Function() show) {
    _checkNotOver();
    _checkEveryoneOpened();
    if (_jokers != null) {
      if (tipluPosition != null) {
        throw ArgumentError.value(
          tipluPosition,
          'tipluPosition',
          'the tiplu has already been picked',
        );
      }
      show();
      return;
    }

    // First to show: check the pick before showing, so a bad position
    // leaves everything untouched, then take the card only once the show
    // has succeeded.
    _refillStockIfEmpty();
    if (tipluPosition == null ||
        tipluPosition < 0 ||
        tipluPosition >= _stock.length) {
      throw ArgumentError.value(
        tipluPosition,
        'tipluPosition',
        'the first player to show must pick a stock position from 0 to '
            '${_stock.length - 1}',
      );
    }
    show();
    _jokers = Jokers(_stock.removeAt(_stock.length - 1 - tipluPosition));
  }

  void _discardFromCurrentHand(PlayingCard card) {
    _checkCanDiscard(card);
    final hand = _currentHand;
    hand.discard(card);
    _discardPile.add(card);
    _takenFromDiscardPile = null;

    final jokers = _jokers;
    if (config.jokerDiscardPenaltyEnabled &&
        hand.hasSeenJoker &&
        jokers != null &&
        jokers.isWild(card)) {
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
    final top = _discardPile.removeLast();
    _stock.addAll(_discardPile);
    _discardPile
      ..clear()
      ..add(top);
    fisherYatesShuffle(_stock, _random);
  }

  void _checkNotOver() {
    if (isOver) throw StateError('The round is over');
  }

  void _checkEveryoneOpened() {
    if (!_hands.every((hand) => hand.hasOpened)) {
      throw StateError('Every player must make their opening show first');
    }
  }
}
