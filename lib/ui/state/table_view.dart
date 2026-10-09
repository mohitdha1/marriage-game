import '../../engine/card.dart';
import '../../engine/joker.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';

/// One player's seat as everyone at the table can see it.
class SeatView {
  const SeatView({
    required this.seat,
    required this.name,
    required this.cardCount,
    this.hasSeenJoker = false,
    this.laidDown = const [],
  });

  final int seat;
  final String name;

  /// Cards still held, not counting any laid down.
  final int cardCount;

  /// Whether this player has shown their sets and seen the joker.
  final bool hasSeenJoker;

  /// Sets this player has laid face up: opening tunnellas, then the sets
  /// shown to see the joker.
  final List<List<PlayingCard>> laidDown;
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
    this.yourJokers,
    this.pureSetsStillNeeded = PlayerHand.pureSetsToShow,
  });

  /// Builds the view for [humanSeat]. [opponents] are listed in turn order
  /// starting from the player after [humanSeat], which the table screen lays
  /// out clockwise from the left.
  factory TableView.fromRound(
    Round round, {
    required int humanSeat,
    required String Function(int seat) nameOf,
  }) {
    final playerCount = round.hands.length;
    SeatView seatView(int seat) {
      final hand = round.hands[seat];
      return SeatView(
        seat: seat,
        name: nameOf(seat),
        cardCount: hand.cards.length,
        hasSeenJoker: hand.hasSeenJoker,
        laidDown: [...hand.openingTunnellas, ...hand.shownSets],
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
      yourJokers: round.jokersFor(humanSeat),
      pureSetsStillNeeded: yours.pureSetsStillNeeded,
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

  /// The jokers, once the human player has seen them; otherwise `null`.
  final Jokers? yourJokers;

  /// How many pure sets the human player still has to show, after counting
  /// their opening tunnellas.
  final int pureSetsStillNeeded;

  bool get youHaveSeenJoker => you.hasSeenJoker;

  bool get isYourTurn => winner == null && currentSeat == you.seat;
}
