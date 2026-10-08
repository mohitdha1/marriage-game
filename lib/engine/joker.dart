import 'card.dart';
import 'shoe.dart';

/// The role a card plays once the joker (tiplu) for the round is known.
enum JokerKind {
  /// The flipped card itself: same suit and rank.
  tiplu,

  /// Same suit, one rank below the tiplu.
  jhiplu,

  /// Same suit, one rank above the tiplu.
  poplu,

  /// Same rank as the tiplu, in the other suit of the same colour
  /// (e.g. 7♦ when the tiplu is 7♥).
  alter,

  /// Same rank as the tiplu, in one of the two opposite-colour suits.
  ordinary,
}

/// The jokers for one round, all derived from the flipped [tiplu].
///
/// Every [JokerKind] is wild: any card of the tiplu's rank (whatever the
/// suit), plus the jhiplu and poplu. Jhiplu/poplu wrap around the ace, so a
/// tiplu of A gives poplu 2, and a tiplu of 2 gives jhiplu A.
class Jokers {
  const Jokers(this.tiplu);

  /// Flips the top card of [shoe] — normally the stock left after dealing —
  /// to become the tiplu. The flipped card leaves the shoe.
  factory Jokers.flipFrom(Shoe shoe) => Jokers(shoe.draw());

  final PlayingCard tiplu;

  PlayingCard get jhiplu => PlayingCard(tiplu.suit, _shiftRank(tiplu.rank, -1));

  PlayingCard get poplu => PlayingCard(tiplu.suit, _shiftRank(tiplu.rank, 1));

  PlayingCard get alter =>
      PlayingCard(_sameColourPartner(tiplu.suit), tiplu.rank);

  /// What kind of joker [card] is this round, or `null` if it's a normal card.
  JokerKind? kindOf(PlayingCard card) {
    if (card == tiplu) return JokerKind.tiplu;
    if (card == jhiplu) return JokerKind.jhiplu;
    if (card == poplu) return JokerKind.poplu;
    if (card == alter) return JokerKind.alter;
    if (card.rank == tiplu.rank) return JokerKind.ordinary;
    return null;
  }

  /// Whether [card] can stand in for any other card in a sequence or trial.
  bool isWild(PlayingCard card) => kindOf(card) != null;
}

/// Moves [rank] up or down by [delta] steps, wrapping between ace and two.
Rank _shiftRank(Rank rank, int delta) {
  const ranks = Rank.values;
  return ranks[(rank.index + delta) % ranks.length];
}

/// Hearts pair with diamonds (red); clubs pair with spades (black).
Suit _sameColourPartner(Suit suit) => switch (suit) {
  Suit.hearts => Suit.diamonds,
  Suit.diamonds => Suit.hearts,
  Suit.clubs => Suit.spades,
  Suit.spades => Suit.clubs,
};
