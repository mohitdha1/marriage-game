/// The messages host and joining phones send each other, and their JSON
/// form.
///
/// A joining phone sends its name ([Hello]) and the moves its player makes
/// ([MoveMessage]s). The host answers with the seat it gave them
/// ([Welcome]), who has joined so far ([LobbyUpdate]), and once the game is
/// on, everything that player may see after each change ([SeatUpdate]):
/// never anyone else's cards. A move the engine won't allow comes back as
/// [Refused] with the reason.
library;

import '../engine/card.dart';
import '../engine/hand_arrangement.dart';
import '../engine/joker.dart';
import '../engine/player_hand.dart';
import '../engine/round.dart';
import '../engine/scoring.dart';
import '../engine/table_event.dart';
import '../ui/state/table_view.dart';

typedef Json = Map<String, Object?>;

/// Something sent between host and joining phones.
sealed class WireMessage {
  const WireMessage();

  Json toJson();

  /// The message [json] describes. Throws [FormatException] if it isn't one.
  static WireMessage fromJson(Json json) {
    try {
      return switch (json['type']) {
        'hello' => Hello(json['name']! as String),
        'welcome' => Welcome(json['seat']! as int),
        'lobby' => LobbyUpdate(
          names: _strings(json['names']),
          seats: json['seats']! as int,
        ),
        'rejected' => Rejected(json['reason']! as String),
        'refused' => Refused(json['reason']! as String),
        'update' => SeatUpdate.fromJson(json),
        'draw' => MoveDraw(DrawSource.values.byName(json['source']! as String)),
        'discard' => MoveDiscard(cardFromJson(json['card'])),
        'open' => MoveOpenTunnellas(setsFromJson(json['sets'])),
        'show' => MoveShow(
          kind: ShowKind.values.byName(json['kind']! as String),
          sets: setsFromJson(json['sets']),
          tipluPosition: json['tipluPosition'] as int?,
        ),
        'win' => MoveWin(cardFromJson(json['card'])),
        final type => throw FormatException('unknown message type $type'),
      };
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('malformed message: $e');
    }
  }
}

/// A joining phone introduces its player.
class Hello extends WireMessage {
  const Hello(this.name);

  final String name;

  @override
  Json toJson() => {'type': 'hello', 'name': name};
}

/// The host has given the joining player [seat].
class Welcome extends WireMessage {
  const Welcome(this.seat);

  final int seat;

  @override
  Json toJson() => {'type': 'welcome', 'seat': seat};
}

/// Who has joined so far, by seat, out of [seats] at the table.
class LobbyUpdate extends WireMessage {
  const LobbyUpdate({required this.names, required this.seats});

  final List<String> names;
  final int seats;

  @override
  Json toJson() => {'type': 'lobby', 'names': names, 'seats': seats};
}

/// The host turned the joining player away, saying why.
class Rejected extends WireMessage {
  const Rejected(this.reason);

  final String reason;

  @override
  Json toJson() => {'type': 'rejected', 'reason': reason};
}

/// The host didn't allow a move, saying why.
class Refused extends WireMessage {
  const Refused(this.reason);

  final String reason;

  @override
  Json toJson() => {'type': 'refused', 'reason': reason};
}

/// Everything one player may see, sent after every change at the table.
class SeatUpdate extends WireMessage {
  const SeatUpdate({
    required this.view,
    required this.handProgress,
    required this.winningCards,
    required this.roundNumber,
    required this.seatNames,
    required this.roundScores,
    required this.totals,
    required this.jokerPenalty,
    this.choosingOpening = false,
  });

  factory SeatUpdate.fromJson(Json json) => SeatUpdate(
    view: tableViewFromJson(json['view']! as Json),
    handProgress: _progressFromJson(json['progress'] as Json?),
    winningCards: cardsFromJson(json['winningCards']),
    roundNumber: json['round']! as int,
    seatNames: _strings(json['names']),
    roundScores: [
      for (final score in json['scores']! as List)
        _roundScoreFromJson(score as Json),
    ],
    totals: _ints(json['totals']),
    jokerPenalty: json['jokerPenalty']! as bool,
    choosingOpening: json['choosingOpening']! as bool,
  );

  final TableView view;
  final HandProgress? handProgress;

  /// The cards in hand that would leave a winning hand if discarded now.
  final List<PlayingCard> winningCards;

  final int roundNumber;
  final List<String> seatNames;
  final List<RoundScore> roundScores;
  final List<int> totals;

  /// Whether throwing away a joker after seeing it costs a penalty.
  final bool jokerPenalty;

  /// Whether the player was dealt more than 3 tunnellas and has to choose
  /// which to open with before play can start.
  final bool choosingOpening;

  @override
  Json toJson() => {
    'type': 'update',
    'view': tableViewToJson(view),
    'progress': _progressToJson(handProgress),
    'winningCards': cardsToJson(winningCards),
    'round': roundNumber,
    'names': seatNames,
    'scores': [for (final score in roundScores) _roundScoreToJson(score)],
    'totals': totals,
    'jokerPenalty': jokerPenalty,
    'choosingOpening': choosingOpening,
  };
}

