import 'dart:math';

import '../engine/card.dart';
import '../engine/joker.dart';

/// How likely [card] is to end up in a set alongside [others]. Identical
/// copies and close same-suit cards always help; same-rank cards only help
/// once the joker is seen, because trials don't count toward the show.
/// Wild cards, the Superman included, are worth keeping above everything
/// else. A man card, dead until the joker is seen, still beats a loose
/// card: it becomes wild and is maal.
///
/// [stillAvailable], when given, says how many more copies of a card could
/// still turn up. Partners that can no longer be completed count for less,
/// which is how a card-counting bot spots dead cards.
int usefulness(
  PlayingCard card,
  List<PlayingCard> others,
  Jokers? jokers, {
  int Function(PlayingCard card)? stillAvailable,
  int pairBonus = 0,
}) {
  if (card.isSuperman || (jokers != null && jokers.isWild(card))) {
    return 100;
  }
  if (card.isMan) return _manBeforeSeeing;

  var score = 0;
  for (final other in others) {
    if (other.isPrinted) continue;
    if (other == card) {
      score += 2 + pairBonus;
    } else if (other.suit == card.suit) {
      final gap = rankGap(card.rank!, other.rank!);
      if (gap == 1) score += 2;
      if (gap == 2) score += 1;
      // A run with a gap needs the card in between; if every copy of it is
      // already gone, the pair can never become a run.
      if (gap == 2 && stillAvailable != null) {
        final between = _between(card, other);
        if (between != null && stillAvailable(between) == 0) score -= 1;
      }
    } else if (jokers != null && other.rank == card.rank) {
      score += 1;
    }
  }
  if (stillAvailable != null && stillAvailable(card) == 0 && score > 0) {
    // No more copies are coming, so a lone near-miss is less promising.
    score -= 1;
  }
  return score;
}

/// What a man card is worth keeping before the joker is seen: as much as a
/// card one step from a run.
const _manBeforeSeeing = 2;

/// Distance between two ranks, letting the ace sit next to the two.
int rankGap(Rank a, Rank b) {
  final high = (a.order - b.order).abs();
  int low(Rank r) => r == Rank.ace ? 1 : r.order;
  return min(high, (low(a) - low(b)).abs());
}

/// The card that would fill the gap between two same-suit cards two ranks
/// apart, or `null` if they aren't two apart.
PlayingCard? _between(PlayingCard a, PlayingCard b) {
  for (final rank in Rank.values) {
    final middle = PlayingCard(a.suit!, rank);
    if (rankGap(a.rank!, rank) == 1 && rankGap(b.rank!, rank) == 1) {
      return middle;
    }
  }
  return null;
}
