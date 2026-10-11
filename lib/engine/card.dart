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
///
/// A man card ([PlayingCard.man]) is a printed joker with no suit or rank:
/// dead until its holder sees the joker, then wild. All man cards are equal.
class PlayingCard {
  const PlayingCard(Suit this.suit, Rank this.rank);

  /// A printed joker, added to the shoe when man cards are on.
  const PlayingCard.man() : suit = null, rank = null;

  /// `null` only for a man card.
  final Suit? suit;

  /// `null` only for a man card.
  final Rank? rank;

  bool get isMan => rank == null;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => isMan ? 'Man' : '${rank!.label}${suit!.symbol}';
}

/// A number for [card] that is the same for equal cards and different for
/// unequal ones: 0–51 for the natural cards, suit by suit, and 52 for a man
/// card.
int cardIndex(PlayingCard card) => card.isMan
    ? Suit.values.length * Rank.values.length
    : card.suit!.index * Rank.values.length + card.rank!.index;
