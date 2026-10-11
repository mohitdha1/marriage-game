import 'dart:math';

import 'card.dart';
import 'game_config.dart';

/// Shuffles [items] in place using the Fisher–Yates algorithm, which gives
/// every permutation an equal chance. Pass a seeded [Random] (for example
/// `Random(42)`) to get the same order every time — that's what makes
/// shuffle-dependent tests repeatable.
void fisherYatesShuffle<T>(List<T> items, Random random) {
  for (var i = items.length - 1; i > 0; i--) {
    // nextInt's upper bound is exclusive, so j is in [0, i] — including i
    // itself, which lets a card stay where it is.
    final j = random.nextInt(i + 1);
    final temp = items[i];
    items[i] = items[j];
    items[j] = temp;
  }
}

/// All the physical cards in play for a round: [deckCount] standard 52-card
/// decks mixed together, plus any man cards. Cards are drawn from the top,
/// which is the *end* of [cards] (so drawing is a cheap `removeLast`).
///
/// Jokers/maal aren't part of the shoe itself — the joker is picked by
/// flipping a card from the stock after dealing, which is a later step.
class Shoe {
  Shoe(int deckCount, {int manCards = 0})
    : _cards = [
        for (var deck = 0; deck < deckCount; deck++)
          for (final suit in Suit.values)
            for (final rank in Rank.values) PlayingCard(suit, rank),
        for (var i = 0; i < manCards; i++) const PlayingCard.man(),
      ] {
    if (deckCount < 1) {
      throw ArgumentError.value(deckCount, 'deckCount', 'must be at least 1');
    }
  }

  /// One man card per deck when [GameConfig.manCardsEnabled] is on.
  factory Shoe.fromConfig(GameConfig config) => Shoe(
    config.deckCount,
    manCards: config.manCardsEnabled ? config.deckCount : 0,
  );

  final List<PlayingCard> _cards;

  /// A read-only view of the cards still in the shoe, bottom first; the last
  /// element is the next card [draw] will return.
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  int get length => _cards.length;

  bool get isEmpty => _cards.isEmpty;

  /// Shuffles the shoe in place. Defaults to an unseeded [Random]; tests
  /// should inject a seeded one.
  void shuffle([Random? random]) {
    fisherYatesShuffle(_cards, random ?? Random());
  }

  /// Removes and returns the top card.
  PlayingCard draw() {
    if (_cards.isEmpty) {
      throw StateError('Cannot draw from an empty shoe');
    }
    return _cards.removeLast();
  }

  /// Deals [GameConfig.cardsPerPlayer] cards to each of
  /// [GameConfig.playerCount] players, one card at a time round the table
  /// (player 0, 1, 2, … then back to 0), the way cards are dealt by hand.
  /// Returns one hand per player, indexed by seat. Whatever is left in the
  /// shoe afterwards becomes the stock pile.
  ///
  /// Throws a [StateError] — without dealing anything — if the shoe doesn't
  /// hold enough cards for every hand.
  List<List<PlayingCard>> deal(GameConfig config) {
    final needed = config.playerCount * config.cardsPerPlayer;
    if (needed > _cards.length) {
      throw StateError(
        'Need $needed cards to deal ${config.cardsPerPlayer} each to '
        '${config.playerCount} players, but the shoe only has ${_cards.length}',
      );
    }

    final hands = List.generate(config.playerCount, (_) => <PlayingCard>[]);
    for (var round = 0; round < config.cardsPerPlayer; round++) {
      for (final hand in hands) {
        hand.add(draw());
      }
    }
    return hands;
  }
}
