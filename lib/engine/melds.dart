import 'card.dart';
import 'joker.dart';

/// A tunnella is exactly 3 physically-identical cards (same suit AND rank) —
/// the maximum possible with a 3-deck shoe.
bool isTunnella(List<PlayingCard> cards) {
  if (cards.length != 3 || cards.first.isPrinted) return false;
  return cards[0] == cards[1] && cards[1] == cards[2];
}

/// A set the opening show can lay down: a [isTunnella], or all 3 man cards,
/// which count as a tunnella only there.
bool isOpeningTunnella(List<PlayingCard> cards) =>
    isTunnella(cards) || (cards.length == 3 && cards.every((c) => c.isMan));

/// A doublee is exactly 2 physically-identical cards (same suit AND rank).
/// Man cards never pair: they're dead until their holder sees the joker,
/// and doublees are shown before that.
bool isDoublee(List<PlayingCard> cards) {
  if (cards.length != 2 || cards.first.isPrinted) return false;
  return cards[0] == cards[1];
}

/// A doublee that can be shown to see the joker: an [isDoublee], or the
/// Superman paired with any other card.
bool isShowDoublee(List<PlayingCard> cards) =>
    isDoublee(cards) ||
    (cards.length == 2 && cards.where((c) => c.isSuperman).length == 1);

/// A pure set that can be shown to see the joker: an [isPureSequence], an
/// [isTunnella], or either of those with the Superman standing in for one
/// card ([isPureSetWithSuperman]).
bool isShowPureSet(List<PlayingCard> cards) =>
    isPureSequence(cards) || isTunnella(cards) || isPureSetWithSuperman(cards);

/// The Superman plus natural cards that would be a pure sequence or a
/// tunnella if the Superman were the one card missing, such as
/// 5♥ Superman 7♥, or K♠ K♠ Superman.
bool isPureSetWithSuperman(List<PlayingCard> cards) {
  final naturals = [
    for (final card in cards)
      if (!card.isSuperman) card,
  ];
  if (cards.length < 3 ||
      cards.length > Rank.values.length ||
      naturals.length != cards.length - 1 ||
      naturals.any((c) => c.isPrinted)) {
    return false;
  }
  if (cards.length == 3 && naturals[0] == naturals[1]) return true;

  final suit = naturals.first.suit;
  if (!naturals.every((c) => c.suit == suit)) return false;
  return _fitsInRun([for (final c in naturals) c.rank!.order], cards.length) ||
      _fitsInRun(naturals.map(_aceLowOrder).toList(), cards.length);
}

/// Every separate [isOpeningTunnella] in [cards]: one for each 3 copies of
/// a card, in the order the cards first appear.
List<List<PlayingCard>> findTunnellas(List<PlayingCard> cards) {
  final copies = <PlayingCard, int>{};
  for (final card in cards) {
    copies[card] = (copies[card] ?? 0) + 1;
  }
  return [
    for (final MapEntry(key: card, value: n) in copies.entries)
      for (var i = 0; i < n ~/ 3; i++) [card, card, card],
  ];
}

/// A trial is 3 cards of the same rank across 3 strictly different suits.
bool isTrial(List<PlayingCard> cards) {
  if (cards.length != 3 || cards.any((c) => c.isPrinted)) return false;

  final rank = cards.first.rank;
  if (!cards.every((c) => c.rank == rank)) return false;

  final suits = cards.map((c) => c.suit).toSet();
  return suits.length == 3;
}

/// A pure sequence is 3 or more consecutive same-suit cards, with no jokers
/// involved. Ace can act as high (Q-K-A) or low (A-2-3), but never wraps
/// (K-A-2 is not valid either way), so the longest possible run is 13 cards.
bool isPureSequence(List<PlayingCard> cards) {
  if (cards.length < 3 || cards.any((c) => c.isPrinted)) return false;

  final suit = cards.first.suit;
  if (!cards.every((c) => c.suit == suit)) return false;

  final aceHighValues = cards.map((c) => c.rank!.order).toList()..sort();
  if (_isConsecutive(aceHighValues)) return true;

  final aceLowValues = cards.map(_aceLowOrder).toList()..sort();
  return _isConsecutive(aceLowValues);
}

/// A sequence is 3 or more same-suit cards in a run, where wild cards (see
/// [Jokers.isWild]) can fill any gaps or extend either end. At least one
/// card must be a natural (non-wild) card, unless the cards already form a
/// pure sequence on their face values. Ace is high or low, never wrapping,
/// exactly as in [isPureSequence].
///
/// Every pure sequence is also a valid sequence; a wild card sitting in its
/// natural place (e.g. tiplu 7♥ in 6♥-7♥-8♥) still counts as pure, because
/// [isPureSequence] only looks at face values.
bool isSequenceWithJokers(List<PlayingCard> cards, Jokers jokers) {
  // Without wrapping round the ace, a run can't be longer than 13 ranks.
  if (cards.length < 3 || cards.length > Rank.values.length) return false;
  if (isPureSequence(cards)) return true;

  final naturals = cards.where((c) => !jokers.isWild(c)).toList();
  if (naturals.isEmpty) return false;

  final suit = naturals.first.suit;
  if (!naturals.every((c) => c.suit == suit)) return false;

  final aceHighValues = naturals.map((c) => c.rank!.order).toList();
  if (_fitsInRun(aceHighValues, cards.length)) return true;

  final aceLowValues = naturals.map(_aceLowOrder).toList();
  return _fitsInRun(aceLowValues, cards.length);
}

/// A natural card's order with the ace counted as 1, below the two.
int _aceLowOrder(PlayingCard card) =>
    card.rank == Rank.ace ? 1 : card.rank!.order;

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
