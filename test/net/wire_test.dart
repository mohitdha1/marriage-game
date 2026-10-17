import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/hand_arrangement.dart';
import 'package:marriage_game/engine/player_hand.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/engine/scoring.dart';
import 'package:marriage_game/engine/table_event.dart';
import 'package:marriage_game/net/wire.dart';
import 'package:marriage_game/ui/state/table_view.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

/// [message] sent as text and read back.
WireMessage sentAndRead(WireMessage message) => WireMessage.fromJson(
  jsonDecode(jsonEncode(message.toJson())) as Map<String, Object?>,
);

/// Asserts [message] reads back to a message with exactly the same JSON.
void expectRoundTrip(WireMessage message) {
  final back = sentAndRead(message);
  expect(back.runtimeType, message.runtimeType);
  expect(jsonEncode(back.toJson()), jsonEncode(message.toJson()));
}

/// A round some way in: Asha has shown three runs and seen the joker (7♥),
/// and everyone has drawn and discarded.
Round playedRound() {
  final hearts = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
  final spades = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
  final clubs = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
  final round = Round.fromCards(
    config: GameConfig(playerCount: 2),
    random: Random(0),
    hands: [
      [
        ...hearts,
        ...spades,
        ...clubs,
        c(Suit.spades, Rank.king),
        c(Suit.diamonds, Rank.two),
      ],
      run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]),
    ],
    stock: [
      c(Suit.clubs, Rank.five),
      c(Suit.hearts, Rank.seven),
      c(Suit.clubs, Rank.two),
      c(Suit.diamonds, Rank.queen),
    ],
    discardPile: [c(Suit.clubs, Rank.king)],
  );
  round
    ..showOpeningTunnellas(0, [])
    ..showOpeningTunnellas(1, [])
    ..draw(DrawSource.stock)
    ..showPureSets([hearts, spades, clubs], tipluPosition: 1)
    ..discard(c(Suit.spades, Rank.king))
    ..draw(DrawSource.discardPile)
    ..discard(c(Suit.spades, Rank.six));
  return round;
}

