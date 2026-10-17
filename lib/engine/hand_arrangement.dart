import 'dart:math';

import 'card.dart';
import 'joker.dart';
import 'melds.dart';
import 'player_hand.dart';
import 'scoring.dart';
import 'win_check.dart';

/// How many copies of each card [cards] holds.
Map<PlayingCard, int> countCopies(Iterable<PlayingCard> cards) {
  final copies = <PlayingCard, int>{};
  for (final card in cards) {
    copies[card] = (copies[card] ?? 0) + 1;
  }
  return copies;
}

/// Every way to pick [count] separate pure sets (3-card pure sequences or
/// tunnellas, the Superman standing in for a card of one) from [cards]. Empty if there aren't that many.
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

/// The most separate pure sets (pure sequences or tunnellas) that [cards]
/// can make at once — what counts toward showing to see the joker.
///
/// Only 3-card pure sets are tried: a longer run contains a 3-card one, and
/// can't make more separate sets than its 3-card pieces would.
int maxPureSets(List<PlayingCard> cards) {
  final candidates = _pureSetCandidates(cards);
  final available = countCopies(cards);
  var best = 0;

  void search(int from, int found) {
    best = max(best, found);
    for (var i = from; i < candidates.length; i++) {
      final set = candidates[i];
      if (!_takeAll(available, set)) continue;
      search(i, found + 1);
      _returnAll(available, set);
    }
  }

  search(0, 0);
  return best;
}

/// Up to [count] separate doublees (pairs of identical cards) in [cards], or
/// `null` if there are fewer than [count].
List<List<PlayingCard>>? findDoublees(List<PlayingCard> cards, int count) {
  final pairs = _allDoublees(cards);
  return pairs.length < count ? null : pairs.take(count).toList();
}

/// How many separate doublees (pairs of identical cards) [cards] holds.
int countDoublees(List<PlayingCard> cards) => _allDoublees(cards).length;

/// Man cards never pair (see [isDoublee]). The Superman pairs with a card
/// left over from the real pairs, if there is one (see [isShowDoublee]).
List<List<PlayingCard>> _allDoublees(List<PlayingCard> cards) {
  final copies = countCopies(cards);
  final pairs = [
    for (final MapEntry(key: card, value: n) in copies.entries)
      if (!card.isPrinted)
        for (var i = 0; i < n ~/ 2; i++) [card, card],
  ];
  if (copies.containsKey(const PlayingCard.superman())) {
    final leftovers = [
      for (final MapEntry(key: card, value: n) in copies.entries)
        if (card.isMan || (!card.isPrinted && n.isOdd)) card,
    ]..sort((a, b) => a.isMan == b.isMan ? 0 : (a.isMan ? 1 : -1));
    if (leftovers.isNotEmpty) {
      pairs.add([const PlayingCard.superman(), leftovers.first]);
    }
  }
  return pairs;
}

/// The best way to arrange [cards] into separate sets: the one covering the
/// most cards, and of those, the one with the most sets.
///
/// Before the joker is seen ([jokers] is `null`) only the pure sets a show
/// accepts count (see [isShowPureSet]), since those are all a player can
/// use. Afterwards, any
/// set that can finish a hand counts, jokers included (see
/// [isFinishingSet]). Sets longer than [maxSetSize] aren't tried, which keeps
/// the search fast and loses nothing: a long run still counts through its
/// shorter pieces.
List<List<PlayingCard>> bestArrangement(
  List<PlayingCard> cards,
  Jokers? jokers, {
  int maxSetSize = 5,
}) {
  bool isSet(List<PlayingCard> set) =>
      jokers == null ? isShowPureSet(set) : isFinishingSet(set, jokers);
  bool isWild(PlayingCard card) =>
      card.isSuperman || (jokers?.isWild(card) ?? false);
  int covered(List<List<PlayingCard>> sets) =>
      sets.fold(0, (total, set) => total + set.length);
  bool better(List<List<PlayingCard>> a, List<List<PlayingCard>> b) {
    final byCards = covered(a) - covered(b);
    return byCards != 0 ? byCards > 0 : a.length > b.length;
  }

  final known = <String, List<List<PlayingCard>>>{};

  List<List<PlayingCard>> best(List<PlayingCard> remaining) {
    if (remaining.length < 3) return const [];
    final key = _key(remaining);
    final cached = known[key];
    if (cached != null) return cached;

    // Either the first card stays out of every set, or it joins a set with
    // some of its possible partners: cards of its suit, cards of its rank,
    // or wild cards (no other card can share a set with it).
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
      if (!isSet(set)) continue;
      final candidate = [set, ...best(left)];
      if (better(candidate, result)) result = candidate;
    }

    known[key] = result;
    return result;
  }

  return best(cards);
}

/// The most cards in [cards] that can be covered by separate sets at once —
/// a measure of how close a hand is to finishing. See [bestArrangement].
int maxCoverage(
  List<PlayingCard> cards,
  Jokers? jokers, {
  int maxSetSize = 5,
}) => bestArrangement(
  cards,
  jokers,
  maxSetSize: maxSetSize,
).fold(0, (total, set) => total + set.length);

/// How far a player's hand has come, as a hand helper would show it. Which
/// kind depends on where they are in the round.
sealed class HandProgress {
  const HandProgress();
}

/// Before seeing the joker: progress toward the show that reveals it, by
/// either route.
class ShowProgress extends HandProgress {
  const ShowProgress({
    required this.pureSets,
    required this.pureSetsNeeded,
    required this.doublees,
  });

