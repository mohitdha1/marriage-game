import 'card.dart';

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

bool _isConsecutive(List<int> sortedValues) {
  for (var i = 1; i < sortedValues.length; i++) {
    if (sortedValues[i] != sortedValues[i - 1] + 1) return false;
  }
  return true;
}
