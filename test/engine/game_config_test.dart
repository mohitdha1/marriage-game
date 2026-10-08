import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/game_config.dart';

void main() {
  group('GameConfig defaults', () {
    test('uses sensible defaults with no arguments', () {
      final config = GameConfig();

      expect(config.deckCount, 3);
      expect(config.cardsPerPlayer, 21);
      expect(config.playerCount, 5);
      expect(config.murderEnabled, isFalse);
      expect(config.kidnapEnabled, isFalse);
      expect(config.manCardsEnabled, isFalse);
      expect(config.supermanCardEnabled, isFalse);
      expect(config.jokerDiscardPenaltyEnabled, isTrue);
    });

    test('every field can be overridden', () {
      final config = GameConfig(
        deckCount: 2,
        cardsPerPlayer: 13,
        playerCount: 3,
        murderEnabled: true,
        kidnapEnabled: true,
        manCardsEnabled: true,
        supermanCardEnabled: true,
        jokerDiscardPenaltyEnabled: false,
      );

      expect(config.deckCount, 2);
      expect(config.cardsPerPlayer, 13);
      expect(config.playerCount, 3);
      expect(config.murderEnabled, isTrue);
      expect(config.kidnapEnabled, isTrue);
      expect(config.manCardsEnabled, isTrue);
      expect(config.supermanCardEnabled, isTrue);
      expect(config.jokerDiscardPenaltyEnabled, isFalse);
    });
  });

  group('GameConfig playerCount validation', () {
    test('2 players (the minimum) is allowed', () {
      expect(() => GameConfig(playerCount: 2), returnsNormally);
    });

    test('5 players (the maximum) is allowed', () {
      expect(() => GameConfig(playerCount: 5), returnsNormally);
    });

    test('fewer than 2 players throws', () {
      expect(() => GameConfig(playerCount: 1), throwsArgumentError);
    });

    test('more than 5 players throws', () {
      expect(() => GameConfig(playerCount: 6), throwsArgumentError);
    });
  });
}
