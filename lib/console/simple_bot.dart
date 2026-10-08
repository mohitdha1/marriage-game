import 'dart:math';

import '../engine/card.dart';
import '../engine/joker.dart';
import '../engine/melds.dart';
import '../engine/round.dart';
import '../engine/win_check.dart';

/// What a bot did on its turn, for the console to report. Bots' hands stay
/// hidden; only public actions are described.
class BotTurn {
  BotTurn({
    required this.drewFrom,
    required this.drawn,
    this.shown = const [],
    this.pickedTiplu = false,
    this.discarded,
    this.won = false,
  });

  final DrawSource drewFrom;

  /// The card drawn. Only public when [drewFrom] is the discard pile.
  final PlayingCard drawn;
  final List<List<PlayingCard>> shown;
  final bool pickedTiplu;
  final PlayingCard? discarded;
  final bool won;
}

/// A deliberately simple placeholder bot for the console game; the real
/// bots (with difficulty levels) come in Phase 2.
///
/// It shows as soon as it holds the pure sets it needs, wins whenever its
/// hand allows, and otherwise discards the card with the fewest useful
/// neighbours. It never goes for the dublee route.
class SimpleBot {
  SimpleBot(this._random);

  final Random _random;

  /// Every tunnella in [cards], up to 3 — the opening show.
  List<List<PlayingCard>> openingTunnellas(List<PlayingCard> cards) =>
      findTunnellas(cards).take(3).toList();

  /// Plays the whole of the current player's turn in [round].
  BotTurn takeTurn(Round round) {
    final seat = round.currentSeat;
    final hand = round.hands[seat];

    final top = round.topDiscard;
    final source =
        top != null && _usefulness(top, hand.cards, round.jokersFor(seat)) >= 2
        ? DrawSource.discardPile
        : DrawSource.stock;
    final drawn = round.draw(source);
    final mustKeep = source == DrawSource.discardPile ? drawn : null;

    var shown = <List<PlayingCard>>[];
    var pickedTiplu = false;
    if (!hand.hasSeenJoker) {
      final sets = findPureSets(hand.cards, hand.pureSetsStillNeeded);
      if (sets != null) {
        pickedTiplu = !round.isJokerChosen;
        round.showPureSets(
          sets,
          tipluPosition: pickedTiplu ? _pickTipluPosition(round) : null,
        );
        shown = sets;
      }
    }

    final jokers = round.jokersFor(seat);
    if (jokers != null) {
      for (final card in hand.cards.toSet()) {
        if (card == mustKeep) continue;
        final remaining = [...hand.cards]..remove(card);
        if (canSplitIntoSets(remaining, jokers)) {
          round.declareWin(card);
          return BotTurn(
            drewFrom: source,
            drawn: drawn,
            shown: shown,
            pickedTiplu: pickedTiplu,
            discarded: card,
            won: true,
          );
        }
      }
    }

    final discard = chooseDiscard(hand.cards, jokers, mustKeep: mustKeep);
    round.discard(discard);
    return BotTurn(
      drewFrom: source,
      drawn: drawn,
      shown: shown,
      pickedTiplu: pickedTiplu,
      discarded: discard,
    );
  }

  /// The least useful card in [cards], never [mustKeep] (a card just taken
  /// from the discard pile). Ties go to the highest-ranked card.
  PlayingCard chooseDiscard(
    List<PlayingCard> cards,
    Jokers? jokers, {
    PlayingCard? mustKeep,
  }) {
    final candidates = cards.where((card) => card != mustKeep).toList()
      ..sort((a, b) => b.rank.order.compareTo(a.rank.order));
    int scoreOf(PlayingCard card) =>
        _usefulness(card, [...cards]..remove(card), jokers);
    var best = candidates.first;
    var bestScore = scoreOf(best);
    for (final card in candidates.skip(1)) {
      final score = scoreOf(card);
      if (score < bestScore) {
        best = card;
        bestScore = score;
      }
    }
    return best;
  }

  /// Any stock position. If the stock is empty, the round refills it from
  /// the discards before taking the tiplu, so position 0 is safe.
  int _pickTipluPosition(Round round) =>
      round.stockCount == 0 ? 0 : _random.nextInt(round.stockCount);

  /// Finds [count] separate pure sets (3-card pure sequences or tunnellas)
  /// in [cards], or `null` if there aren't that many.
  static List<List<PlayingCard>>? findPureSets(
    List<PlayingCard> cards,
    int count,
  ) {
    final candidates = _pureSetCandidates(cards);
    final available = _countCopies(cards);

    List<List<PlayingCard>>? pick(int from, int needed) {
      if (needed == 0) return [];
      for (var i = from; i < candidates.length; i++) {
        final set = candidates[i];
        if (!_takeAll(available, set)) continue;
        final rest = pick(i, needed - 1);
        if (rest != null) return [set, ...rest];
        _returnAll(available, set);
      }
      return null;
    }

    return pick(0, count);
  }

  /// Every distinct 3-card pure sequence and tunnella that [cards] could
  /// make, ignoring overlaps between them.
  static List<List<PlayingCard>> _pureSetCandidates(List<PlayingCard> cards) {
    final copies = _countCopies(cards);
    final sets = <List<PlayingCard>>[
      for (final MapEntry(key: card, value: n) in copies.entries)
        if (n >= 3) [card, card, card],
    ];
    for (final suit in Suit.values) {
      // Ace low (A-2-3) first, then every run up to Q-K-A.
      final runStarts = [
        [Rank.ace, Rank.two, Rank.three],
        for (var i = 0; i + 2 < Rank.values.length; i++)
          Rank.values.sublist(i, i + 3),
      ];
      for (final ranks in runStarts) {
        final run = [for (final rank in ranks) PlayingCard(suit, rank)];
        if (run.every(copies.containsKey) && isPureSequence(run)) {
          sets.add(run);
        }
      }
    }
    return sets;
  }

  /// How likely [card] is to end up in a set alongside [others]: identical
  /// copies and close same-suit cards always help. Same-rank cards only help
  /// once the joker is seen, because trials don't count toward the show.
  /// Wild cards are always kept.
  static int _usefulness(
    PlayingCard card,
    List<PlayingCard> others,
    Jokers? jokers,
  ) {
    if (jokers != null && jokers.isWild(card)) return 100;

    var score = 0;
    for (final other in others) {
      if (other == card) {
        score += 2;
      } else if (other.suit == card.suit) {
        final gap = _rankGap(card.rank, other.rank);
        if (gap == 1) score += 2;
        if (gap == 2) score += 1;
      } else if (jokers != null && other.rank == card.rank) {
        score += 1;
      }
    }
    return score;
  }

  /// Distance between two ranks, letting the ace sit next to the two.
  static int _rankGap(Rank a, Rank b) {
    final high = (a.order - b.order).abs();
    int low(Rank r) => r == Rank.ace ? 1 : r.order;
    return min(high, (low(a) - low(b)).abs());
  }
}

Map<PlayingCard, int> _countCopies(List<PlayingCard> cards) {
  final copies = <PlayingCard, int>{};
  for (final card in cards) {
    copies[card] = (copies[card] ?? 0) + 1;
  }
  return copies;
}

bool _takeAll(Map<PlayingCard, int> available, List<PlayingCard> set) {
  final needed = _countCopies(set);
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
