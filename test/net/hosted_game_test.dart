import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/net/connection.dart';
import 'package:marriage_game/net/game_host.dart' show Rejoin;
import 'package:marriage_game/net/remote_session.dart';
import 'package:marriage_game/net/wire.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/state/remote_table_controller.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_notifier.dart';
import 'package:marriage_game/ui/state/table_state.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

final hearts = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
final spades = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
final clubs = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
final twoOfDiamonds = c(Suit.diamonds, Rank.two);

/// Mohit's cards (the host, seat 0).
final mohitsCards = [
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
];

/// Bina's cards (on another device, seat 1): after drawing Q♦ she can show
/// three runs, see the joker (7♥) and win by discarding 2♦.
final binasCards = [
  ...hearts,
  ...spades,
  ...clubs,
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.ten),
  c(Suit.diamonds, Rank.jack),
  c(Suit.hearts, Rank.eight),
  twoOfDiamonds,
];

final idleBotCards = run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]);

/// A host device and one joined device, linked in memory.
class Game {
  Game._(this.host, this.guest, this.session);

  final ProviderContainer host;
  final ProviderContainer guest;
  final RemoteSession session;

  /// Mohit hosts with Bina joined at seat 1, and a bot at any seat after.
  static Future<Game> start({
    List<List<PlayingCard>>? hands,
    List<PlayingCard>? stock,
    Stream<Rejoin>? rejoins,
  }) async {
    final (hostEnd, guestEnd) = InMemoryConnection.pair();
    final dealt = hands ?? [mohitsCards, binasCards];
    final host = ProviderContainer(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: dealt.length),
            random: Random(0),
            hands: dealt,
            stock:
                stock ??
                [
                  c(Suit.clubs, Rank.five),
                  c(Suit.hearts, Rank.seven),
                  c(Suit.clubs, Rank.two),
                  c(Suit.diamonds, Rank.queen),
                ],
            discardPile: [c(Suit.clubs, Rank.king)],
            firstSeat: seat,
          ),
        ),
      ],
    );
    addTearDown(host.dispose);
    host
        .read(matchSetupProvider.notifier)
        .choose(
          MatchSetup.hosted(
            hostName: 'Mohit',
            playerCount: dealt.length,
            remote: {1: RemotePlayer(name: 'Bina', connection: hostEnd)},
            rejoins: rejoins,
          ),
        );

    final session = RemoteSession(guestEnd);
    host.read(tableProvider);
    await session.firstUpdate;

    final guest = ProviderContainer(
      overrides: [
        remoteSessionProvider.overrideWithValue(session),
        tableProvider.overrideWith(RemoteTableController.new),
      ],
    );
    addTearDown(guest.dispose);
    guest.read(tableProvider);
    return Game._(host, guest, session);
  }

  TableNotifier get hostTable => host.read(tableProvider.notifier);
  TableNotifier get guestTable => guest.read(tableProvider.notifier);
  TableState get hostState => host.read(tableProvider);
  TableState get guestState => guest.read(tableProvider);

  int guestIdOf(PlayingCard card) =>
      guestState.hand.firstWhere((h) => h.card == card).id;

  /// Lets messages cross the link and anything they set off finish.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('the joined device sees its own seat, cards and names', () async {
    final game = await Game.start();

    final view = game.guestState.view;
    expect(view.you.seat, 1);
    expect(view.you.name, 'Bina');
    expect(view.hand, binasCards);
    // Shown sorted by suit (♠ ♥ ♣ ♦), then rank, as dealt.
    final suits = [for (final h in game.guestState.hand) h.card.suit];
    expect(
      suits,
      [...suits]..sort(
        (a, b) => TableNotifier.sortedSuits
            .indexOf(a)
            .compareTo(TableNotifier.sortedSuits.indexOf(b)),
      ),
    );
    expect(view.opponents.single.name, 'Mohit');
    expect(game.guestState.seatNames, ['Mohit', 'Bina']);
    expect(game.hostState.view.opponents.single.name, 'Bina');
  });

  test('turns pass both ways across the link', () async {
    final game = await Game.start();

    // Mohit plays.
    game.hostTable.draw(DrawSource.stock);
    await game.hostTable.discard(
      game.hostState.hand.firstWhere((h) => h.card == mohitsCards.first).id,
    );
    await game.settle();
    expect(game.guestState.view.isYourTurn, isTrue);
    expect(game.guestState.view.topDiscard, mohitsCards.first);
    expect(game.hostState.view.isYourTurn, isFalse);

    // Bina takes Mohit's discard and throws 2♦.
    game.guestTable.draw(DrawSource.discardPile);
    await game.settle();
    expect(
      game.guestState.hand.map((h) => h.card),
      contains(mohitsCards.first),
    );
    await game.guestTable.discard(game.guestIdOf(twoOfDiamonds));
    await game.settle();

    expect(game.hostState.view.isYourTurn, isTrue);
    expect(game.hostState.view.topDiscard, twoOfDiamonds);
    expect(game.guestState.view.isYourTurn, isFalse);
  });

  test('a move out of turn is refused, with the reason', () async {
    final game = await Game.start();

    // It's Mohit's turn; Bina's phone won't even send the draw.
    game.guestTable.draw(DrawSource.stock);
    expect(game.guestState.notice, 'Wait for Mohit to play.');

    // A move the engine refuses comes back from the host.
    game.hostTable.draw(DrawSource.stock);
    await game.hostTable.discard(game.hostState.hand.first.id);
    await game.settle();
    game.guestTable.draw(DrawSource.discardPile);
    await game.settle();
    // The card just taken from the pile can't be thrown straight back.
    await game.guestTable.discard(game.guestIdOf(mohitsCards.first));
    await game.settle();
    expect(game.guestState.notice, contains('must be kept this turn'));
    expect(game.guestState.view.youHaveDrawn, isTrue);
  });

  test('nothing the host sends holds the host\'s cards', () async {
    final (hostEnd, guestEnd) = InMemoryConnection.pair();
    final sent = <String>[];
    guestEnd.messages.listen((m) => sent.add(jsonEncode(m.toJson())));
    final host = ProviderContainer(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [mohitsCards, idleBotCards],
            stock: [c(Suit.clubs, Rank.five)],
            discardPile: [c(Suit.clubs, Rank.king)],
          ),
        ),
      ],
    );
    addTearDown(host.dispose);
    host
        .read(matchSetupProvider.notifier)
        .choose(
          MatchSetup.hosted(
            hostName: 'Mohit',
            playerCount: 2,
            remote: {1: RemotePlayer(name: 'Bina', connection: hostEnd)},
          ),
        );
    host.read(tableProvider);
    await Future<void>.delayed(Duration.zero);

    expect(sent, isNotEmpty);
    for (final message in sent) {
      for (final card in mohitsCards) {
        expect(message, isNot(contains(cardToJson(card))), reason: '$card');
      }
    }
  });

  test('bots fill seats nobody joined', () async {
    final game = await Game.start(
      hands: [mohitsCards, binasCards, idleBotCards],
      stock: [for (var i = 0; i < 6; i++) c(Suit.clubs, Rank.five)],
    );
    expect(game.hostState.seatNames[2], isNot(anyOf('Mohit', 'Bina')));

    game.hostTable.draw(DrawSource.stock);
    await game.hostTable.discard(game.hostState.hand.first.id);
    await game.settle();
    game.guestTable.draw(DrawSource.stock);
    await game.settle();
    await game.guestTable.discard(game.guestIdOf(twoOfDiamonds));
    await game.settle();
    await game.hostTable.botsSettled;
    await game.settle();

    // The bot has played its turn, and it's Mohit's again.
    expect(game.hostState.view.isYourTurn, isTrue);
    expect(game.hostState.view.events.where((e) => e.seat == 2), isNotEmpty);
  });

  test(
    'someone dealt more than 3 tunnellas chooses on their own device',
    () async {
      final four = [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king]) ...[
          c(Suit.clubs, rank),
          c(Suit.clubs, rank),
          c(Suit.clubs, rank),
        ],
      ];
      final game = await Game.start(hands: [mohitsCards, four]);

      expect(game.guestState.openingChoice, hasLength(4));
      game.hostTable.draw(DrawSource.stock);
      expect(
        game.hostState.notice,
        'Every player must make their opening show first',
      );

      game.guestTable.chooseOpeningTunnellas([0, 1, 2]);
      await game.settle();
      expect(game.guestState.openingChoice, isNull);
      expect(game.guestState.view.you.laidDown, hasLength(3));

      game.hostTable.draw(DrawSource.stock);
      expect(game.hostState.view.youHaveDrawn, isTrue);
    },
  );

  test(
    'a win on the joined device is everyone\'s news; coins stay put',
    () async {
      final game = await Game.start();
      final coins = (await game.host.read(playerDataProvider.future)).coins;
      // Mohit takes K♣ from the pile, leaving Q♦ on the stock for Bina, and
      // throws K♠.
      game.hostTable.draw(DrawSource.discardPile);
      await game.hostTable.discard(
        game.hostState.hand
            .firstWhere((h) => h.card == c(Suit.spades, Rank.king))
            .id,
      );
      await game.settle();

      // Bina draws Q♦, groups and shows her runs, picks 7♥, and wins on 2♦.
      final guest = game.guestTable..draw(DrawSource.stock);
      await game.settle();
      for (final set in [hearts, spades, clubs]) {
        final used = <int>{};
        for (final card in set) {
          final id = game.guestState.hand
              .firstWhere((h) => h.card == card && !used.contains(h.id))
              .id;
          used.add(id);
          guest.toggleSelected(id);
        }
        guest.groupSelected();
      }
      guest.showGroups();
      expect(game.guestState.pickingTiplu, isTrue);
      guest.pickTiplu(1);
      await game.settle();
      expect(game.guestState.revealingJoker, isTrue);
      expect(game.guestState.groups, isEmpty);
      expect(game.guestState.view.youHaveSeenJoker, isTrue);

      guest
        ..dismissReveal()
        ..toggleSelected(game.guestIdOf(twoOfDiamonds))
        ..declareWin();
      await game.settle();

      expect(game.guestState.notice, 'You won the round!');
      expect(game.hostState.notice, 'Bina won the round.');
      expect(game.guestState.roundScores, hasLength(1));
      expect(game.hostState.roundScores.single.winner, 1);
      await Future<void>.delayed(Duration.zero);
      final hostData = await game.host.read(playerDataProvider.future);
      final guestData = await game.guest.read(playerDataProvider.future);
      expect(hostData.coins, coins);
      // Both devices count the round: a win for Bina, a loss for Mohit.
      expect(guestData.stats.roundsWon, 1);
      expect(hostData.stats.roundsPlayed, 1);
      expect(hostData.stats.roundsWon, 0);

      // Only the host deals the next round.
      expect(game.guestTable.dealsRounds, isFalse);
      // Only the host can start the match again.
      expect(game.guestTable.canStartNewMatch, isFalse);
      expect(game.hostTable.canStartNewMatch, isTrue);
      game.guestTable.startNextRound();
      expect(game.guestState.notice, 'The host deals the next round.');
      game.hostTable.startNextRound();
      await game.settle();
      expect(game.guestState.roundNumber, 2);
      expect(game.guestState.groups, isEmpty);

      // A new match: the joined device starts afresh too, though the
      // rounds count from 1 again.
      game.guestTable.toggleSelected(game.guestState.hand.first.id);
      game.hostTable.startNewMatch();
      game.host.read(tableProvider);
      await game.settle();
      expect(game.guestState.roundNumber, 1);
      expect(game.guestState.roundScores, isEmpty);
      expect(game.guestState.totals, everyElement(0));
      expect(game.guestState.selected, isEmpty);
    },
  );

  group('A player whose link drops', () {
    test('mid-turn: the host says so, and a bot finishes their turn', () async {
      // Bina holds an ordinary hand, so the bot doesn't simply win.
      final game = await Game.start(hands: [mohitsCards, idleBotCards]);
      game.hostTable.draw(DrawSource.stock);
      await game.hostTable.discard(game.hostState.hand.first.id);
      await game.settle();
      game.guestTable.draw(DrawSource.stock);
      await game.settle();
      expect(game.hostState.view.isYourTurn, isFalse);

      await game.session.close();
      await game.settle();
      await game.hostTable.botsSettled;
      await game.settle();

      expect(
        game.hostState.notice,
        'Bina lost connection. A bot plays for them until they\'re back.',
      );
      expect(game.hostState.offlineSeats, {1});
      // The bot finished Bina's turn without drawing again: she holds as
      // many cards as before her draw.
      expect(game.hostState.view.isYourTurn, isTrue);
      expect(
        game.hostState.view.opponents.single.cardCount,
        idleBotCards.length,
      );
    });

    test(
      'they can come back: the bot steps aside and the table knows',
      () async {
        final rejoins = StreamController<Rejoin>.broadcast(sync: true);
        addTearDown(rejoins.close);
        final game = await Game.start(
          hands: [mohitsCards, idleBotCards],
          rejoins: rejoins.stream,
        );
        await game.session.close();
        await game.settle();
        expect(game.hostState.offlineSeats, {1});

        // Bina's phone reconnects on a new link.
        final (hostEnd, guestEnd) = InMemoryConnection.pair();
        final back = RemoteSession(guestEnd);
        addTearDown(back.close);
        rejoins.add((seat: 1, connection: hostEnd));
        await game.settle();

        expect(game.hostState.notice, 'Bina is back.');
        expect(game.hostState.offlineSeats, isEmpty);
        expect(back.latest!.view.you.seat, 1);
        expect(back.latest!.offline, isEmpty);

        // It's her turn after Mohit's, and no bot takes it.
        game.hostTable.draw(DrawSource.stock);
        await game.hostTable.discard(game.hostState.hand.first.id);
        await game.hostTable.botsSettled;
        await game.settle();
        expect(game.hostState.view.currentSeat, 1);
        expect(back.latest!.view.isYourTurn, isTrue);

        // A new match reaches her on the new link.
        final firstMatch = back.latest!.match;
        game.hostTable.startNewMatch();
        game.host.read(tableProvider);
        await game.settle();
        expect(back.latest!.match, isNot(firstMatch));
      },
    );

    test('between turns: the bot plays when their turn comes', () async {
      final game = await Game.start();
      await game.session.close();
      await game.settle();

      game.hostTable.draw(DrawSource.stock);
      await game.hostTable.discard(game.hostState.hand.first.id);
      await game.hostTable.botsSettled;
      await game.settle();

      expect(game.hostState.view.isYourTurn, isTrue);
      expect(game.hostState.view.events.where((e) => e.seat == 1), isNotEmpty);
    });

    test(
      'while choosing their opening: the bot opens with the first three',
      () async {
        final four = [
          for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king]) ...[
            c(Suit.clubs, rank),
            c(Suit.clubs, rank),
            c(Suit.clubs, rank),
          ],
        ];
        final game = await Game.start(hands: [mohitsCards, four]);
        expect(game.guestState.openingChoice, isNotNull);

        await game.session.close();
        await game.settle();

        expect(game.hostState.view.opponents.single.laidDown, hasLength(3));
        game.hostTable.draw(DrawSource.stock);
        expect(game.hostState.view.youHaveDrawn, isTrue);
      },
    );
  });

  test('a garbled or unexpected message from a guest is ignored', () async {
    final game = await Game.start();
    game.session.send(const Hello('Bina again'));
    game.session.send(const Welcome(3, token: 'nope'));
    await game.settle();

    expect(game.hostState.view.isYourTurn, isTrue);
    unawaited(game.session.close());
  });
}
