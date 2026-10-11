import 'card.dart';

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

  /// A printed joker ([PlayingCard.man]), when man cards are in play.
  man,
}

/// The jokers for one round, all derived from the [tiplu]: the card the
/// first player to show picks from the stock.
///
/// Every [JokerKind] is wild: any card of the tiplu's rank (whatever the
/// suit), the jhiplu and poplu, and man cards. Jhiplu/poplu wrap around the ace, so a
/// tiplu of A gives poplu 2, and a tiplu of 2 gives jhiplu A.
class Jokers {
  Jokers(this.tiplu) {
    if (tiplu.isMan) {
      throw ArgumentError.value(tiplu, 'tiplu', 'cannot be a man card');
    }
  }

  final PlayingCard tiplu;

  PlayingCard get jhiplu => PlayingCard(_suit, _shiftRank(_rank, -1));

  PlayingCard get poplu => PlayingCard(_suit, _shiftRank(_rank, 1));

  PlayingCard get alter => PlayingCard(_sameColourPartner(_suit), _rank);

  Suit get _suit => tiplu.suit!;
  Rank get _rank => tiplu.rank!;

  /// What kind of joker [card] is this round, or `null` if it's a normal card.
  JokerKind? kindOf(PlayingCard card) {
    if (card.isMan) return JokerKind.man;
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
