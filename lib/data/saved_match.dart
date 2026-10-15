import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../bots/bot_personality.dart';
import '../bots/bot_player.dart';
import '../engine/card.dart';
import '../engine/game_config.dart';
import '../engine/player_hand.dart';
import '../engine/round.dart';
import '../engine/round_log.dart';
import '../engine/scoring.dart';
import '../net/wire.dart'
    show
        Json,
        cardFromJson,
        cardToJson,
        cardsFromJson,
        cardsToJson,
        roundScoreFromJson,
        roundScoreToJson,
        setsFromJson,
        setsToJson;
import '../ui/settings/preferences.dart';

/// How a person had arranged their hand: its [cards] in order, the sets
/// they'd grouped and the cards they'd [selected], as positions in
/// [cards].
class HandArrangement {
  HandArrangement({
    required List<PlayingCard> cards,
    required List<List<int>> groups,
    List<int> selected = const [],
  }) : cards = List.unmodifiable(cards),
       groups = List.unmodifiable(groups.map(List<int>.unmodifiable)),
       selected = List.unmodifiable(selected);

  final List<PlayingCard> cards;
  final List<List<int>> groups;
  final List<int> selected;
}

/// A match played on this device, saved after every move so it can be
/// picked up again if the app is closed: who plays it, the rounds finished
/// so far, the round being played, as the cards it started from and every
/// move since, and how each person had arranged their hand.
class SavedMatch {
  SavedMatch({
    required this.config,
    required this.difficulty,
    required this.stake,
    required this.people,
    required this.bots,
    required this.roundNumber,
    required this.rounds,
    required this.start,
    required this.log,
    this.arrangements = const {},
  });

  /// The rules and number of players.
  final GameConfig config;

  /// How well the bots play.
  final BotDifficulty difficulty;

  /// Coins per point at a stake table; `null` for any other game.
  final int? stake;

  /// Everyone sharing the device in pass and play, by seat; empty against
  /// bots.
  final List<String> people;

  /// The bots at the table, by seat.
  final Map<int, BotPersonality> bots;

  /// The round being played, counting from 1.
  final int roundNumber;

  /// Every round finished so far, oldest first, including the current one
  /// once it's over.
  final List<RoundScore> rounds;

  /// The current round's cards as dealt.
  final RoundStart start;

  /// Every move made in the current round.
  final List<RoundLogEntry> log;

  /// How the people at the device had arranged their hands, by seat. A
  /// seat that isn't here has its hand dealt in the usual order.
  final Map<int, HandArrangement> arrangements;

  /// The current round, played again to where it was saved. Throws if the
  /// moves no longer fit the cards.
  Round replay(Random random) =>
      Round.replay(config: config, random: random, start: start, log: log);

  /// Whether several people share the device in this match.
  bool get isPassAndPlay => people.isNotEmpty;

  static const _version = 1;

  Json toJson() => {
    'version': _version,
    'config': {
      'players': config.playerCount,
      'mode': config.mode.name,
      'manCards': config.manCardsEnabled,
      'superman': config.supermanCardEnabled,
      'alterIsMaal': config.alterIsMaal,
      'jokerPenalty': config.jokerDiscardPenaltyEnabled,
    },
    'difficulty': difficulty.name,
    'stake': stake,
    'people': people,
    'bots': {
      for (final MapEntry(key: seat, value: bot) in bots.entries)
        '$seat': bot.name,
    },
    'round': roundNumber,
    'scores': [for (final score in rounds) roundScoreToJson(score)],
    'start': {
      'hands': setsToJson(start.hands),
      'stock': cardsToJson(start.stock),
      'discards': cardsToJson(start.discardPile),
      'firstSeat': start.firstSeat,
    },
    'log': [for (final entry in log) _entryToJson(entry)],
    'arrangements': {
      for (final MapEntry(key: seat, value: hand) in arrangements.entries)
        '$seat': {
          'cards': cardsToJson(hand.cards),
          'groups': hand.groups,
          'selected': hand.selected,
        },
    },
  };

