import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/shoe.dart';

/// Counts how many copies of each suit+rank appear in [cards].
Map<PlayingCard, int> countCards(Iterable<PlayingCard> cards) {
  final counts = <PlayingCard, int>{};
  for (final card in cards) {
    counts[card] = (counts[card] ?? 0) + 1;
  }
  return counts;
}

void main() {
  group('Shoe creation', () {
    test('default config builds a 3-deck, 156-card shoe', () {
      final shoe = Shoe.fromConfig(GameConfig());

      expect(shoe.length, 156);
    });

    test('every suit+rank appears exactly deckCount times', () {
      for (final deckCount in [1, 2, 3]) {
        final shoe = Shoe(deckCount);
        final counts = countCards(shoe.cards);

        expect(counts.length, 52, reason: 'deckCount $deckCount');
        expect(
          counts.values.every((n) => n == deckCount),
          isTrue,
          reason: 'deckCount $deckCount',
        );
      }
    });

    test('uses deckCount from GameConfig', () {
      expect(Shoe.fromConfig(GameConfig(deckCount: 2)).length, 104);
    });

    test('fewer than 1 deck throws', () {
      expect(() => Shoe(0), throwsArgumentError);
    });

    test('cards view cannot be modified from outside', () {
      final shoe = Shoe(1);

      expect(() => shoe.cards.removeLast(), throwsUnsupportedError);
    });
  });

  group('fisherYatesShuffle', () {
    test('same seed produces the same order', () {
      final a = List.generate(52, (i) => i);
      final b = List.generate(52, (i) => i);

      fisherYatesShuffle(a, Random(42));
      fisherYatesShuffle(b, Random(42));

      expect(a, b);
    });

    test('different seeds produce different orders', () {
      final a = List.generate(52, (i) => i);
      final b = List.generate(52, (i) => i);

      fisherYatesShuffle(a, Random(1));
      fisherYatesShuffle(b, Random(2));

      expect(a, isNot(b));
    });

    test('keeps exactly the same elements', () {
      final items = List.generate(52, (i) => i);

      fisherYatesShuffle(items, Random(7));

      expect(items, isNot(List.generate(52, (i) => i)));
      expect(items.toSet(), List.generate(52, (i) => i).toSet());
      expect(items.length, 52);
    });

    test('handles empty and single-element lists', () {
      final empty = <int>[];
      final single = [1];

      fisherYatesShuffle(empty, Random(0));
      fisherYatesShuffle(single, Random(0));

      expect(empty, isEmpty);
      expect(single, [1]);
    });

    test('every permutation of 3 items is roughly equally likely', () {
      // A correct Fisher–Yates gives each of the 6 orderings ~1/6 of the
      // time. Common off-by-one bugs (e.g. nextInt(i) instead of
      // nextInt(i + 1)) make some orderings impossible or over-represented.
      const trials = 60000;
      final random = Random(123);
      final counts = <String, int>{};

      for (var t = 0; t < trials; t++) {
        final items = ['a', 'b', 'c'];
        fisherYatesShuffle(items, random);
        final key = items.join();
        counts[key] = (counts[key] ?? 0) + 1;
      }

      expect(counts.length, 6);
      for (final count in counts.values) {
        expect(count, closeTo(trials / 6, trials * 0.01));
      }
    });
  });

  group('Shoe.shuffle', () {
    test('same seed gives the same shoe order', () {
      final a = Shoe(3)..shuffle(Random(99));
      final b = Shoe(3)..shuffle(Random(99));

      expect(a.cards, b.cards);
    });

    test('changes the order but not the contents', () {
      final unshuffled = Shoe(3);
      final shuffled = Shoe(3)..shuffle(Random(5));

      expect(shuffled.cards, isNot(unshuffled.cards));
      expect(countCards(shuffled.cards), countCards(unshuffled.cards));
    });
  });

  group('Shoe.draw', () {
    test('returns the top (last) card and removes it', () {
      final shoe = Shoe(1)..shuffle(Random(3));
      final top = shoe.cards.last;

      expect(shoe.draw(), top);
      expect(shoe.length, 51);
    });

    test('drawing from an empty shoe throws', () {
      final shoe = Shoe(1);
      for (var i = 0; i < 52; i++) {
        shoe.draw();
      }

      expect(shoe.isEmpty, isTrue);
      expect(shoe.draw, throwsStateError);
    });
  });

  group('Shoe.deal', () {
    test('default config deals 5 hands of 21, leaving 51 in the stock', () {
      final config = GameConfig();
      final shoe = Shoe.fromConfig(config)..shuffle(Random(1));

      final hands = shoe.deal(config);

      expect(hands.length, 5);
      expect(hands.every((h) => h.length == 21), isTrue);
      expect(shoe.length, 156 - 5 * 21);
    });

    test('respects playerCount and cardsPerPlayer from GameConfig', () {
      final config = GameConfig(playerCount: 3, cardsPerPlayer: 13);
      final shoe = Shoe.fromConfig(config);

      final hands = shoe.deal(config);

      expect(hands.length, 3);
      expect(hands.every((h) => h.length == 13), isTrue);
      expect(shoe.length, 156 - 39);
    });

    test('deals one card at a time round the table', () {
      final config = GameConfig(playerCount: 4);
      final shoe = Shoe.fromConfig(config)..shuffle(Random(8));
      // Top of the shoe is the end of the list, so reverse to get draw order.
      final drawOrder = shoe.cards.reversed.toList();

      final hands = shoe.deal(config);

      for (var seat = 0; seat < 4; seat++) {
        final expected = [
          for (var round = 0; round < 21; round++) drawOrder[round * 4 + seat],
        ];
        expect(hands[seat], expected, reason: 'seat $seat');
      }
    });

    test('no cards are lost or duplicated: hands + stock = original shoe', () {
      final config = GameConfig();
      final shoe = Shoe.fromConfig(config)..shuffle(Random(11));
      final before = countCards(shoe.cards);

      final hands = shoe.deal(config);

      final after = countCards([...hands.expand((h) => h), ...shoe.cards]);
      expect(after, before);
    });

    test('same seed deals identical hands', () {
      final config = GameConfig();
      final a = (Shoe.fromConfig(config)..shuffle(Random(2024))).deal(config);
      final b = (Shoe.fromConfig(config)..shuffle(Random(2024))).deal(config);

      expect(a, b);
    });

    test('throws without dealing when the shoe is too small', () {
      // 1 deck = 52 cards, but 5 players x 21 needs 105.
      final config = GameConfig(deckCount: 1);
      final shoe = Shoe.fromConfig(config);

      expect(() => shoe.deal(config), throwsStateError);
      expect(shoe.length, 52);
    });
  });
}