  /// The most separate pure sets the hand can make right now.
  final int pureSets;

  /// How many pure sets the show needs, after counting opening tunnellas.
  final int pureSetsNeeded;

  /// How many doublees the hand holds.
  final int doublees;

  int get doubleesNeeded => PlayerHand.doubleesToShow;
}

/// After seeing the joker by showing pure sets: progress toward winning.
class WinProgress extends HandProgress {
  const WinProgress({
    required this.setsMade,
    required this.unmatched,
    required this.setsToWin,
    required this.maal,
  });

  /// Sets already laid down, plus the sets in the best arrangement of the
  /// cards still held.
  final int setsMade;

  /// Cards held that fit into no set in that arrangement. One unmatched card
  /// after drawing means the hand can win by discarding it.
  final int unmatched;

  /// How many more 3-card sets the unmatched cards still need to form, not
  /// counting the card about to be discarded: the unmatched cards divided by
  /// 3, rounded up. 0 exactly when the hand can win this turn.
  final int setsToWin;

  /// The hand's maal points right now.
  final int maal;
}

/// After seeing the joker by showing doublees: progress toward the 8th
/// doublee that wins.
class DubleeProgress extends HandProgress {
  const DubleeProgress({required this.doublees, required this.maal});

  /// Doublees made: the 7 shown, plus 1 if the cards held already include
  /// an 8th (jokers can pair with anything).
  final int doublees;

  final int maal;

  int get doubleesNeeded => PlayerHand.doubleesToShow + 1;

  /// 1 until the 8th doublee is made, then 0: the hand can win this turn.
  int get doubleesToWin => doublees >= doubleesNeeded ? 0 : 1;
}

/// How far [hand] has come, given the round's [jokers] (`null` until the
/// player has seen them). [alterIsMaal] works as in [scoreMaal].
HandProgress handProgress(
  PlayerHand hand,
  Jokers? jokers, {
  bool alterIsMaal = true,
}) {
  final cards = hand.cards;
  if (jokers == null || !hand.hasSeenJoker) {
    return ShowProgress(
      pureSets: maxPureSets(cards),
      pureSetsNeeded: hand.pureSetsStillNeeded,
      doublees: countDoublees(cards),
    );
  }

  final maal = scoreMaal(hand, jokers, alterIsMaal: alterIsMaal).total;
  if (hand.showKind == ShowKind.doublees) {
    return DubleeProgress(
      doublees:
          hand.shownSets.length +
          (containsDoubleeWithJokers(cards, jokers) ? 1 : 0),
      maal: maal,
    );
  }

  final arrangement = bestArrangement(cards, jokers);
  final inSets = arrangement.fold(0, (total, set) => total + set.length);
  final unmatched = cards.length - inSets;
  return WinProgress(
    setsMade:
        hand.openingTunnellas.length +
        hand.shownSets.length +
        arrangement.length,
    unmatched: unmatched,
    setsToWin: _setsToWin(hand, jokers, unmatched),
    maal: maal,
  );
}

/// See [WinProgress.setsToWin]. Before drawing, a hand whose cards are all
/// in sets wins by discarding whatever it draws. After drawing, one card
/// goes out with the discard, and 0 is confirmed by trying each discard,
/// since a hand with every card in sets may have none it can spare.
int _setsToWin(PlayerHand hand, Jokers jokers, int unmatched) {
  final cards = hand.cards;
  if (!hand.hasDrawn) return (unmatched + 2) ~/ 3;
  if (unmatched <= 1) {
    for (var i = 0; i < cards.length; i++) {
      if (canSplitIntoSets([...cards.take(i), ...cards.skip(i + 1)], jokers)) {
        return 0;
      }
    }
  }
  return max(1, (unmatched - 1 + 2) ~/ 3);
}

/// Every distinct 3-card pure sequence and tunnella that [cards] could
/// make, ignoring overlaps between them; with the Superman, also each one
/// it could complete.
List<List<PlayingCard>> _pureSetCandidates(List<PlayingCard> cards) {
  final copies = countCopies(cards);
  const superman = PlayingCard.superman();
  final hasSuperman = copies.containsKey(superman);
  final sets = <List<PlayingCard>>[
    ...findTunnellas(cards).where(isTunnella),
    if (hasSuperman)
      for (final MapEntry(key: card, value: n) in copies.entries)
        if (!card.isPrinted && n >= 2) [card, card, superman],
  ];
  for (final suit in Suit.values) {
    // Ace low (A-2-3) first, then every run up to Q-K-A.
    final runs = [
      [Rank.ace, Rank.two, Rank.three],
      for (var i = 0; i + 2 < Rank.values.length; i++)
        Rank.values.sublist(i, i + 3),
    ];
    for (final ranks in runs) {
      final run = [for (final rank in ranks) PlayingCard(suit, rank)];
      final missing = run.where((c) => !copies.containsKey(c)).toList();
      if (missing.isEmpty) {
        sets.add(run);
      } else if (hasSuperman && missing.length == 1) {
        sets.add([
          for (final card in run) card == missing.single ? superman : card,
        ]);
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

int _bitCount(int n) {
  var count = 0;
  for (var m = n; m != 0; m &= m - 1) {
    count++;
  }
  return count;
}

String _key(List<PlayingCard> cards) {
  final ids = cards.map(cardIndex).toList()..sort();
  return ids.join(',');
}
