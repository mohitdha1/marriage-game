import 'card.dart';
import 'joker.dart';
import 'melds.dart';
import 'player_hand.dart';

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

    // Whatever the split, this card must be in some set. Starting from a
    // natural card (when there is one) keeps the search small: any set
    // holding it can only contain cards of its suit, cards of its rank, or
    // wild cards, so only those "partners" are worth combining with it.
    final firstIndex = remaining.indexWhere((c) => !jokers.isWild(c));
    final first = remaining[firstIndex < 0 ? 0 : firstIndex];
    final rest = [...remaining]..remove(first);
    final partners = <PlayingCard>[];
    final others = <PlayingCard>[];
    for (final card in rest) {
      final canJoin =
          firstIndex < 0 ||
          jokers.isWild(card) ||
          card.suit == first.suit ||
          card.rank == first.rank;
      if (canJoin) {
        partners.add(card);
      } else {
        others.add(card);
      }
    }

    // Try every set made of the first card plus 2 or more partners.
    for (var mask = 1; mask < 1 << partners.length; mask++) {
      final set = [first];
      final left = [...others];
      for (var i = 0; i < partners.length; i++) {
        // Bit i of the mask says whether partners[i] joins the set.
        if (mask & (1 << i) != 0) {
          set.add(partners[i]);
        } else {
          left.add(partners[i]);
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

/// Whether [remaining], the cards a player who showed by [route] holds
/// after their final discard, finish the round: with pure sets shown, they
/// all split into sets ([canSplitIntoSets]); with doublees shown, they hold
/// an 8th doublee ([containsDoubleeWithJokers]).
///
/// The one win check: the engine, the bots, the Win button and the
/// to-win badge all use it, so they can never disagree.
bool isWinningHand(
  List<PlayingCard> remaining,
  ShowKind route,
  Jokers jokers,
) => switch (route) {
  ShowKind.pureSets => canSplitIntoSets(remaining, jokers),
  ShowKind.doublees => containsDoubleeWithJokers(remaining, jokers),
};

/// The cards [hand] could discard now to finish the round, each listed
/// once: those that leave an [isWinningHand]. Empty unless the player has
/// drawn, shown and seen the [jokers]. [mustKeep], a card taken from the
/// discard pile this turn, can't be discarded, so is never one.
List<PlayingCard> winningDiscards(
  PlayerHand hand,
  Jokers jokers, {
  PlayingCard? mustKeep,
}) {
  final route = hand.showKind;
  if (route == null || !hand.hasSeenJoker || !hand.hasDrawn) return const [];
  final cards = hand.cards;
  return [
    for (final card in cards.toSet())
      if (card != mustKeep &&
          isWinningHand([...cards]..remove(card), route, jokers))
        card,
  ];
}

String _key(List<PlayingCard> cards) {
  final ids = cards.map(cardIndex).toList()..sort();
  return ids.join(',');
}
