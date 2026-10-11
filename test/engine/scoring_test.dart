import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/joker.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/scoring.dart';

const c = PlayingCard.new;

// Tiplu 7♥ → jhiplu 6♥, poplu 8♥, alter 7♦; 7♣ and 7♠ are ordinary jokers.
final jokers = Jokers(c(Suit.hearts, Rank.seven));
final tiplu = c(Suit.hearts, Rank.seven);
final jhiplu = c(Suit.hearts, Rank.six);
final poplu = c(Suit.hearts, Rank.eight);
final alter = c(Suit.diamonds, Rank.seven);
final ordinary = c(Suit.clubs, Rank.seven);

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

// Pure sequences with no maal in them, for the joker-seen show.
final spadesRun = [
  c(Suit.spades, Rank.two),
  c(Suit.spades, Rank.three),
  c(Suit.spades, Rank.four),
];
final clubsRun = [
  c(Suit.clubs, Rank.nine),
  c(Suit.clubs, Rank.ten),
  c(Suit.clubs, Rank.jack),
];
final diamondsRun = [
  c(Suit.diamonds, Rank.jack),
  c(Suit.diamonds, Rank.queen),
  c(Suit.diamonds, Rank.king),
];

/// A hand that has opened with [opening], then seen the joker by showing
/// [shown] (3 − opening count sets), while also holding [held].
///
/// Without [drawn], the show happens before the first draw (sets straight
/// from the deal). With [drawn] — one of the cards in [held] or [shown] —
/// that card is left out of the deal and drawn before showing instead. That's
/// how a player ends up with 3 copies of a card that wasn't an opening
/// tunnella.
PlayerHand seenHand({
  List<PlayingCard> held = const [],
  List<List<PlayingCard>> opening = const [],
  List<List<PlayingCard>>? shown,
  PlayingCard? drawn,
}) {
  final sets = shown ?? [spadesRun, clubsRun, diamondsRun];
  final dealt = [
    ...opening.expand((t) => t),
    ...sets.expand((s) => s),
    ...held,
  ];
  if (drawn != null && !dealt.remove(drawn)) {
    throw ArgumentError('drawn must be one of the held or shown cards');
  }
  final hand = PlayerHand(dealt)..showOpeningTunnellas(opening);
  if (drawn != null) hand.draw(drawn);
  hand.showPureSets(sets);
  return hand;
}

/// A hand that has opened but never seen the joker.
PlayerHand unseenHand({
  List<PlayingCard> held = const [],
  List<List<PlayingCard>> opening = const [],
}) =>
    PlayerHand([...opening.expand((t) => t), ...held])
      ..showOpeningTunnellas(opening);

int maalOf(PlayerHand hand) => scoreMaal(hand, jokers).total;

