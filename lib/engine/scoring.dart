import 'card.dart';
import 'game_config.dart';
import 'joker.dart';
import 'player_hand.dart';

/// Every point value used in scoring, in one place.
///
/// The count tables are indexed by how many of that card a player holds, so
/// they escalate rather than add up: 2 alters is 15, not 5 + 5. They assume
/// the standard 3-deck shoe; with 3 decks, only 2 tiplus are ever in play
/// because the flipped one is out of the game.
abstract final class ScoringTable {
  static const tipluByCount = [0, 3, 8];
  static const jhipluOrPopluByCount = [0, 2, 5, 10];
  static const alterByCount = [0, 5, 15, 25];

  /// Opening-show tunnellas.
  static const alterTunnella = 30;
  static const jhipluOrPopluTunnella = 15;
  static const plainTunnella = 5;

  /// Jhiplu + tiplu + poplu, replacing those three cards' own points.
  static const shownMarriage = 15;
  static const handMarriage = 10;

  /// What each other player pays the round's winner.
  static const winnerFromSeen = 3;
  static const winnerFromUnseen = 10;
  static const dubleeWinBonus = 5;

  /// Paid to the winner for each wild card a player discarded after seeing
  /// the joker, when [GameConfig.jokerDiscardPenaltyEnabled] is on.
  static const jokerDiscardPenalty = 15;
}

/// One player's maal points for a round, itemised for the scoreboard.
class MaalBreakdown {
  const MaalBreakdown({
    this.tunnellas = 0,
    this.shownMarriages = 0,
    this.handMarriages = 0,
    this.tiplu = 0,
    this.jhiplu = 0,
    this.poplu = 0,
    this.alter = 0,
  });

  /// Points from opening-show tunnellas.
  final int tunnellas;

  /// How many marriages were scored as shown (15 each) or in hand (10 each).
  final int shownMarriages;
  final int handMarriages;

  /// Points from maal cards not used in a marriage or opening tunnella.
  final int tiplu;
  final int jhiplu;
  final int poplu;
  final int alter;

  int get marriages =>
      shownMarriages * ScoringTable.shownMarriage +
      handMarriages * ScoringTable.handMarriage;

  int get total => tunnellas + marriages + tiplu + jhiplu + poplu + alter;
}

/// Works out a player's maal points. Players who haven't seen the joker score
/// nothing at all, opening tunnellas included.
MaalBreakdown scoreMaal(PlayerHand hand, Jokers jokers) => hand.hasSeenJoker
    ? _maalOf(hand, jokers, withTunnellas: true)
    : const MaalBreakdown();

/// The maal a player who hasn't seen the joker loses to the winner in
/// [GameMode.kidnap]: what their cards would score had they seen it, leaving
/// out their opening tunnellas.
MaalBreakdown kidnappedMaal(PlayerHand hand, Jokers jokers) =>
    _maalOf(hand, jokers, withTunnellas: false);

