import 'dart:math';

import '../engine/card.dart';
import '../engine/hand_arrangement.dart';
import '../engine/joker.dart';
import '../engine/melds.dart';
import '../engine/player_hand.dart';
import '../engine/round.dart';
import 'bot_personality.dart';
import 'hand_analysis.dart';
import 'table_memory.dart';

/// How well a bot plays.
enum BotDifficulty {
  /// Mostly legal, often careless: draws blind, sometimes throws away good
  /// cards (jokers included), and occasionally misses a win.
  easy,

  /// Solid: never breaks a finished pure set, keeps its jokers, takes
  /// useful discards, throws its highest deadwood first, and never misses a
  /// win.
  medium,

  /// Careful: plays like Medium, but also counts which cards are gone, avoids
  /// discarding what the next player has been collecting, chooses which
  /// sets to show to keep its hand flexible, and plays for doublees when
  /// the hand suits them better than pure sets.
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

  /// How many doublees a Hard bot needs, with few pure sets, before it
  /// plays for doublees instead.
  static const dubleeRouteAt = 4;

  /// Every tunnella in [cards], up to 3 — the opening show.
  List<List<PlayingCard>> openingTunnellas(List<PlayingCard> cards) =>
      findTunnellas(cards).take(PlayerHand.maxOpeningTunnellas).toList();

  /// Plays the whole of the current player's turn in [round]: draw, show
  /// if it can, then win or discard. The first to show picks the tiplu
  /// after that discard. A turn with a show never wins; the earliest win
  /// is the next turn.
  BotTurn takeTurn(Round round) {
    final seat = round.currentSeat;
    final hand = round.hands[seat];
    final memory = difficulty == BotDifficulty.hard
        ? TableMemory.read(round, seat)
        : null;
    final forDoublees = playsForDoublees(hand);
    _pickTipluAgain(round);

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
      source = _chooseDrawSource(round, seat, memory, forDoublees);
      drawn = round.draw(source);
      mustKeep = source == DrawSource.discardPile ? drawn : null;
    }

    var shown = <List<PlayingCard>>[];
    if (!hand.hasShown) {
      final show = _chooseShow(hand, forDoublees);
      if (show != null) {
        if (show.doublees) {
          round.showDoublees(show.sets);
        } else {
          round.showPureSets(show.sets);
        }
        shown = show.sets;
      }
    }

    final winning = round.currentWinningDiscards;
    // An Easy bot sometimes doesn't notice it could win, and breaks up its
    // hand with a card that doesn't.
    final missesWin =
        winning.isNotEmpty &&
        difficulty == BotDifficulty.easy &&
        _random.nextDouble() < _easyMissedWin &&
        hand.cards.any((card) => card != mustKeep && !winning.contains(card));
    final winningCard = missesWin ? null : winning.firstOrNull;
    if (winningCard != null) {
      round.declareWin(winningCard);
      return BotTurn(
        drewFrom: source,
        drawn: drawn,
        shown: shown,
        discarded: winningCard,
        won: true,
      );
    }

