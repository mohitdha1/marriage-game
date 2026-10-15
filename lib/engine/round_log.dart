import 'card.dart';
import 'player_hand.dart';
import 'round.dart';
import 'table_event.dart';

/// The cards a [Round] started from: [hands] by seat, and [stock] and
/// [discardPile] with their top card last. With [Round.log], enough to
/// play the round again exactly as it went.
class RoundStart {
  RoundStart({
    required List<List<PlayingCard>> hands,
    required List<PlayingCard> stock,
    required List<PlayingCard> discardPile,
    required this.firstSeat,
  }) : hands = List.unmodifiable(hands.map(List<PlayingCard>.unmodifiable)),
       stock = List.unmodifiable(stock),
       discardPile = List.unmodifiable(discardPile);

  final List<List<PlayingCard>> hands;
  final List<PlayingCard> stock;
  final List<PlayingCard> discardPile;
  final int firstSeat;
}

/// One thing that changed a [Round], in the order it happened. Unlike a
/// [TableEvent], it holds everything needed to make the same change again,
/// including what players can't see: where the tiplu was picked from, and
/// the order a reshuffled stock came out in.
sealed class RoundLogEntry {
  const RoundLogEntry();
}

/// [seat] made their opening show of [tunnellas], perhaps none.
class OpeningMove extends RoundLogEntry {
  const OpeningMove(this.seat, this.tunnellas);

  final int seat;
  final List<List<PlayingCard>> tunnellas;
}

/// The player whose turn it was drew from [source].
class DrawMove extends RoundLogEntry {
  const DrawMove(this.source);

  final DrawSource source;
}

/// The player whose turn it was showed [sets] of [kind] to see the joker,
/// picking the tiplu at [tipluPosition] if they were the first to show.
class ShowMove extends RoundLogEntry {
  const ShowMove(this.kind, this.sets, this.tipluPosition);

  final ShowKind kind;
  final List<List<PlayingCard>> sets;
  final int? tipluPosition;
}

/// The player whose turn it was picked the tiplu again, at [position].
class PickTipluMove extends RoundLogEntry {
  const PickTipluMove(this.position);

  final int position;
}

/// The player whose turn it was discarded [card].
class DiscardMove extends RoundLogEntry {
  const DiscardMove(this.card);

  final PlayingCard card;
}

/// The player whose turn it was won, discarding [card].
class WinMove extends RoundLogEntry {
  const WinMove(this.card);

  final PlayingCard card;
}

/// The stock ran out and the discards were shuffled into [stock], top card
/// last.
class StockShuffle extends RoundLogEntry {
  const StockShuffle(this.stock);

  final List<PlayingCard> stock;
}
