import 'card.dart';
import 'player_hand.dart';
import 'round.dart';

/// Something that happened at the table that every player could see. A
/// [Round] keeps these in order in [Round.events], so players (and bots)
/// can remember the game the way people at a real table do.
///
/// Only public information is recorded: a card drawn from the stock is never
/// revealed, but a card taken from the discard pile is.
sealed class TableEvent {
  const TableEvent(this.seat);

  /// The seat that acted.
  final int seat;
}

/// [seat] laid down their dealt tunnellas in the opening show.
class OpenedTunnellas extends TableEvent {
  const OpenedTunnellas(super.seat, this.tunnellas);

  final List<List<PlayingCard>> tunnellas;
}

/// [seat] drew from [source]. [card] is only known when it came from the
/// discard pile; a stock card stays hidden.
class DrewCard extends TableEvent {
  const DrewCard(super.seat, this.source, [this.card]);

  final DrawSource source;
  final PlayingCard? card;
}

/// [seat] showed [sets] to see the joker.
class ShowedSets extends TableEvent {
  const ShowedSets(super.seat, this.kind, this.sets);

  final ShowKind kind;
  final List<List<PlayingCard>> sets;
}

/// [seat] discarded [card] to end their turn.
class DiscardedCard extends TableEvent {
  const DiscardedCard(super.seat, this.card);

  final PlayingCard card;
}

/// [seat] won the round, discarding [card] as their final discard.
class WonRound extends TableEvent {
  const WonRound(super.seat, this.card);

  final PlayingCard card;
}

/// The stock ran out, so the discard pile (apart from its top card) was
/// shuffled into a new stock during [seat]'s draw.
class StockReshuffled extends TableEvent {
  const StockReshuffled(super.seat);
}
