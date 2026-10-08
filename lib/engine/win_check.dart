import 'card.dart';
import 'joker.dart';
import 'melds.dart';

/// Whether [cards] is one set that can finish a hand once the joker is seen:
/// a sequence or trial (jokers allowed, at least one natural card) or a
/// tunnella.
bool isFinishingSet(List<PlayingCard> cards, Jokers jokers) =>
    isTunnella(cards) ||
    isTrialWithJokers(cards, jokers) ||
    isSequenceWithJokers(cards, jokers);

/// Whether every card in [cards] can be split into [isFinishingSet]s, with
/// nothing left over. This is the pure-sets win check, run on the hand left
/// after the final discard (shown sets are already valid and aren't
/// included).
bool canSplitIntoSets(List<PlayingCard> cards, Jokers jokers) {
  // Hands that are known not to split, keyed by their sorted contents, so the
  // same leftover cards aren't searched twice.
  final dead = <String>{};

  bool split(List<PlayingCard> remaining) {
    if (remaining.isEmpty) return true;
    if (remaining.length < 3) return false;

    final key = _key(remaining);
    if (dead.contains(key)) return false;

    // Whatever the split, the first card must be in some set. Try every set
    // made of it plus 2 or more of the other cards.
    final first = remaining.first;
    final rest = remaining.sublist(1);
    for (var mask = 1; mask < 1 << rest.length; mask++) {
      final set = [first];
      final left = <PlayingCard>[];
      for (var i = 0; i < rest.length; i++) {
        // Bit i of the mask says whether rest[i] joins the set.
        if (mask & (1 << i) != 0) {
          set.add(rest[i]);
        } else {
          left.add(rest[i]);
        }
      }
      if (set.length < 3) continue;
      if (isFinishingSet(set, jokers) && split(left)) return true;
    }

    dead.add(key);
    return false;
  }

  return split(cards);
}

/// Whether [cards] holds an 8th doublee for the dublee game: two identical
/// cards, or any two cards where at least one is wild (two jokers count).
bool containsDoubleeWithJokers(List<PlayingCard> cards, Jokers jokers) {
  if (cards.length < 2) return false;
  if (cards.any(jokers.isWild)) return true;
  return cards.toSet().length < cards.length;
}

String _key(List<PlayingCard> cards) {
  final ids = cards.map((c) => c.suit.index * 100 + c.rank.index).toList()
    ..sort();
  return ids.join(',');
}