void main() {
  group('scoreMaal: who scores', () {
    test('a player who has not seen the joker scores nothing', () {
      final hand = unseenHand(
        held: [tiplu, jhiplu, poplu, alter],
        opening: [tunnellaOf(alter)],
      );

      expect(maalOf(hand), 0);
    });

    test('a seen player with no maal scores 0', () {
      expect(maalOf(seenHand()), 0);
    });
  });

  group('scoreMaal: count tables', () {
    test('tiplu: 1 = 3, 2 = 8', () {
      expect(maalOf(seenHand(held: [tiplu])), 3);
      expect(maalOf(seenHand(held: [tiplu, tiplu])), 8);
    });

    test('jhiplu: 1 = 2, 2 = 5, 3 = 10', () {
      expect(maalOf(seenHand(held: [jhiplu])), 2);
      expect(maalOf(seenHand(held: [jhiplu, jhiplu])), 5);
      expect(
        maalOf(seenHand(held: [jhiplu, jhiplu, jhiplu], drawn: jhiplu)),
        10,
      );
    });

    test('poplu: 1 = 2, 2 = 5, 3 = 10', () {
      expect(maalOf(seenHand(held: [poplu])), 2);
      expect(maalOf(seenHand(held: [poplu, poplu])), 5);
      expect(maalOf(seenHand(held: [poplu, poplu, poplu], drawn: poplu)), 10);
    });

    test('jhiplu and poplu are counted separately', () {
      final breakdown = scoreMaal(seenHand(held: [jhiplu, poplu]), jokers);

      expect(breakdown.jhiplu, 2);
      expect(breakdown.poplu, 2);
      expect(breakdown.total, 4);
    });

    test('alter: 1 = 5, 2 = 15, 3 = 25', () {
      expect(maalOf(seenHand(held: [alter])), 5);
      expect(maalOf(seenHand(held: [alter, alter])), 15);
      expect(maalOf(seenHand(held: [alter, alter, alter], drawn: alter)), 25);
    });

    test('ordinary jokers are worth nothing', () {
      expect(maalOf(seenHand(held: [ordinary, c(Suit.spades, Rank.seven)])), 0);
    });

    test('maal in shown sets counts too', () {
      // 8♥-9♥-10♥ is a pure sequence holding the poplu.
      final popluRun = [
        poplu,
        c(Suit.hearts, Rank.nine),
        c(Suit.hearts, Rank.ten),
      ];
      final hand = seenHand(shown: [popluRun, spadesRun, clubsRun]);

      expect(maalOf(hand), 2);
    });
  });

  group('scoreMaal: opening tunnellas', () {
    PlayerHand openedWith(PlayingCard card) =>
        seenHand(opening: [tunnellaOf(card)], shown: [spadesRun, clubsRun]);

    test('alter tunnella = 30, and its cards are not counted again', () {
      final breakdown = scoreMaal(openedWith(alter), jokers);

      expect(breakdown.tunnellas, 30);
      expect(breakdown.alter, 0);
      expect(breakdown.total, 30);
    });

    test('jhiplu or poplu tunnella = 15', () {
      expect(maalOf(openedWith(jhiplu)), 15);
      expect(maalOf(openedWith(poplu)), 15);
    });

    test('plain tunnella = 5', () {
      expect(maalOf(openedWith(c(Suit.spades, Rank.king))), 5);
    });

    test('ordinary-joker tunnella = 5, like a plain one', () {
      expect(maalOf(openedWith(ordinary)), 5);
    });

    test('a tunnella shown later, not at the opening, gets no bonus', () {
      // 3 alters, the third drawn, shown at the joker-seen show: scored
      // from the count table (25), not as a tunnella (30).
      final hand = seenHand(
        held: [c(Suit.spades, Rank.king)],
        drawn: alter,
        shown: [tunnellaOf(alter), spadesRun, clubsRun],
      );

      expect(scoreMaal(hand, jokers).tunnellas, 0);
      expect(maalOf(hand), 25);
    });

    test('a tiplu tunnella is impossible and throws', () {
      expect(() => scoreMaal(openedWith(tiplu), jokers), throwsStateError);
    });
  });

  group('scoreMaal: marriage', () {
    final trio = [jhiplu, tiplu, poplu];

    test('in hand = 10, replacing the cards\' own 3 + 2 + 2', () {
      final breakdown = scoreMaal(seenHand(held: trio), jokers);

      expect(breakdown.handMarriages, 1);
      expect(breakdown.tiplu + breakdown.jhiplu + breakdown.poplu, 0);
      expect(breakdown.total, 10);
    });

    test('shown at the joker-seen show = 15', () {
      final breakdown = scoreMaal(
        seenHand(shown: [trio, spadesRun, clubsRun]),
        jokers,
      );

      expect(breakdown.shownMarriages, 1);
      expect(breakdown.total, 15);
    });

    test('a longer shown sequence containing the trio is a shown marriage', () {
      final longRun = [c(Suit.hearts, Rank.five), ...trio];

      expect(maalOf(seenHand(shown: [longRun, spadesRun, clubsRun])), 15);
    });

    test('two marriages in hand = 20', () {
      expect(maalOf(seenHand(held: [...trio, ...trio])), 20);
    });

    test('one shown and one in hand = 25', () {
      expect(
        maalOf(seenHand(held: trio, shown: [trio, spadesRun, clubsRun])),
        25,
      );
    });

    test('a marriage with leftover maal scores the leftovers by count', () {
      // Trio + one more tiplu: marriage 10 + tiplu 3.
      expect(maalOf(seenHand(held: [...trio, tiplu])), 13);
    });

    test('when the cards alone score more, no marriage is counted', () {
      // 2 tiplu, 3 jhiplu, 1 poplu. Separately: 8 + 10 + 2 = 20.
      // With a marriage: 10 + tiplu 3 + jhiplu 5 + poplu 0 = 18.
      final breakdown = scoreMaal(
        seenHand(
          held: [tiplu, tiplu, jhiplu, jhiplu, jhiplu, poplu],
          drawn: jhiplu,
        ),
        jokers,
      );

      expect(breakdown.handMarriages, 0);
      expect(breakdown.total, 20);
    });
  });

  group('scoreRound', () {
    test('maal is zero-sum, then the winner collects 3 or 10', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [jhiplu, tiplu, poplu]), // maal 10, winner
          seenHand(held: [tiplu]), // maal 3
          unseenHand(held: [alter]), // unseen: maal 0
        ],
        winner: 0,
        jokers: jokers,
      );

      // Total maal 13, 3 players: 10×3 − 13 = 17, 3×3 − 13 = −4, −13.
      // Then seat 1 (seen) pays 3 and seat 2 (unseen) pays 10.
      expect(result.maal.map((m) => m.total), [10, 3, 0]);
      expect(result.net, [17 + 13, -4 - 3, -13 - 10]);
      expect(result.winner, 0);
    });

    test('net points always sum to zero', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter, alter]),
          seenHand(held: [tiplu, jhiplu]),
          unseenHand(),
          seenHand(opening: [tunnellaOf(poplu)], shown: [spadesRun, clubsRun]),
          unseenHand(held: [tiplu]),
        ],
        winner: 1,
        jokers: jokers,
      );

      expect(result.net.fold(0, (sum, n) => sum + n), 0);
    });

    test('a dublee winner collects 5 extra from every other player', () {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.three,
          Rank.four,
          Rank.five,
          Rank.nine,
          Rank.ten,
          Rank.jack,
        ])
          [c(Suit.clubs, rank), c(Suit.clubs, rank)],
      ];
      final dubleeWinner =
          PlayerHand([
              ...pairs.expand((pair) => pair),
              c(Suit.spades, Rank.king),
            ])
            ..showOpeningTunnellas([])
            ..draw(c(Suit.spades, Rank.queen))
            ..showDoublees(pairs);

      final result = scoreRound(
        hands: [dubleeWinner, seenHand(), unseenHand()],
        winner: 0,
        jokers: jokers,
      );

      // No maal anywhere: seen pays 3 + 5, unseen pays 10 + 5.
      expect(result.net, [8 + 15, -8, -15]);
      expect(result.wonWithDoublees, isTrue);
    });

    test('each joker discarded after seeing costs 15, paid to the winner', () {
      final result = scoreRound(
        hands: [seenHand(), seenHand(), unseenHand()],
        winner: 0,
        jokers: jokers,
        jokerDiscards: [0, 2, 0],
      );

      expect(result.penalties, [0, 30, 0]);
      // Seat 1 pays 3 (seen) + 30 penalty; seat 2 pays 10 (unseen).
      expect(result.net, [3 + 30 + 10, -33, -10]);
    });

    test('the winner\'s own joker discards cost nothing', () {
      final result = scoreRound(
        hands: [seenHand(), seenHand()],
        winner: 0,
        jokers: jokers,
        jokerDiscards: [3, 0],
      );

      expect(result.penalties, [0, 0]);
      expect(result.net, [3, -3]);
    });

    test('settlement with penalties still sums to zero', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter]),
          seenHand(held: [tiplu, tiplu]),
          unseenHand(),
          seenHand(held: [jhiplu, tiplu, poplu]),
        ],
        winner: 3,
        jokers: jokers,
        jokerDiscards: [1, 2, 0, 1],
      );

      expect(result.penalties, [15, 30, 0, 0]);
      expect(result.net.fold(0, (sum, n) => sum + n), 0);
    });

    test('without joker discard counts, nobody pays a penalty', () {
      final result = scoreRound(
        hands: [seenHand(), seenHand()],
        winner: 0,
        jokers: jokers,
      );

      expect(result.penalties, [0, 0]);
    });

    test('joker discard counts must cover every seat', () {
      expect(
        () => scoreRound(
          hands: [seenHand(), seenHand()],
          winner: 0,
          jokers: jokers,
          jokerDiscards: [1],
        ),
        throwsArgumentError,
      );
    });

    test('itemises each player\'s maal share and winner payment', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [jhiplu, tiplu, poplu]), // maal 10, winner
          seenHand(held: [tiplu]), // maal 3
          unseenHand(held: [alter]), // unseen: maal 0
        ],
        winner: 0,
        jokers: jokers,
        jokerDiscards: [0, 1, 0],
      );

      expect(result.maalShares, [17, -4, -13]);
      expect(result.winnerPayments, [13, -3, -10]);
      expect(result.penaltyTransfers, [15, -15, 0]);
      expect(result.sawJoker, [true, true, false]);
      expect(result.wonWithDoublees, isFalse);
      for (var seat = 0; seat < 3; seat++) {
        expect(
          result.net[seat],
          result.maalShares[seat] +
              result.winnerPayments[seat] +
              result.penaltyTransfers[seat],
          reason: 'seat $seat: the items add up to the round total',
        );
      }
    });

    test('shares, payments and penalty transfers each sum to zero', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter, alter]),
          seenHand(held: [tiplu, jhiplu]),
          unseenHand(),
          seenHand(opening: [tunnellaOf(poplu)], shown: [spadesRun, clubsRun]),
        ],
        winner: 1,
        jokers: jokers,
        jokerDiscards: [2, 0, 0, 1],
      );

      int sum(List<int> values) => values.fold(0, (a, b) => a + b);
      expect(sum(result.maalShares), 0);
      expect(sum(result.winnerPayments), 0);
      expect(sum(result.penaltyTransfers), 0);
    });

    test('the winner must have seen the joker', () {
      expect(
        () => scoreRound(
          hands: [unseenHand(), seenHand()],
          winner: 0,
          jokers: jokers,
        ),
        throwsArgumentError,
      );
    });

    test('the winner must be a seat at the table', () {
      expect(
        () => scoreRound(
          hands: [seenHand(), seenHand()],
          winner: 2,
          jokers: jokers,
        ),
        throwsArgumentError,
      );
    });
  });

  group('scoreRound: Kidnap', () {
    test('the winner takes the maal of players who haven\'t seen', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [jhiplu, tiplu, poplu]), // maal 10, winner
          seenHand(held: [tiplu]), // maal 3, keeps it
          unseenHand(held: [alter]), // 5 taken by the winner
        ],
        winner: 0,
        jokers: jokers,
        mode: GameMode.kidnap,
      );

      // Counted maal 15, 3, 0; total 18: 45 − 18 = 27, 9 − 18 = −9, −18.
      // Then seat 1 (seen) pays 3 and seat 2 (unseen) pays 10.
      expect(result.kidnapped, [0, 0, 5]);
      expect(result.maal.map((m) => m.total), [10, 3, 0]);
      expect(result.maalShares, [27, -9, -18]);
      expect(result.net, [27 + 13, -9 - 3, -18 - 10]);
    });

    test('opening tunnellas are not taken', () {
      final result = scoreRound(
        hands: [
          seenHand(),
          unseenHand(opening: [tunnellaOf(alter)], held: [tiplu]),
        ],
        winner: 0,
        jokers: jokers,
        mode: GameMode.kidnap,
      );

      // Only the tiplu (3) goes; the alter tunnella counts for nobody.
      expect(result.kidnapped, [0, 3]);
    });

    test('in Standard, unseen maal counts for nobody', () {
      final result = scoreRound(
        hands: [
          seenHand(),
          unseenHand(held: [alter]),
        ],
        winner: 0,
        jokers: jokers,
      );

      expect(result.kidnapped, [0, 0]);
      expect(result.net, [10, -10]);
    });

    test('net points always sum to zero', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter, alter]),
          seenHand(held: [tiplu, jhiplu]),
          unseenHand(held: [jhiplu, tiplu, poplu]),
          seenHand(opening: [tunnellaOf(poplu)], shown: [spadesRun, clubsRun]),
          unseenHand(opening: [tunnellaOf(alter)], held: [tiplu]),
        ],
        winner: 1,
        jokers: jokers,
        mode: GameMode.kidnap,
        jokerDiscards: [1, 0, 0, 2, 0],
      );

      expect(result.kidnapped, [0, 0, 10, 0, 3]);
      expect(result.net.fold(0, (sum, n) => sum + n), 0);
    });
  });

  group('scoreRound: Murder', () {
    test('unseen players pay 10 plus the winner\'s maal', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [jhiplu, tiplu, poplu]), // maal 10, winner
          seenHand(held: [tiplu]), // maal 3
          unseenHand(held: [alter]), // maal counts for nothing
        ],
        winner: 0,
        jokers: jokers,
        mode: GameMode.murder,
      );

      // Shares as in Standard: 17, −4, −13. Seat 1 (seen) pays 3; seat 2
      // (unseen) pays 10 + the winner's 10 maal.
      expect(result.maalShares, [17, -4, -13]);
      expect(result.winnerPayments, [23, -3, -20]);
      expect(result.net, [17 + 23, -4 - 3, -13 - 20]);
    });

    test('the extra is whatever maal the winner has', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter]), // maal 5
          unseenHand(),
        ],
        winner: 0,
        jokers: jokers,
        mode: GameMode.murder,
      );
      // The unseen player pays 10 + the winner's 5 (one alter).
      expect(result.winnerPayments, [15, -15]);
    });

    test('net points always sum to zero', () {
      final result = scoreRound(
        hands: [
          seenHand(held: [alter, alter]),
          seenHand(held: [tiplu, jhiplu]),
          unseenHand(held: [jhiplu, tiplu, poplu]),
          seenHand(opening: [tunnellaOf(poplu)], shown: [spadesRun, clubsRun]),
          unseenHand(opening: [tunnellaOf(alter)], held: [tiplu]),
        ],
        winner: 1,
        jokers: jokers,
        mode: GameMode.murder,
        jokerDiscards: [1, 0, 0, 2, 0],
      );

      expect(result.winnerPayments, [-3, 3 + 15 + 3 + 15, -15, -3, -15]);
      expect(result.net.fold(0, (sum, n) => sum + n), 0);
    });
  });

  group('MatchScore', () {
    RoundScore round(List<int> net) =>
        RoundScore(winner: 0, maal: const [], net: net);

    test('starts at 0 with everyone tied', () {
      final match = MatchScore(3);

      expect(match.totals, [0, 0, 0]);
      expect(match.rounds, isEmpty);
      expect(match.leaders, [0, 1, 2]);
    });

    test('adds each round to the running totals', () {
      final match = MatchScore(3)
        ..addRound(round([10, -4, -6]))
        ..addRound(round([-5, 12, -7]));

      expect(match.totals, [5, 8, -13]);
      expect(match.rounds.length, 2);
      expect(match.leaders, [1]);
    });

    test('reports every leader when tied', () {
      final match = MatchScore(3)..addRound(round([6, 6, -12]));

      expect(match.leaders, [0, 1]);
    });

    test('rejects a round for the wrong number of players', () {
      expect(() => MatchScore(3).addRound(round([5, -5])), throwsArgumentError);
    });
  });
}