    final discard = chooseDiscard(
      [
        for (final card in hand.cards)
          if (!winning.contains(card)) card,
      ],
      round.jokersFor(seat),
      mustKeep: mustKeep,
      memory: memory,
      keepPairs: forDoublees,
      shown: hand.hasShown,
    );
    round.discard(discard);
    // The first to show sees the joker with that discard, and picks it.
    final pickedTiplu = round.needsTipluPick;
    _pickTipluAgain(round);
    return BotTurn(
      drewFrom: source,
      drawn: drawn,
      shown: shown,
      pickedTiplu: pickedTiplu,
      discarded: discard,
    );
  }

  /// The card to throw away from [cards], never [mustKeep] (a card just
  /// taken from the discard pile). [shown] says the player has shown, so
  /// natural trials count as sets even before the joker is seen. Ties go
  /// to the highest-ranked card.
  PlayingCard chooseDiscard(
    List<PlayingCard> cards,
    Jokers? jokers, {
    PlayingCard? mustKeep,
    TableMemory? memory,
    bool keepPairs = false,
    bool shown = false,
  }) {
    var candidates = cards.where((card) => card != mustKeep).toList()
      ..sort((a, b) => (b.rank?.order ?? 0).compareTo(a.rank?.order ?? 0));

    if (difficulty == BotDifficulty.easy &&
        _random.nextDouble() < _easyCarelessDiscard) {
      return candidates[_random.nextInt(candidates.length)];
    }

    // Having shown, but before the joker comes with this discard, a Medium
    // or Hard bot keeps the natural sets that will finish its hand.
    if (shown && jokers == null && difficulty != BotDifficulty.easy) {
      int coverage(PlayingCard card) =>
          maxCoverage([...cards]..remove(card), null, shown: true);
      final most = candidates.map(coverage).reduce(max);
      candidates = [
        for (final card in candidates)
          if (coverage(card) == most) card,
      ];
    }

    // A Medium bot never breaks up a finished pure set while it has other
    // cards to throw.
    if (difficulty == BotDifficulty.medium) {
      final sets = maxPureSets(cards);
      final spare = [
        for (final card in candidates)
          if (maxPureSets([...cards]..remove(card)) == sets) card,
      ];
      if (spare.isNotEmpty) candidates = spare;
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

    // A bot playing for doublees throws a single card while it has one.
    if (keepPairs) {
      final copies = countCopies(cards);
      final singles = [
        for (final card in candidates)
          if (copies[card] == 1 &&
              !card.isSuperman &&
              !(jokers?.isWild(card) ?? false))
            card,
      ];
      if (singles.isNotEmpty) candidates = singles;
    }

    // A Hard bot first keeps whatever leaves the most cards in sets; the
    // usual cost only breaks ties.
    int coverageWithout(PlayingCard card) =>
        difficulty == BotDifficulty.hard && !keepPairs
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

  /// Whether a Hard bot plays [hand] for doublees: once it has shown them,
  /// or while it hasn't seen the joker and holds at least [dubleeRouteAt]
  /// doublees but is further from its pure sets.
  bool playsForDoublees(PlayerHand hand) {
    if (difficulty != BotDifficulty.hard) return false;
    if (hand.showKind == ShowKind.doublees) return true;
    if (hand.hasShown) return false;
    final pairs = countDoublees(hand.cards);
    return pairs >= dubleeRouteAt &&
        PlayerHand.doubleesToShow - pairs <
            2 * (hand.pureSetsStillNeeded - maxPureSets(hand.cards));
  }

  DrawSource _chooseDrawSource(
    Round round,
    int seat,
    TableMemory? memory,
    bool forDoublees,
  ) {
    final top = round.topDiscard;
    if (top == null) return DrawSource.stock;

    // Playing for doublees, a discard is worth taking if it makes a pair.
    if (forDoublees) {
      final cards = round.hands[seat].cards;
      return cards.where((card) => card == top).length == 1
          ? DrawSource.discardPile
          : DrawSource.stock;
    }

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
    bool forDoublees,
  ) {
    final cards = hand.cards;
    if (forDoublees) {
      final pairs = findDoublees(cards, PlayerHand.doubleesToShow);
      if (pairs != null) return (sets: pairs, doublees: true);
    }
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

  /// Picks again for as long as the picks are printed jokers, which are
  /// kept aside.
  void _pickTipluAgain(Round round) {
    while (round.needsTipluPick) {
      round.pickTiplu(_pickTipluPosition(round));
    }
  }

  /// Any stock position. If the stock is empty, the round refills it from
  /// the discards before taking the tiplu, so position 0 is safe.
  int _pickTipluPosition(Round round) =>
      round.stockCount == 0 ? 0 : _random.nextInt(round.stockCount);
}