MaalBreakdown _maalOf(
  PlayerHand hand,
  Jokers jokers, {
  required bool withTunnellas,
}) {
  var tunnellaPoints = 0;
  for (final tunnella in withTunnellas ? hand.openingTunnellas : const []) {
    tunnellaPoints += switch (jokers.kindOf(tunnella.first)) {
      JokerKind.alter => ScoringTable.alterTunnella,
      JokerKind.jhiplu || JokerKind.poplu => ScoringTable.jhipluOrPopluTunnella,
      JokerKind.tiplu => throw StateError(
        'A tiplu tunnella is impossible: only 2 tiplus are in play',
      ),
      JokerKind.ordinary || null => ScoringTable.plainTunnella,
    };
  }

  // Opening-tunnella cards are already scored, so only the rest count here.
  final cards = [...hand.cards, ...hand.shownSets.expand((set) => set)];
  int countOf(PlayingCard card) => cards.where((c) => c == card).length;
  final tipluCount = countOf(jokers.tiplu);
  final jhipluCount = countOf(jokers.jhiplu);
  final popluCount = countOf(jokers.poplu);
  final alterCount = countOf(jokers.alter);

  final shownTrios = hand.shownSets
      .where(
        (set) =>
            set.contains(jokers.jhiplu) &&
            set.contains(jokers.tiplu) &&
            set.contains(jokers.poplu),
      )
      .length;

  // A marriage replaces its three cards' points, which can sometimes score
  // less than the cards alone, so try every way of counting marriages and
  // keep the best for the player.
  MaalBreakdown? best;
  for (var shown = 0; shown <= shownTrios; shown++) {
    final maxInHand =
        [tipluCount, jhipluCount, popluCount].reduce((a, b) => a < b ? a : b) -
        shown;
    for (var inHand = 0; inHand <= maxInHand; inHand++) {
      final used = shown + inHand;
      final candidate = MaalBreakdown(
        tunnellas: tunnellaPoints,
        shownMarriages: shown,
        handMarriages: inHand,
        tiplu: _lookup(ScoringTable.tipluByCount, tipluCount - used, 'tiplu'),
        jhiplu: _lookup(
          ScoringTable.jhipluOrPopluByCount,
          jhipluCount - used,
          'jhiplu',
        ),
        poplu: _lookup(
          ScoringTable.jhipluOrPopluByCount,
          popluCount - used,
          'poplu',
        ),
        alter: _lookup(ScoringTable.alterByCount, alterCount, 'alter'),
      );
      if (best == null || candidate.total > best.total) best = candidate;
    }
  }
  return best!;
}

int _lookup(List<int> table, int count, String name) {
  if (count >= table.length) {
    throw StateError('$count ${name}s is more than a 3-deck shoe allows');
  }
  return table[count];
}

/// The outcome of one round.
class RoundScore {
  RoundScore({
    required this.winner,
    required this.maal,
    required this.net,
    List<int>? penalties,
    List<int>? maalShares,
    List<int>? winnerPayments,
    List<bool>? sawJoker,
    List<int>? kidnapped,
    this.wonWithDoublees = false,
  }) : penalties = penalties ?? List.filled(net.length, 0),
       kidnapped = kidnapped ?? List.filled(net.length, 0),
       maalShares = maalShares ?? List.filled(net.length, 0),
       winnerPayments = winnerPayments ?? List.filled(net.length, 0),
       sawJoker = sawJoker ?? List.filled(net.length, false);

  /// Seat index of the player who won the round.
  final int winner;

  /// Each player's maal points, by seat.
  final List<MaalBreakdown> maal;

  /// Each player's points won (+) or lost (−) this round, by seat. Always
  /// sums to zero.
  final List<int> net;

  /// Joker-discard penalty points each player paid the winner, by seat;
  /// already included in [net].
  final List<int> penalties;

  /// Each player's zero-sum share of the maal: the maal counted for them ×
  /// the number of players, minus all the maal counted. Part of [net].
  final List<int> maalShares;

  /// In [GameMode.kidnap], the maal points the winner took from each player
  /// who hadn't seen the joker, by seat; counted for the winner in
  /// [maalShares]. All zeros in other modes.
  final List<int> kidnapped;

  /// What each player paid the winner (negative) for losing the round, and
  /// what the winner collected (positive), by seat. Part of [net].
  final List<int> winnerPayments;

  /// Whether each player had seen the joker when the round ended.
  final List<bool> sawJoker;

  /// Whether the winner showed doublees, which earns them
  /// [ScoringTable.dubleeWinBonus] extra from every other player.
  final bool wonWithDoublees;

  /// [penalties] as transfers: negative for each player who paid, and the
  /// total collected (positive) for the winner.
  List<int> get penaltyTransfers {
    final collected = penalties.fold(0, (sum, p) => sum + p);
    return [
      for (var seat = 0; seat < penalties.length; seat++)
        seat == winner ? collected : -penalties[seat],
    ];
  }
}

