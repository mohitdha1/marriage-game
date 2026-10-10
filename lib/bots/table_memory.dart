import '../engine/card.dart';
import '../engine/hand_arrangement.dart';
import '../engine/round.dart';
import '../engine/table_event.dart';
import 'hand_analysis.dart';

/// What a careful player at [seat] remembers about the round, built only
/// from public information: their own hand, every laid-down set, and the
/// history of draws and discards in [Round.events].
class TableMemory {
  TableMemory.read(Round round, this.seat)
    : _copiesPerCard = round.config.deckCount {
    final hands = round.hands;
    _nextSeat = (seat + 1) % hands.length;
    _nextHasSeenJoker = hands[_nextSeat].hasSeenJoker;

    final gone = <PlayingCard>[...hands[seat].cards];
    for (final hand in hands) {
      for (final set in [...hand.openingTunnellas, ...hand.shownSets]) {
        gone.addAll(set);
      }
    }
    final jokers = round.jokersFor(seat);
    if (jokers != null) gone.add(jokers.tiplu);

    // Discards buried under the top card are out of reach until the stock
    // is reshuffled.
    var buried = <PlayingCard>[];
    for (final event in round.events) {
      switch (event) {
        case DiscardedCard(:final card) || WonRound(:final card):
          buried.add(card);
        case DrewCard(source: DrawSource.discardPile, :final card?):
          buried.remove(card);
          if (event.seat == _nextSeat) _takenByNext.add(card);
        case StockReshuffled():
          buried = buried.isEmpty ? [] : [buried.last];
        case DrewCard() || OpenedTunnellas() || ShowedSets():
          break;
      }
      if (event case DiscardedCard(:final card) when event.seat == _nextSeat) {
        _thrownByNext.add(card);
      }
    }
    final top = round.topDiscard;
    if (top != null) buried.remove(top);
    gone.addAll(buried);

    _gone = countCopies(gone);
  }

  final int seat;
  final int _copiesPerCard;
  late final int _nextSeat;
  late final bool _nextHasSeenJoker;
  late final Map<PlayingCard, int> _gone;
  final _takenByNext = <PlayingCard>[];
  final _thrownByNext = <PlayingCard>[];

  /// How many more copies of [card] could still be drawn by anyone.
  int stillAvailable(PlayingCard card) =>
      (_copiesPerCard - (_gone[card] ?? 0)).clamp(0, _copiesPerCard);

  /// How much discarding [card] would help the next player, judged by what
  /// they've taken from and thrown onto the discard pile.
  int danger(PlayingCard card) {
    var score = 0;
    for (final taken in _takenByNext) {
      if (taken == card) {
        score += 2;
      } else if (taken.suit == card.suit) {
        final gap = rankGap(taken.rank, card.rank);
        if (gap == 1) score += 2;
        if (gap == 2) score += 1;
      } else if (_nextHasSeenJoker && taken.rank == card.rank) {
        score += 1;
      }
    }
    // A card they threw away themselves is one they don't want back.
    if (_thrownByNext.contains(card)) score -= 2;
    return score;
  }
}