/// A move a joining player makes, for the host to apply to the engine.
sealed class MoveMessage extends WireMessage {
  const MoveMessage();
}

class MoveDraw extends MoveMessage {
  const MoveDraw(this.source);

  final DrawSource source;

  @override
  Json toJson() => {'type': 'draw', 'source': source.name};
}

class MoveDiscard extends MoveMessage {
  const MoveDiscard(this.card);

  final PlayingCard card;

  @override
  Json toJson() => {'type': 'discard', 'card': cardToJson(card)};
}

class MoveOpenTunnellas extends MoveMessage {
  const MoveOpenTunnellas(this.tunnellas);

  final List<List<PlayingCard>> tunnellas;

  @override
  Json toJson() => {'type': 'open', 'sets': setsToJson(tunnellas)};
}

/// Shows [sets] to see the joker; the first to show also picks the tiplu at
/// [tipluPosition] in the stock.
class MoveShow extends MoveMessage {
  const MoveShow({required this.kind, required this.sets, this.tipluPosition});

  final ShowKind kind;
  final List<List<PlayingCard>> sets;
  final int? tipluPosition;

  @override
  Json toJson() => {
    'type': 'show',
    'kind': kind.name,
    'sets': setsToJson(sets),
    'tipluPosition': tipluPosition,
  };
}

/// Wins the round by discarding [card].
class MoveWin extends MoveMessage {
  const MoveWin(this.card);

  final PlayingCard card;

  @override
  Json toJson() => {'type': 'win', 'card': cardToJson(card)};
}

// Cards are written as "rank.suit", such as "queen.diamonds".

String cardToJson(PlayingCard card) => '${card.rank.name}.${card.suit.name}';

PlayingCard cardFromJson(Object? json) {
  final [rank, suit] = (json! as String).split('.');
  return PlayingCard(Suit.values.byName(suit), Rank.values.byName(rank));
}

PlayingCard? _cardOrNull(Object? json) =>
    json == null ? null : cardFromJson(json);

List<String> cardsToJson(List<PlayingCard> cards) => [
  for (final card in cards) cardToJson(card),
];

List<PlayingCard> cardsFromJson(Object? json) => [
  for (final card in json! as List) cardFromJson(card),
];

List<List<String>> setsToJson(List<List<PlayingCard>> sets) => [
  for (final set in sets) cardsToJson(set),
];

List<List<PlayingCard>> setsFromJson(Object? json) => [
  for (final set in json! as List) cardsFromJson(set),
];

List<String> _strings(Object? json) => [
  for (final s in json! as List) s as String,
];

List<int> _ints(Object? json) => [for (final i in json! as List) i as int];

Json seatViewToJson(SeatView seat) => {
  'seat': seat.seat,
  'name': seat.name,
  'cards': seat.cardCount,
  'seen': seat.hasSeenJoker,
  'laidDown': setsToJson(seat.laidDown),
  'avatar': seat.avatarColor,
  'lastDiscard': seat.lastDiscard == null
      ? null
      : cardToJson(seat.lastDiscard!),
};

SeatView seatViewFromJson(Json json) => SeatView(
  seat: json['seat']! as int,
  name: json['name']! as String,
  cardCount: json['cards']! as int,
  hasSeenJoker: json['seen']! as bool,
  laidDown: setsFromJson(json['laidDown']),
  avatarColor: json['avatar'] as int?,
  lastDiscard: _cardOrNull(json['lastDiscard']),
);

Json tableViewToJson(TableView view) => {
  'you': seatViewToJson(view.you),
  'opponents': [for (final seat in view.opponents) seatViewToJson(seat)],
  'hand': cardsToJson(view.hand),
  'stock': view.stockCount,
  'topDiscard': view.topDiscard == null ? null : cardToJson(view.topDiscard!),
  'current': view.currentSeat,
  'drawn': view.youHaveDrawn,
  'winner': view.winner == null ? null : seatViewToJson(view.winner!),
  'jokerChosen': view.isJokerChosen,
  'tiplu': view.yourJokers == null ? null : cardToJson(view.yourJokers!.tiplu),
  'pureSetsNeeded': view.pureSetsStillNeeded,
  'events': [for (final event in view.events) eventToJson(event)],
};

TableView tableViewFromJson(Json json) => TableView(
  you: seatViewFromJson(json['you']! as Json),
  opponents: [
    for (final seat in json['opponents']! as List)
      seatViewFromJson(seat as Json),
  ],
  hand: cardsFromJson(json['hand']),
  stockCount: json['stock']! as int,
  topDiscard: _cardOrNull(json['topDiscard']),
  currentSeat: json['current']! as int,
  youHaveDrawn: json['drawn']! as bool,
  winner: json['winner'] == null
      ? null
      : seatViewFromJson(json['winner']! as Json),
  isJokerChosen: json['jokerChosen']! as bool,
  yourJokers: switch (_cardOrNull(json['tiplu'])) {
    final tiplu? => Jokers(tiplu),
    null => null,
  },
  pureSetsStillNeeded: json['pureSetsNeeded']! as int,
  events: [
    for (final event in json['events']! as List) eventFromJson(event as Json),
  ],
);

