import 'card.dart';
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
MaalBreakdown scoreMaal(PlayerHand hand, Jokers jokers) {
  if (!hand.hasSeenJoker) return const MaalBreakdown();

  var tunnellaPoints = 0;
  for (final tunnella in hand.openingTunnellas) {
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
  RoundScore({required this.winner, required this.maal, required this.net});

  /// Seat index of the player who won the round.
  final int winner;

  /// Each player's maal points, by seat.
  final List<MaalBreakdown> maal;

  /// Each player's points won (+) or lost (−) this round, by seat. Always
  /// sums to zero.
  final List<int> net;
}

/// Settles a round won by the player at seat [winner].
///
/// Maal is zero-sum: each player's share is their own maal × the number of
/// players, minus everyone's maal combined. On top of that, every other
/// player pays the winner 3 if they saw the joker or 10 if they didn't, plus
/// 5 more if the winner showed doublees.
RoundScore scoreRound({
  required List<PlayerHand> hands,
  required int winner,
  required Jokers jokers,
}) {
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
  final totalMaal = maal.fold(0, (sum, m) => sum + m.total);
  final net = [for (final m in maal) m.total * hands.length - totalMaal];

  final dubleeWin = hands[winner].showKind == ShowKind.doublees;
  for (var seat = 0; seat < hands.length; seat++) {
    if (seat == winner) continue;
    var payment = hands[seat].hasSeenJoker
        ? ScoringTable.winnerFromSeen
        : ScoringTable.winnerFromUnseen;
    if (dubleeWin) payment += ScoringTable.dubleeWinBonus;
    net[seat] -= payment;
    net[winner] += payment;
  }

  return RoundScore(winner: winner, maal: maal, net: net);
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
