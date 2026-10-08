import 'card.dart';
import 'joker.dart';

/// A tunnella is exactly 3 physically-identical cards (same suit AND rank) —
/// the maximum possible with a 3-deck shoe.
bool isTunnella(List<PlayingCard> cards) {
  if (cards.length != 3) return false;
  return cards[0] == cards[1] && cards[1] == cards[2];
}

/// A trial is 3 cards of the same rank across 3 strictly different suits.
bool isTrial(List<PlayingCard> cards) {
  if (cards.length != 3) return false;

  final rank = cards.first.rank;
  if (!cards.every((c) => c.rank == rank)) return false;

  final suits = cards.map((c) => c.suit).toSet();
  return suits.length == 3;
}

/// A pure sequence is 3 to 5 consecutive same-suit cards, with no jokers
/// involved. Ace can act as high (Q-K-A) or low (A-2-3), but never wraps
/// (K-A-2 is not valid either way).
bool isPureSequence(List<PlayingCard> cards) {
  if (cards.length < 3 || cards.length > 5) return false;

  final suit = cards.first.suit;
  if (!cards.every((c) => c.suit == suit)) return false;

  final aceHighValues = cards.map((c) => c.rank.order).toList()..sort();
  if (_isConsecutive(aceHighValues)) return true;

  final aceLowValues =
      cards.map((c) => c.rank == Rank.ace ? 1 : c.rank.order).toList()
        ..sort();
  return _isConsecutive(aceLowValues);
}

/// A sequence is 3 to 5 same-suit cards in a run, where wild cards (see
/// [Jokers.isWild]) can fill any gaps or extend either end. At least one
/// card must be a natural (non-wild) card, unless the cards already form a
/// pure sequence on their face values. Ace is high or low, never wrapping,
/// exactly as in [isPureSequence].
///
/// Every pure sequence is also a valid sequence; a wild card sitting in its
/// natural place (e.g. tiplu 7♥ in 6♥-7♥-8♥) still counts as pure, because
/// [isPureSequence] only looks at face values.
bool isSequenceWithJokers(List<PlayingCard> cards, Jokers jokers) {
  if (cards.length < 3 || cards.length > 5) return false;
  if (isPureSequence(cards)) return true;

  final naturals = cards.where((c) => !jokers.isWild(c)).toList();
  if (naturals.isEmpty) return false;

  final suit = naturals.first.suit;
  if (!naturals.every((c) => c.suit == suit)) return false;

  final aceHighValues = naturals.map((c) => c.rank.order).toList();
  if (_fitsInRun(aceHighValues, cards.length)) return true;

  final aceLowValues = naturals
      .map((c) => c.rank == Rank.ace ? 1 : c.rank.order)
      .toList();
  return _fitsInRun(aceLowValues, cards.length);
}

/// A trial is 3 cards of the same rank in 3 different suits, where wild cards
/// (see [Jokers.isWild]) can stand in for missing suits. At least one card
/// must be natural, unless the cards already form a trial on face value.
bool isTrialWithJokers(List<PlayingCard> cards, Jokers jokers) {
  if (cards.length != 3) return false;
  if (isTrial(cards)) return true;

  final naturals = cards.where((c) => !jokers.isWild(c)).toList();
  if (naturals.isEmpty) return false;

  final rank = naturals.first.rank;
  if (!naturals.every((c) => c.rank == rank)) return false;

  final suits = naturals.map((c) => c.suit).toSet();
  return suits.length == naturals.length;
}

/// Whether distinct [values] can all sit inside one run of [runLength]
/// consecutive values, with wild cards filling the remaining slots.
bool _fitsInRun(List<int> values, int runLength) {
  final sorted = [...values]..sort();
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] == sorted[i - 1]) return false;
  }
  return sorted.last - sorted.first + 1 <= runLength;
}

bool _isConsecutive(List<int> sortedValues) {
  for (var i = 1; i < sortedValues.length; i++) {
    if (sortedValues[i] != sortedValues[i - 1] + 1) return false;
  }
  return true;
}