Json eventToJson(TableEvent event) => switch (event) {
  OpenedTunnellas(:final seat, :final tunnellas) => {
    'type': 'opened',
    'seat': seat,
    'sets': setsToJson(tunnellas),
  },
  DrewCard(:final seat, :final source, :final card) => {
    'type': 'drew',
    'seat': seat,
    'source': source.name,
    'card': card == null ? null : cardToJson(card),
  },
  ShowedSets(:final seat, :final kind, :final sets) => {
    'type': 'showed',
    'seat': seat,
    'kind': kind.name,
    'sets': setsToJson(sets),
  },
  DiscardedCard(:final seat, :final card) => {
    'type': 'discarded',
    'seat': seat,
    'card': cardToJson(card),
  },
  WonRound(:final seat, :final card) => {
    'type': 'won',
    'seat': seat,
    'card': cardToJson(card),
  },
  StockReshuffled(:final seat) => {'type': 'reshuffled', 'seat': seat},
};

TableEvent eventFromJson(Json json) {
  final seat = json['seat']! as int;
  return switch (json['type']) {
    'opened' => OpenedTunnellas(seat, setsFromJson(json['sets'])),
    'drew' => DrewCard(
      seat,
      DrawSource.values.byName(json['source']! as String),
      _cardOrNull(json['card']),
    ),
    'showed' => ShowedSets(
      seat,
      ShowKind.values.byName(json['kind']! as String),
      setsFromJson(json['sets']),
    ),
    'discarded' => DiscardedCard(seat, cardFromJson(json['card'])),
    'won' => WonRound(seat, cardFromJson(json['card'])),
    'reshuffled' => StockReshuffled(seat),
    final type => throw FormatException('unknown event type $type'),
  };
}

Json? _progressToJson(HandProgress? progress) => switch (progress) {
  null => null,
  ShowProgress(:final pureSets, :final pureSetsNeeded, :final doublees) => {
    'type': 'show',
    'pureSets': pureSets,
    'pureSetsNeeded': pureSetsNeeded,
    'doublees': doublees,
  },
  WinProgress(:final setsMade, :final unmatched, :final maal) => {
    'type': 'win',
    'setsMade': setsMade,
    'unmatched': unmatched,
    'maal': maal,
  },
  DubleeProgress(:final doublees, :final maal) => {
    'type': 'doublee',
    'doublees': doublees,
    'maal': maal,
  },
};

HandProgress? _progressFromJson(Json? json) => switch (json?['type']) {
  null => null,
  'show' => ShowProgress(
    pureSets: json!['pureSets']! as int,
    pureSetsNeeded: json['pureSetsNeeded']! as int,
    doublees: json['doublees']! as int,
  ),
  'win' => WinProgress(
    setsMade: json!['setsMade']! as int,
    unmatched: json['unmatched']! as int,
    maal: json['maal']! as int,
  ),
  'doublee' => DubleeProgress(
    doublees: json!['doublees']! as int,
    maal: json['maal']! as int,
  ),
  final type => throw FormatException('unknown progress type $type'),
};

Json _maalToJson(MaalBreakdown maal) => {
  'tunnellas': maal.tunnellas,
  'shownMarriages': maal.shownMarriages,
  'handMarriages': maal.handMarriages,
  'tiplu': maal.tiplu,
  'jhiplu': maal.jhiplu,
  'poplu': maal.poplu,
  'alter': maal.alter,
};

MaalBreakdown _maalFromJson(Json json) => MaalBreakdown(
  tunnellas: json['tunnellas']! as int,
  shownMarriages: json['shownMarriages']! as int,
  handMarriages: json['handMarriages']! as int,
  tiplu: json['tiplu']! as int,
  jhiplu: json['jhiplu']! as int,
  poplu: json['poplu']! as int,
  alter: json['alter']! as int,
);

Json _roundScoreToJson(RoundScore score) => {
  'winner': score.winner,
  'maal': [for (final maal in score.maal) _maalToJson(maal)],
  'net': score.net,
  'penalties': score.penalties,
  'maalShares': score.maalShares,
  'winnerPayments': score.winnerPayments,
  'sawJoker': score.sawJoker,
  'doublees': score.wonWithDoublees,
};

RoundScore _roundScoreFromJson(Json json) => RoundScore(
  winner: json['winner']! as int,
  maal: [for (final maal in json['maal']! as List) _maalFromJson(maal as Json)],
  net: _ints(json['net']),
  penalties: _ints(json['penalties']),
  maalShares: _ints(json['maalShares']),
  winnerPayments: _ints(json['winnerPayments']),
  sawJoker: [for (final saw in json['sawJoker']! as List) saw as bool],
  wonWithDoublees: json['doublees']! as bool,
);
