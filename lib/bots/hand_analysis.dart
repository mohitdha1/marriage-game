import 'dart:math';

import '../engine/card.dart';
import '../engine/joker.dart';
import '../engine/melds.dart';
import '../engine/win_check.dart';

/// Every way to pick [count] separate pure sets (3-card pure sequences or
/// tunnellas) from [cards]. Empty if there aren't that many.
List<List<List<PlayingCard>>> allPureSetChoices(
  List<PlayingCard> cards,
  int count,
) {
  final candidates = _pureSetCandidates(cards);
  final available = countCopies(cards);
  final choices = <List<List<PlayingCard>>>[];

  void pick(int from, List<List<PlayingCard>> chosen) {
    if (chosen.length == count) {
      choices.add([...chosen]);
      return;
    }
    for (var i = from; i < candidates.length; i++) {
      final set = candidates[i];
      if (!_takeAll(available, set)) continue;
      pick(i, [...chosen, set]);
      _returnAll(available, set);
    }
  }

  pick(0, []);
  return choices;
}

/// The first way found to pick [count] separate pure sets from [cards], or
/// `null` if there aren't that many.
List<List<PlayingCard>>? findPureSets(List<PlayingCard> cards, int count) {
  final choices = allPureSetChoices(cards, count);
  return choices.isEmpty ? null : choices.first;
}

/// Up to [count] separate doublees (pairs of identical cards) in [cards], or
/// `null` if there are fewer than [count].
List<List<PlayingCard>>? findDoublees(List<PlayingCard> cards, int count) {
  final pairs = [
    for (final MapEntry(key: card, value: n) in countCopies(cards).entries)
      for (var i = 0; i < n ~/ 2; i++) [card, card],
  ];
  return pairs.length < count ? null : pairs.take(count).toList();
}

/// How many copies of each card [cards] holds.
Map<PlayingCard, int> countCopies(Iterable<PlayingCard> cards) {
  final copies = <PlayingCard, int>{};
  for (final card in cards) {
    copies[card] = (copies[card] ?? 0) + 1;
  }
  return copies;
}

/// How likely [card] is to end up in a set alongside [others]. Identical
/// copies and close same-suit cards always help; same-rank cards only help
/// once the joker is seen, because trials don't count toward the show.
/// Wild cards are worth keeping above everything else.
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
  if (jokers != null && jokers.isWild(card)) return 100;

  var score = 0;
  for (final other in others) {
    if (other == card) {
      score += 2 + pairBonus;
    } else if (other.suit == card.suit) {
      final gap = rankGap(card.rank, other.rank);
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
    final middle = PlayingCard(a.suit, rank);
    if (rankGap(a.rank, rank) == 1 && rankGap(b.rank, rank) == 1) {
      return middle;
    }
  }
  return null;
}

/// Every distinct 3-card pure sequence and tunnella that [cards] could
/// make, ignoring overlaps between them.
List<List<PlayingCard>> _pureSetCandidates(List<PlayingCard> cards) {
  final copies = countCopies(cards);
  final sets = <List<PlayingCard>>[...findTunnellas(cards)];
  for (final suit in Suit.values) {
    // Ace low (A-2-3) first, then every run up to Q-K-A.
    final runs = [
      [Rank.ace, Rank.two, Rank.three],
      for (var i = 0; i + 2 < Rank.values.length; i++)
        Rank.values.sublist(i, i + 3),
    ];
    for (final ranks in runs) {
      final run = [for (final rank in ranks) PlayingCard(suit, rank)];
      if (run.every(copies.containsKey) && isPureSequence(run)) {
        sets.add(run);
      }
    }
  }
  return sets;
}

bool _takeAll(Map<PlayingCard, int> available, List<PlayingCard> set) {
  final needed = countCopies(set);
  if (needed.entries.any((e) => (available[e.key] ?? 0) < e.value)) {
    return false;
  }
  needed.forEach((card, n) => available[card] = available[card]! - n);
  return true;
}

void _returnAll(Map<PlayingCard, int> available, List<PlayingCard> set) {
  for (final card in set) {
    available[card] = available[card]! + 1;
  }
}

/// The most cards in [cards] that can be covered by separate sets at once —
/// a measure of how close a hand is to finishing.
///
/// Before the joker is seen ([jokers] is `null`) only pure sequences and
/// tunnellas count, since those are what a player must show. Afterwards,
/// any finishing set counts, jokers included. Sets of more than
/// [maxSetSize] cards aren't tried, which keeps the search fast and loses
/// little: a long run still scores through its shorter pieces.
int maxCoverage(List<PlayingCard> cards, Jokers? jokers, {int maxSetSize = 5}) {
  bool isSet(List<PlayingCard> set) => jokers == null
      ? isPureSequence(set) || isTunnella(set)
      : isFinishingSet(set, jokers);
  bool isWild(PlayingCard card) => jokers?.isWild(card) ?? false;

  final known = <String, int>{};

  int best(List<PlayingCard> remaining) {
    if (remaining.length < 3) return 0;
    final key = _key(remaining);
    final cached = known[key];
    if (cached != null) return cached;

    // Either the first card stays uncovered, or it joins a set with some of
    // its possible partners: cards of its suit, cards of its rank, or wild
    // cards (see canSplitIntoSets for why no others can join).
    final firstIndex = remaining.indexWhere((c) => !isWild(c));
    final first = remaining[firstIndex < 0 ? 0 : firstIndex];
    final rest = [...remaining]..remove(first);
    var result = best(rest);

    final partners = <PlayingCard>[];
    final others = <PlayingCard>[];
    for (final card in rest) {
      if (firstIndex < 0 ||
          isWild(card) ||
          card.suit == first.suit ||
          card.rank == first.rank) {
        partners.add(card);
      } else {
        others.add(card);
      }
    }
    for (var mask = 1; mask < 1 << partners.length; mask++) {
      final size = _bitCount(mask) + 1;
      if (size < 3 || size > maxSetSize) continue;
      final set = [first];
      final left = [...others];
      for (var i = 0; i < partners.length; i++) {
        if (mask & (1 << i) != 0) {
          set.add(partners[i]);
        } else {
          left.add(partners[i]);
        }
      }
      if (isSet(set)) result = max(result, set.length + best(left));
    }

    known[key] = result;
    return result;
  }

  return best(cards);
}

int _bitCount(int n) {
  var count = 0;
  for (var m = n; m != 0; m &= m - 1) {
    count++;
  }
  return count;
}

String _key(List<PlayingCard> cards) {
  final ids = cards.map((c) => c.suit.index * 100 + c.rank.index).toList()
    ..sort();
  return ids.join(',');
}
