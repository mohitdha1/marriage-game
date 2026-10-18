import '../../engine/card.dart';
import '../../engine/joker.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/table_event.dart';

/// One player's seat as everyone at the table can see it.
class SeatView {
  const SeatView({
    required this.seat,
    required this.name,
    required this.cardCount,
    this.hasShown = false,
    this.hasSeenJoker = false,
    this.laidDown = const [],
    this.look,
    this.lastDiscard,
  });

  final int seat;
  final String name;

  /// Cards still held, not counting any laid down.
  final int cardCount;

  /// Whether this player has shown their sets (or doublees).
  final bool hasShown;

  /// Whether this player has seen the joker: once the discard after their
  /// show is made, or straight after an early show.
  final bool hasSeenJoker;

  /// Sets this player has laid face up: opening tunnellas, then the sets
  /// shown to see the joker, then each printed joker they kept aside on its
  /// own.
  final List<List<PlayingCard>> laidDown;

  /// This player's avatar, as its number among the drawn avatar looks, if
  /// they have one.
  final int? look;

  /// The card this player discarded most recently this round, if any.
  final PlayingCard? lastDiscard;
}

/// An immutable snapshot of a [Round] as seen from [you]'s seat: what the
/// table screen draws. It shows only what that player is allowed to see —
/// their own cards, but just a count for everyone else's, and the joker only
/// once they've seen it.
class TableView {
  const TableView({
    required this.you,
    required this.opponents,
    required this.hand,
    required this.stockCount,
    required this.topDiscard,
    required this.currentSeat,
    required this.youHaveDrawn,
    required this.winner,
    this.isJokerChosen = false,
    this.youMustPickTiplu = false,
    this.youPickTipluAgain = false,
    this.youHaveShownThisTurn = false,
    this.yourJokers,
    this.pureSetsStillNeeded = PlayerHand.pureSetsToShow,
    this.events = const [],
  });

  /// Builds the view for [humanSeat]. [opponents] are listed in turn order
  /// starting from the player after [humanSeat], which the table screen lays
  /// out clockwise from the left.
  factory TableView.fromRound(
    Round round, {
    required int humanSeat,
    required String Function(int seat) nameOf,
    int? Function(int seat)? lookOf,
  }) {
    final playerCount = round.hands.length;
    SeatView seatView(int seat) {
      final hand = round.hands[seat];
      return SeatView(
        seat: seat,
        name: nameOf(seat),
        cardCount: hand.cards.length,
        hasShown: hand.hasShown,
        hasSeenJoker: hand.hasSeenJoker,
        laidDown: [
          ...hand.openingTunnellas,
          ...hand.shownSets,
          for (final card in hand.keptAside) [card],
        ],
        look: lookOf?.call(seat),
        lastDiscard: _lastDiscardBy(seat, round.events),
      );
    }

    final yours = round.hands[humanSeat];
    return TableView(
      you: seatView(humanSeat),
      opponents: [
        for (var i = 1; i < playerCount; i++)
          seatView((humanSeat + i) % playerCount),
      ],
      hand: yours.cards,
      stockCount: round.stockCount,
      topDiscard: round.topDiscard,
      currentSeat: round.currentSeat,
      youHaveDrawn: yours.hasDrawn,
      winner: round.winner == null ? null : seatView(round.winner!),
      isJokerChosen: round.isJokerChosen,
      youMustPickTiplu: round.needsTipluPick && round.currentSeat == humanSeat,
      youPickTipluAgain:
          round.needsTipluPick &&
          round.currentSeat == humanSeat &&
          yours.keptAside.isNotEmpty,
      youHaveShownThisTurn: yours.shownThisTurn,
      yourJokers: round.jokersFor(humanSeat),
      pureSetsStillNeeded: yours.pureSetsStillNeeded,
      events: round.events,
    );
  }

  final SeatView you;
  final List<SeatView> opponents;

  /// The human player's cards, in the order they hold them.
  final List<PlayingCard> hand;

  final int stockCount;

  /// The face-up card on the discard pile, or `null` if it's empty.
  final PlayingCard? topDiscard;

  /// The seat whose turn it is.
  final int currentSeat;

  /// Whether the human player has drawn this turn and now owes a discard.
  final bool youHaveDrawn;

  /// Who won the round, or `null` while it's still being played.
  final SeatView? winner;

  /// Whether anyone has picked the tiplu yet.
  final bool isJokerChosen;

  /// Whether the human player must pick the tiplu before play goes on:
  /// they were the first to show and have just discarded, or they picked a
  /// printed joker and pick again.
  final bool youMustPickTiplu;

  /// Whether that pick is a second (or later) one, after a printed joker.
  final bool youPickTipluAgain;

  /// Whether the human player showed this turn, so can't win until their
  /// next.
  final bool youHaveShownThisTurn;

  /// The jokers, once the human player has seen them; otherwise `null`.
  final Jokers? yourJokers;

  /// How many pure sets the human player still has to show, after counting
  /// their opening tunnellas.
  final int pureSetsStillNeeded;

  /// Everything every player has seen happen this round, oldest first.
  final List<TableEvent> events;

  bool get youHaveShown => you.hasShown;

  bool get youHaveSeenJoker => you.hasSeenJoker;

  bool get isYourTurn => winner == null && currentSeat == you.seat;
}

/// The card [seat] discarded most recently in [events], if any.
PlayingCard? _lastDiscardBy(int seat, List<TableEvent> events) {
  for (final event in events.reversed) {
    if (event.seat != seat) continue;
    switch (event) {
      case DiscardedCard(:final card) || WonRound(:final card):
        return card;
      case _:
        continue;
    }
  }
  return null;
}
