import 'dart:math';

import '../engine/card.dart';
import '../engine/hand_arrangement.dart';
import '../engine/joker.dart';
import '../engine/melds.dart';
import '../engine/player_hand.dart';
import '../engine/round.dart';
import '../engine/win_check.dart';
import 'bot_personality.dart';
import 'hand_analysis.dart';
import 'table_memory.dart';

/// How well a bot plays.
enum BotDifficulty {
  /// Mostly legal, often careless: draws blind, sometimes throws away good
  /// cards (jokers included), and occasionally misses a win.
  easy,

  /// Solid: keeps its sets and jokers, takes useful discards, discards the
  /// card least likely to fit, and never misses a win.
  medium,

  /// Careful: plays like Medium, but also counts which cards are gone, avoids
  /// discarding what the next player has been collecting, and chooses which
  /// sets to show to keep its hand flexible.
  hard,
}

/// What a bot did on its turn, for the table to report. Only public actions
/// are described; the bot's hand stays hidden.
class BotTurn {
  const BotTurn({
    required this.drewFrom,
    required this.drawn,
    this.shown = const [],
    this.pickedTiplu = false,
    this.discarded,
    this.won = false,
  });

  /// Where the bot drew from, or `null` if the turn was already under way
  /// when the bot took it over (the player had drawn before leaving).
  final DrawSource? drewFrom;

  /// The card drawn. Only public when [drewFrom] is the discard pile.
  final PlayingCard? drawn;
  final List<List<PlayingCard>> shown;
  final bool pickedTiplu;
  final PlayingCard? discarded;
  final bool won;
}

/// A computer player: plays whole turns of a [Round] at its [difficulty],
/// flavoured by its [personality].
class BotPlayer {
  BotPlayer({
    required this.difficulty,
    required this.personality,
    required Random random,
  }) : _random = random;

  final BotDifficulty difficulty;
  final BotPersonality personality;
  final Random _random;

  /// Chance an Easy bot ignores its hand and discards at random.
  static const _easyCarelessDiscard = 0.35;

  /// Chance an Easy bot takes the top discard without thinking.
  static const _easyBlindPickup = 0.15;

  /// Chance an Easy bot doesn't notice it could win this turn.
  static const _easyMissedWin = 0.25;

  /// Every tunnella in [cards], up to 3 — the opening show.
  List<List<PlayingCard>> openingTunnellas(List<PlayingCard> cards) =>
      findTunnellas(cards).take(PlayerHand.maxOpeningTunnellas).toList();

  /// Plays the whole of the current player's turn in [round]: draw, show
  /// if it can, then win or discard.
  BotTurn takeTurn(Round round) {
    final seat = round.currentSeat;
    final hand = round.hands[seat];
    final memory = difficulty == BotDifficulty.hard
        ? TableMemory.read(round, seat)
        : null;

    // A turn may already be under way: a player who left after drawing,
    // whose seat a bot has taken over. It finishes the turn from there.
    final DrawSource? source;
    final PlayingCard? drawn;
    final PlayingCard? mustKeep;
    if (hand.hasDrawn) {
      source = null;
      drawn = null;
      mustKeep = round.takenFromDiscardPile;
    } else {
      source = _chooseDrawSource(round, seat, memory);
      drawn = round.draw(source);
      mustKeep = source == DrawSource.discardPile ? drawn : null;
    }

    var shown = <List<PlayingCard>>[];
    var pickedTiplu = false;
    if (!hand.hasSeenJoker) {
      final show = _chooseShow(hand);
      if (show != null) {
        pickedTiplu = !round.isJokerChosen;
        final position = pickedTiplu ? _pickTipluPosition(round) : null;
        if (show.doublees) {
          round.showDoublees(show.sets, tipluPosition: position);
        } else {
          round.showPureSets(show.sets, tipluPosition: position);
        }
        shown = show.sets;
      }
    }

    final winningCard = _findWinningDiscard(round, seat, mustKeep);
    if (winningCard != null) {
      round.declareWin(winningCard);
      return BotTurn(
        drewFrom: source,
        drawn: drawn,
        shown: shown,
        pickedTiplu: pickedTiplu,
        discarded: winningCard,
        won: true,
      );
    }

    final discard = chooseDiscard(
      hand.cards,
      round.jokersFor(seat),
      mustKeep: mustKeep,
      memory: memory,
    );
    round.discard(discard);
    return BotTurn(
      drewFrom: source,
      drawn: drawn,
      shown: shown,
      pickedTiplu: pickedTiplu,
      discarded: discard,
    );
  }