  /// The match [json] describes. Throws [FormatException] if it isn't one
  /// this version of the app can read.
  factory SavedMatch.fromJson(Json json) {
    if (json['version'] != _version) {
      throw FormatException('unknown saved match version ${json['version']}');
    }
    try {
      final config = json['config']! as Json;
      final start = json['start']! as Json;
      return SavedMatch(
        config: GameConfig(
          playerCount: config['players']! as int,
          mode: GameMode.values.byName(config['mode']! as String),
          manCardsEnabled: config['manCards']! as bool,
          supermanCardEnabled: config['superman']! as bool,
          alterIsMaal: config['alterIsMaal']! as bool,
          jokerDiscardPenaltyEnabled: config['jokerPenalty']! as bool,
        ),
        difficulty: BotDifficulty.values.byName(json['difficulty']! as String),
        stake: json['stake'] as int?,
        people: [for (final name in json['people']! as List) name as String],
        bots: {
          for (final MapEntry(:key, :value) in (json['bots']! as Json).entries)
            int.parse(key): BotPersonality.all.firstWhere(
              (bot) => bot.name == value,
            ),
        },
        roundNumber: json['round']! as int,
        rounds: [
          for (final score in json['scores']! as List)
            roundScoreFromJson(score as Json),
        ],
        start: RoundStart(
          hands: setsFromJson(start['hands']),
          stock: cardsFromJson(start['stock']),
          discardPile: cardsFromJson(start['discards']),
          firstSeat: start['firstSeat']! as int,
        ),
        log: [
          for (final entry in json['log']! as List)
            _entryFromJson(entry as Json),
        ],
        // Absent from saves made before hands were arranged.
        arrangements: {
          for (final MapEntry(:key, :value)
              in ((json['arrangements'] as Json?) ?? const {}).entries)
            int.parse(key): _arrangementFromJson(value! as Json),
        },
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('malformed saved match: $e');
    }
  }
}

HandArrangement _arrangementFromJson(Json json) => HandArrangement(
  cards: cardsFromJson(json['cards']),
  groups: [
    for (final group in json['groups']! as List)
      [for (final i in group as List) i as int],
  ],
  // Absent from saves made before selections were kept.
  selected: [for (final i in (json['selected'] as List?) ?? const []) i as int],
);

Json _entryToJson(RoundLogEntry entry) => switch (entry) {
  OpeningMove(:final seat, :final tunnellas) => {
    'type': 'open',
    'seat': seat,
    'sets': setsToJson(tunnellas),
  },
  DrawMove(:final source) => {'type': 'draw', 'source': source.name},
  ShowMove(:final kind, :final sets, :final tipluPosition) => {
    'type': 'show',
    'kind': kind.name,
    'sets': setsToJson(sets),
    'tiplu': tipluPosition,
  },
  PickTipluMove(:final position) => {'type': 'pick', 'position': position},
  DiscardMove(:final card) => {'type': 'discard', 'card': cardToJson(card)},
  WinMove(:final card) => {'type': 'win', 'card': cardToJson(card)},
  StockShuffle(:final stock) => {
    'type': 'shuffle',
    'stock': cardsToJson(stock),
  },
};

RoundLogEntry _entryFromJson(Json json) => switch (json['type']) {
  'open' => OpeningMove(json['seat']! as int, setsFromJson(json['sets'])),
  'draw' => DrawMove(DrawSource.values.byName(json['source']! as String)),
  'show' => ShowMove(
    ShowKind.values.byName(json['kind']! as String),
    setsFromJson(json['sets']),
    json['tiplu'] as int?,
  ),
  'pick' => PickTipluMove(json['position']! as int),
  'discard' => DiscardMove(cardFromJson(json['card'])),
  'win' => WinMove(cardFromJson(json['card'])),
  'shuffle' => StockShuffle(cardsFromJson(json['stock'])),
  final type => throw FormatException('unknown move type $type'),
};

/// Keeps the match in progress among the app's saved preferences: one at
/// a time, replaced by each newer save.
class SavedMatchStore {
  SavedMatchStore(this._store);

  final PreferencesStore _store;

  static const _key = 'match.saved';

  /// The saved match, or `null` if there's none, or it can't be read or
  /// played again (saved by an older version of the app, say), in which
  /// case it's forgotten.
  SavedMatch? load() {
    final saved = _store.getString(_key);
    if (saved == null) return null;
    try {
      final match = SavedMatch.fromJson(jsonDecode(saved) as Json);
      match.replay(Random());
      return match;
    } on Object {
      unawaited(clear());
      return null;
    }
  }

  Future<void> save(SavedMatch match) =>
      _store.setString(_key, jsonEncode(match.toJson()));

  Future<void> clear() => _store.remove(_key);
}
