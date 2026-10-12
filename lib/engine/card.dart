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
/// Two kinds of printed joker have no suit or rank ([isPrinted]):
///
/// * a man card ([PlayingCard.man]): dead until its holder sees the joker,
///   then wild. All man cards are equal.
/// * the Superman ([PlayingCard.superman]): always wild, and can fill one
///   card of a set shown to see the joker.
class PlayingCard {
  const PlayingCard(Suit this.suit, Rank this.rank) : isSuperman = false;

  /// A printed joker, added to the shoe when man cards are on.
  const PlayingCard.man() : suit = null, rank = null, isSuperman = false;

  /// The one extra printed joker, added to the shoe when the Superman card
  /// is on.
  const PlayingCard.superman() : suit = null, rank = null, isSuperman = true;

  /// `null` only for a printed joker.
  final Suit? suit;

  /// `null` only for a printed joker.
  final Rank? rank;

  final bool isSuperman;

  /// Whether this is a printed joker, with no suit or rank.
  bool get isPrinted => rank == null;

  bool get isMan => isPrinted && !isSuperman;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.suit == suit &&
      other.rank == rank &&
      other.isSuperman == isSuperman;

  @override
  int get hashCode => Object.hash(suit, rank, isSuperman);

  @override
  String toString() => isSuperman
      ? 'Superman'
      : isMan
      ? 'Man'
      : '${rank!.label}${suit!.symbol}';
}

/// A number for [card] that is the same for equal cards and different for
/// unequal ones: 0–51 for the natural cards, suit by suit, 52 for a man
/// card and 53 for the Superman.
int cardIndex(PlayingCard card) {
  const naturals = 52;
  if (card.isSuperman) return naturals + 1;
  if (card.isMan) return naturals;
  return card.suit!.index * Rank.values.length + card.rank!.index;
}