void main() {
  group('Every message reads back as sent', () {
    test('joining', () {
      expectRoundTrip(const Hello('Asha'));
      expectRoundTrip(const Hello('Asha', token: '9f3a'));
      expectRoundTrip(const Welcome(2, token: '9f3a'));
      expectRoundTrip(const LobbyUpdate(names: ['Asha', 'Bina'], seats: 4));
      expectRoundTrip(const Rejected('The game is full.'));
      expectRoundTrip(const Refused('Wait for Bina to play.'));
    });

    test('moves', () {
      expectRoundTrip(const MoveDraw(DrawSource.discardPile));
      expectRoundTrip(MoveDiscard(c(Suit.hearts, Rank.ten)));
      expectRoundTrip(
        MoveOpenTunnellas([
          [
            c(Suit.clubs, Rank.two),
            c(Suit.clubs, Rank.two),
            c(Suit.clubs, Rank.two),
          ],
        ]),
      );
      expectRoundTrip(
        MoveShow(
          kind: ShowKind.pureSets,
          sets: [
            run(Suit.hearts, [Rank.three, Rank.four, Rank.five]),
          ],
          tipluPosition: 3,
        ),
      );
      expectRoundTrip(
        MoveShow(
          kind: ShowKind.doublees,
          sets: [
            [c(Suit.spades, Rank.ace), c(Suit.spades, Rank.ace)],
          ],
        ),
      );
      expectRoundTrip(MoveWin(c(Suit.diamonds, Rank.two)));
      expectRoundTrip(const MoveDiscard(PlayingCard.man()));
      expectRoundTrip(const MoveDiscard(PlayingCard.superman()));
      expectRoundTrip(const MovePickTiplu(4));
    });

    test('a seat update from a real round, with every kind of event', () {
      final round = playedRound();
      final view = TableView.fromRound(
        round,
        humanSeat: 0,
        nameOf: (seat) => ['Asha', 'Bina'][seat],
        avatarOf: (seat) => seat == 1 ? 0xFF90CAF9 : null,
      );
      final update = SeatUpdate(
        view: view,
        handProgress: handProgress(round.hands[0], round.jokersFor(0)),
        winningCards: [c(Suit.diamonds, Rank.two)],
        roundNumber: 3,
        seatNames: const ['Asha', 'Bina'],
        roundScores: [
          RoundScore(
            winner: 1,
            maal: const [
              MaalBreakdown(tiplu: 3, shownMarriages: 1, man: 5, superman: 5),
              MaalBreakdown(),
            ],
            net: const [-7, 7],
            maalShares: const [3, -3],
            winnerPayments: const [-10, 10],
            sawJoker: const [true, false],
            kidnapped: const [0, 4],
            setsShown: const [3, 1],
            wonWithDoublees: true,
          ),
        ],
        totals: const [-7, 7],
        jokerPenalty: true,
        mode: GameMode.murder,
      );

      expectRoundTrip(update);
      final back = sentAndRead(update) as SeatUpdate;
      expect(back.view.hand, view.hand);
      expect(back.view.yourJokers?.tiplu, c(Suit.hearts, Rank.seven));
      expect(back.view.opponents.single.lastDiscard, c(Suit.spades, Rank.six));
      expect(back.view.you.laidDown, hasLength(3));
      expect(back.view.events.map((e) => e.runtimeType), [
        DrewCard,
        ShowedSets,
        DiscardedCard,
        DrewCard,
        DiscardedCard,
      ]);
      expect(back.handProgress, isA<WinProgress>());
      expect(back.roundScores.single.maal.first.shownMarriages, 1);
      expect(back.roundScores.single.maal.first.man, 5);
      expect(back.roundScores.single.maal.first.superman, 5);
      expect(back.roundScores.single.kidnapped, [0, 4]);
      expect(back.roundScores.single.setsShown, [3, 1]);
      expect(back.mode, GameMode.murder);
    });

    test('every kind of hand progress', () {
      for (final progress in const [
        ShowProgress(pureSets: 1, pureSetsNeeded: 3, doublees: 4),
        WinProgress(setsMade: 5, unmatched: 2, setsToWin: 1, maal: 6),
        DubleeProgress(doublees: 7, maal: 1),
        null,
      ]) {
        final round = playedRound();
        expectRoundTrip(
          SeatUpdate(
            view: TableView.fromRound(round, humanSeat: 1, nameOf: (s) => '$s'),
            handProgress: progress,
            winningCards: const [],
            roundNumber: 1,
            seatNames: const ['0', '1'],
            roundScores: const [],
            totals: const [0, 0],
            jokerPenalty: false,
          ),
        );
      }
    });

    test('the events a round can hold that the played round doesn\'t', () {
      for (final event in [
        OpenedTunnellas(1, [
          [
            c(Suit.clubs, Rank.two),
            c(Suit.clubs, Rank.two),
            c(Suit.clubs, Rank.two),
          ],
        ]),
        WonRound(0, c(Suit.diamonds, Rank.two)),
        const StockReshuffled(1),
        const KeptAside(0, PlayingCard.man()),
      ]) {
        final back = eventFromJson(
          jsonDecode(jsonEncode(eventToJson(event))) as Map<String, Object?>,
        );
        expect(jsonEncode(eventToJson(back)), jsonEncode(eventToJson(event)));
      }
    });
  });

  group('Garbled messages', () {
    test('an unknown type is refused', () {
      expect(
        () => WireMessage.fromJson({'type': 'teleport'}),
        throwsFormatException,
      );
    });

    test('a missing field is refused rather than crashing', () {
      expect(
        () => WireMessage.fromJson({'type': 'hello'}),
        throwsFormatException,
      );
      expect(
        () => WireMessage.fromJson({'type': 'discard', 'card': 'joker.moon'}),
        throwsFormatException,
      );
    });
  });

  test('a seat update shows only that player\'s own cards', () {
    final round = playedRound();
    final json = jsonEncode(
      tableViewToJson(
        TableView.fromRound(round, humanSeat: 1, nameOf: (s) => '$s'),
      ),
    );

    // Asha still holds 2♦; it must not appear anywhere in Bina's view.
    expect(round.hands[0].cards, contains(c(Suit.diamonds, Rank.two)));
    expect(json, isNot(contains(cardToJson(c(Suit.diamonds, Rank.two)))));
  });
}