/// Settles a round won by the player at seat [winner].
///
/// Maal is zero-sum: each player's share is the maal counted for them × the
/// number of players, minus all the maal counted. In [GameMode.kidnap], the
/// maal of each player who hasn't seen the joker (see [kidnappedMaal]) is
/// counted for the winner. On top of that, every other
/// player pays the winner 3 if they saw the joker or 10 if they didn't, plus
/// 5 more if the winner showed doublees.
///
/// [jokerDiscards] is how many wild cards each seat discarded after seeing
/// the joker; each one costs [ScoringTable.jokerDiscardPenalty], paid to the
/// winner. The round passes all zeros when that house rule is off. The
/// winner's own joker discards cost nothing, since they'd be paying
/// themselves.
RoundScore scoreRound({
  required List<PlayerHand> hands,
  required int winner,
  required Jokers jokers,
  List<int>? jokerDiscards,
  GameMode mode = GameMode.standard,
}) {
  if (jokerDiscards != null && jokerDiscards.length != hands.length) {
    throw ArgumentError.value(
      jokerDiscards.length,
      'jokerDiscards',
      'must have one count per seat',
    );
  }
  if (winner < 0 || winner >= hands.length) {
    throw ArgumentError.value(winner, 'winner', 'is not a seat at the table');
  }
  if (!hands[winner].hasSeenJoker) {
    throw ArgumentError.value(
      winner,
      'winner',
      'must have seen the joker to win',
    );
  }

  final maal = [for (final hand in hands) scoreMaal(hand, jokers)];
  final kidnapped = [
    for (final hand in hands)
      mode == GameMode.kidnap && !hand.hasSeenJoker
          ? kidnappedMaal(hand, jokers).total
          : 0,
  ];
  final taken = kidnapped.fold(0, (sum, k) => sum + k);
  final counted = [
    for (var seat = 0; seat < hands.length; seat++)
      maal[seat].total + (seat == winner ? taken : 0),
  ];
  final totalMaal = counted.fold(0, (sum, m) => sum + m);
  final maalShares = [for (final m in counted) m * hands.length - totalMaal];
  final net = [...maalShares];

  final dubleeWin = hands[winner].showKind == ShowKind.doublees;
  final penalties = List.filled(hands.length, 0);
  final winnerPayments = List.filled(hands.length, 0);
  for (var seat = 0; seat < hands.length; seat++) {
    if (seat == winner) continue;
    var payment = hands[seat].hasSeenJoker
        ? ScoringTable.winnerFromSeen
        : ScoringTable.winnerFromUnseen;
    if (dubleeWin) payment += ScoringTable.dubleeWinBonus;
    net[seat] -= payment;
    net[winner] += payment;
    winnerPayments[seat] -= payment;
    winnerPayments[winner] += payment;

    final penalty =
        (jokerDiscards?[seat] ?? 0) * ScoringTable.jokerDiscardPenalty;
    penalties[seat] = penalty;
    net[seat] -= penalty;
    net[winner] += penalty;
  }

  return RoundScore(
    winner: winner,
    maal: maal,
    net: net,
    penalties: penalties,
    maalShares: maalShares,
    winnerPayments: winnerPayments,
    sawJoker: [for (final hand in hands) hand.hasSeenJoker],
    kidnapped: kidnapped,
    wonWithDoublees: dubleeWin,
  );
}

/// Running totals across a match. There's no round limit: players stop
/// whenever they like, and whoever is ahead then wins.
class MatchScore {
  MatchScore(this.playerCount) : _totals = List.filled(playerCount, 0);

  final int playerCount;
  final List<int> _totals;
  final List<RoundScore> _rounds = [];

  /// Each player's running total, by seat.
  List<int> get totals => List.unmodifiable(_totals);

  /// Every round played so far, oldest first.
  List<RoundScore> get rounds => List.unmodifiable(_rounds);

  void addRound(RoundScore round) {
    if (round.net.length != playerCount) {
      throw ArgumentError.value(
        round.net.length,
        'round',
        'has scores for the wrong number of players',
      );
    }
    for (var seat = 0; seat < playerCount; seat++) {
      _totals[seat] += round.net[seat];
    }
    _rounds.add(round);
  }

  /// Seats with the highest total — more than one if tied. Before any round
  /// is played, everyone is tied on 0.
  List<int> get leaders {
    final top = _totals.reduce((a, b) => a > b ? a : b);
    return [
      for (var seat = 0; seat < playerCount; seat++)
        if (_totals[seat] == top) seat,
    ];
  }
}
