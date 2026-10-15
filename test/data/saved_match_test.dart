import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/data/saved_match.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/round_log.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/net/wire.dart' show Json, cardToJson;
import 'package:marriage_game/ui/settings/preferences.dart';

import '../engine/round_log_test.dart' show dealt, describe, playOn;

/// A match against Hard bots at the 50 table, saved after [turns] turns of
/// its second round.
SavedMatch savedMatch({int turns = 25, GameConfig? config}) {
  config ??= GameConfig(
    playerCount: 4,
    mode: GameMode.kidnap,
    manCardsEnabled: true,
    supermanCardEnabled: true,
    alterIsMaal: false,
  );
  final first = dealt(1, config: config);
  playOn(first, Random(1));
  final round = dealt(2, config: config);
  playOn(round, Random(2), turns: turns);
  return SavedMatch(
    config: config,
    difficulty: BotDifficulty.hard,
    stake: 50,
    people: const [],
    bots: {
      1: BotPersonality.all[2],
      2: BotPersonality.all[0],
      3: BotPersonality.all[5],
    },
    roundNumber: 2,
    rounds: [first.score()],
    start: round.start,
    log: round.log,
  );
}

SavedMatch throughJson(SavedMatch match) =>
    SavedMatch.fromJson(jsonDecode(jsonEncode(match.toJson())) as Json);

void main() {
  group('SavedMatch JSON', () {
    test('brings back the round being played, move for move', () {
      final match = savedMatch();
      final original = match.replay(Random(0));

      final restored = throughJson(match).replay(Random(0));

      expect(restored.log, hasLength(original.log.length));
      expect(describe(restored), describe(original));
    });

    test('brings back a finished round too', () {
      final match = savedMatch(turns: 1000);
      expect(match.replay(Random(0)).isOver, isTrue);

      final restored = throughJson(match).replay(Random(0));

      expect(restored.score().net, match.replay(Random(0)).score().net);
    });

    test('keeps the rules, the bots and who plays', () {
      final restored = throughJson(savedMatch());

      expect(restored.config.playerCount, 4);
      expect(restored.config.mode, GameMode.kidnap);
      expect(restored.config.manCardsEnabled, isTrue);
      expect(restored.config.supermanCardEnabled, isTrue);
      expect(restored.config.alterIsMaal, isFalse);
      expect(restored.config.jokerDiscardPenaltyEnabled, isTrue);
      expect(restored.difficulty, BotDifficulty.hard);
      expect(restored.stake, 50);
      expect(restored.isPassAndPlay, isFalse);
      expect(restored.bots.map((seat, bot) => MapEntry(seat, bot.name)), {
        1: 'Kiran',
        2: 'Bishal',
        3: 'Sabina',
      });
    });

    test('keeps the rounds finished so far', () {
      final match = savedMatch();

      final restored = throughJson(match);

      expect(restored.roundNumber, 2);
      final before = MatchScore(4)..addRound(match.rounds.single);
      final after = MatchScore(4)..addRound(restored.rounds.single);
      expect(after.totals, before.totals);
      expect(restored.rounds.single.maal.length, 4);
    });

    test('keeps the names of everyone sharing the device', () {
      final round = dealt(4, config: GameConfig(playerCount: 3));
      final restored = throughJson(
        SavedMatch(
          config: round.config,
          difficulty: BotDifficulty.medium,
          stake: null,
          people: const ['Asha', 'Bina', 'Chandra'],
          bots: const {},
          roundNumber: 1,
          rounds: const [],
          start: round.start,
          log: round.log,
        ),
      );

      expect(restored.people, ['Asha', 'Bina', 'Chandra']);
      expect(restored.isPassAndPlay, isTrue);
      expect(restored.stake, isNull);
    });

    test('keeps how each person arranged their hand', () {
      final match = savedMatch();
      final round = match.replay(Random(0));
      final arranged = SavedMatch(
        config: match.config,
        difficulty: match.difficulty,
        stake: match.stake,
        people: match.people,
        bots: match.bots,
        roundNumber: match.roundNumber,
        rounds: match.rounds,
        start: match.start,
        log: match.log,
        arrangements: {
          0: HandArrangement(
            cards: round.hands[0].cards.reversed.toList(),
            groups: [
              [2, 0, 1],
              [5, 4],
            ],
            selected: [7, 3],
          ),
        },
      );

      final restored = throughJson(arranged).arrangements;

      expect(restored.keys, [0]);
      expect(restored[0]!.cards, round.hands[0].cards.reversed);
      expect(restored[0]!.groups, [
        [2, 0, 1],
        [5, 4],
      ]);
      expect(restored[0]!.selected, [7, 3]);
    });

    test('a save from before selections were kept still loads', () {
      final match = savedMatch();
      final round = match.replay(Random(0));
      final json = match.toJson();
      json['arrangements'] = {
        '0': {
          'cards': [for (final card in round.hands[0].cards) cardToJson(card)],
          'groups': [
            [0, 1],
          ],
        },
      };

      final arrangement = SavedMatch.fromJson(json).arrangements[0]!;

      expect(arrangement.groups, [
        [0, 1],
      ]);
      expect(arrangement.selected, isEmpty);
    });

    test('a save from before hands were arranged still loads', () {
      final json = savedMatch().toJson()..remove('arrangements');

      expect(SavedMatch.fromJson(json).arrangements, isEmpty);
    });

    test('a different version can\'t be read', () {
      final json = savedMatch().toJson()..['version'] = 0;

      expect(() => SavedMatch.fromJson(json), throwsFormatException);
    });

    test('a bot nobody knows can\'t be read', () {
      final json = savedMatch().toJson();
      (json['bots']! as Map)['1'] = 'Nobody';

      expect(() => SavedMatch.fromJson(json), throwsFormatException);
    });
  });

  group('SavedMatchStore', () {
    test('has nothing until a match is saved', () {
      expect(SavedMatchStore(InMemoryPreferences()).load(), isNull);
    });

    test('loads the match last saved', () async {
      final store = SavedMatchStore(InMemoryPreferences());
      await store.save(savedMatch(turns: 5));
      await store.save(savedMatch(turns: 10));

      final loaded = store.load()!;

      expect(
        describe(loaded.replay(Random(0))),
        describe(savedMatch(turns: 10).replay(Random(0))),
      );
    });

    test('forgets a match once cleared', () async {
      final store = SavedMatchStore(InMemoryPreferences());
      await store.save(savedMatch());

      await store.clear();

      expect(store.load(), isNull);
    });

    test('forgets a save it can\'t read', () async {
      final preferences = InMemoryPreferences({'match.saved': '{"version'});

      expect(SavedMatchStore(preferences).load(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getString('match.saved'), isNull);
    });

    test('forgets a save whose moves no longer fit its cards', () async {
      final match = savedMatch();
      final broken = SavedMatch(
        config: match.config,
        difficulty: match.difficulty,
        stake: match.stake,
        people: match.people,
        bots: match.bots,
        roundNumber: match.roundNumber,
        rounds: match.rounds,
        start: match.start,
        // Two draws in one turn.
        log: [
          ...match.log,
          const DrawMove(DrawSource.stock),
          const DrawMove(DrawSource.stock),
        ],
      );
      final preferences = InMemoryPreferences();
      await SavedMatchStore(preferences).save(broken);

      expect(SavedMatchStore(preferences).load(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getString('match.saved'), isNull);
    });
  });
}