  /// The card to throw away from [cards], never [mustKeep] (a card just
  /// taken from the discard pile). Ties go to the highest-ranked card.
  PlayingCard chooseDiscard(
    List<PlayingCard> cards,
    Jokers? jokers, {
    PlayingCard? mustKeep,
    TableMemory? memory,
  }) {
    final candidates = cards.where((card) => card != mustKeep).toList()
      ..sort((a, b) => b.rank.order.compareTo(a.rank.order));

    if (difficulty == BotDifficulty.easy &&
        _random.nextDouble() < _easyCarelessDiscard) {
      return candidates[_random.nextInt(candidates.length)];
    }

    double cost(PlayingCard card) {
      final others = [...cards]..remove(card);
      final value = usefulness(
        card,
        others,
        // An Easy bot doesn't keep track of which cards are jokers.
        difficulty == BotDifficulty.easy ? null : jokers,
        stillAvailable: memory?.stillAvailable,
        pairBonus: personality.pairBonus,
      );
      final danger = memory == null
          ? 0.0
          : memory.danger(card) * personality.caution;
      return value + danger;
    }

    // A Hard bot first keeps whatever leaves the most cards in sets; the
    // usual cost only breaks ties.
    int coverageWithout(PlayingCard card) => difficulty == BotDifficulty.hard
        ? maxCoverage([...cards]..remove(card), jokers)
        : 0;

    var best = candidates.first;
    var bestCoverage = coverageWithout(best);
    var bestCost = cost(best);
    for (final card in candidates.skip(1)) {
      final coverage = coverageWithout(card);
      final c = cost(card);
      if (coverage > bestCoverage ||
          (coverage == bestCoverage && c < bestCost)) {
        best = card;
        bestCoverage = coverage;
        bestCost = c;
      }
    }
    return best;
  }

  DrawSource _chooseDrawSource(Round round, int seat, TableMemory? memory) {
    final top = round.topDiscard;
    if (top == null) return DrawSource.stock;

    if (difficulty == BotDifficulty.easy) {
      return _random.nextDouble() < _easyBlindPickup
          ? DrawSource.discardPile
          : DrawSource.stock;
    }

    // A Hard bot takes the discard whenever it covers more of the hand.
    final cards = round.hands[seat].cards;
    final jokers = round.jokersFor(seat);
    if (difficulty == BotDifficulty.hard &&
        maxCoverage([...cards, top], jokers) > maxCoverage(cards, jokers)) {
      return DrawSource.discardPile;
    }

    final value = usefulness(
      top,
      round.hands[seat].cards,
      round.jokersFor(seat),
      stillAvailable: memory?.stillAvailable,
      pairBonus: personality.pairBonus,
    );
    return value >= personality.pickupThreshold
        ? DrawSource.discardPile
        : DrawSource.stock;
  }

  /// The sets to show to see the joker, or `null` if the hand can't show
  /// yet. Easy bots only look for pure sets; the others also try doublees.
  ({List<List<PlayingCard>> sets, bool doublees})? _chooseShow(
    PlayerHand hand,
  ) {
    final cards = hand.cards;
    final choices = allPureSetChoices(cards, hand.pureSetsStillNeeded);
    if (choices.isNotEmpty) {
      final sets = difficulty == BotDifficulty.hard
          ? _mostFlexibleChoice(cards, choices)
          : choices.first;
      return (sets: sets, doublees: false);
    }
    if (difficulty == BotDifficulty.easy) return null;
    final pairs = findDoublees(cards, PlayerHand.doubleesToShow);
    return pairs == null ? null : (sets: pairs, doublees: true);
  }

  /// Of several ways to show, the one that leaves the most useful hand.
  List<List<PlayingCard>> _mostFlexibleChoice(
    List<PlayingCard> cards,
    List<List<List<PlayingCard>>> choices,
  ) {
    int leftoverValue(List<List<PlayingCard>> choice) {
      final rest = [...cards];
      for (final card in choice.expand((set) => set)) {
        rest.remove(card);
      }
      var total = 0;
      for (var i = 0; i < rest.length; i++) {
        final others = [...rest]..removeAt(i);
        total += usefulness(rest[i], others, null);
      }
      return total;
    }

    var best = choices.first;
    var bestValue = leftoverValue(best);
    for (final choice in choices.skip(1)) {
      final value = leftoverValue(choice);
      if (value > bestValue) {
        best = choice;
        bestValue = value;
      }
    }
    return best;
  }

  PlayingCard? _findWinningDiscard(
    Round round,
    int seat,
    PlayingCard? mustKeep,
  ) {
    final hand = round.hands[seat];
    final jokers = round.jokersFor(seat);
    final route = hand.showKind;
    if (jokers == null || route == null) return null;
    if (difficulty == BotDifficulty.easy &&
        _random.nextDouble() < _easyMissedWin) {
      return null;
    }

    for (final card in hand.cards.toSet()) {
      if (card == mustKeep) continue;
      final rest = [...hand.cards]..remove(card);
      final wins = switch (route) {
        ShowKind.pureSets => canSplitIntoSets(rest, jokers),
        ShowKind.doublees => containsDoubleeWithJokers(rest, jokers),
      };
      if (wins) return card;
    }
    return null;
  }

  /// Any stock position. If the stock is empty, the round refills it from
  /// the discards before taking the tiplu, so position 0 is safe.
  int _pickTipluPosition(Round round) =>
      round.stockCount == 0 ? 0 : _random.nextInt(round.stockCount);
}
