enum Suit {
  clubs,
  diamonds,
  hearts,
  spades;

  String get symbol => switch (this) {
        Suit.clubs => '♣',
        Suit.diamonds => '♦',
        Suit.hearts => '♥',
        Suit.spades => '♠',
      };
}

enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.order);

  /// Relative order for sequence comparisons, two (lowest) through ace
  /// (highest). Whether ace can also act as low (wrapping with two) is a
  /// sequence-detection rule, not a card-model concern, so it isn't decided
  /// here.
  final int order;

  String get label => switch (this) {
        Rank.jack => 'J',
        Rank.queen => 'Q',
        Rank.king => 'K',
        Rank.ace => 'A',
        _ => order.toString(),
      };
}

/// A value type: two [PlayingCard]s are equal whenever their suit and rank
/// match, regardless of which of the 3 physical decks they came from. Rule
/// logic (sequences, trials, tunnella) only ever cares about suit+rank, never
/// which physical copy is which.
class PlayingCard {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final Rank rank;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '${rank.label}${suit.symbol}';
}
