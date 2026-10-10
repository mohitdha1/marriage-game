import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/net/game_host.dart';
import 'package:marriage_game/net/remote_session.dart';
import 'package:marriage_game/net/wire.dart';
import 'package:marriage_game/ui/state/remote_table_controller.dart';
import 'package:marriage_game/ui/state/table_controller.dart';

const c = PlayingCard.new;

/// Opens a lobby on this computer only, on any free port.
Future<GameHost> openLobby({int seats = 3}) async {
  final host = await GameHost.open(
    hostName: 'Mohit',
    seats: seats,
    address: InternetAddress.loopbackIPv4,
    port: 0,
  );
  addTearDown(host.close);
  return host;
}

/// Joins [host] as [name] and waits for the host's answer.
Future<(RemoteSession, WireMessage)> join(GameHost host, String name) async {
  final session = await joinGame('127.0.0.1', name, port: host.port);
  addTearDown(session.close);
  final answer = await session.messages
      .firstWhere((m) => m is Welcome || m is Rejected)
      .timeout(const Duration(seconds: 5));
  return (session, answer);
}

void main() {
  test(
    'people join the lobby over the network, and everyone is told',
    () async {
      final host = await openLobby();
      final seen = <List<String>>[];
      host.changes.listen(seen.add);

      final (bina, binaAnswer) = await join(host, 'Bina');
      expect(binaAnswer, isA<Welcome>());
      final binaHears = bina.messages
          .where((m) => m is LobbyUpdate)
          .cast<LobbyUpdate>()
          .firstWhere((u) => u.names.length == 3);

      final (_, chandraAnswer) = await join(host, 'Chandra');
      expect(chandraAnswer, isA<Welcome>());

      final lobby = await binaHears.timeout(const Duration(seconds: 5));
      expect(lobby.names, ['Mohit', 'Bina', 'Chandra']);
      expect(lobby.seats, 3);
      expect(host.names, ['Mohit', 'Bina', 'Chandra']);
      expect(seen.last, ['Mohit', 'Bina', 'Chandra']);
    },
  );

  test('a full table turns newcomers away', () async {
    final host = await openLobby(seats: 2);
    await join(host, 'Bina');

    final (_, answer) = await join(host, 'Chandra');

    expect(answer, isA<Rejected>());
    expect((answer as Rejected).reason, 'The table is full.');
  });

  test('a name already taken gets a number', () async {
    final host = await openLobby();
    await join(host, 'Mohit');

    expect(host.names, ['Mohit', 'Mohit 2']);
  });

  test('someone leaving the lobby frees their place', () async {
    final host = await openLobby();
    final (bina, _) = await join(host, 'Bina');
    final left = host.changes.firstWhere((names) => names.length == 1);

    await bina.close();

    expect(await left.timeout(const Duration(seconds: 5)), ['Mohit']);
  });

  test('the table can grow, but not shrink below who has joined', () async {
    final host = await openLobby();
    await join(host, 'Bina');
    await join(host, 'Chandra');

    host.resize(2);
    expect(host.seats, 3);
    host.resize(5);
    expect(host.seats, 5);
  });

  test('once the game starts, the guests are handed over and nobody else '
      'gets in', () async {
    final host = await openLobby();
    await join(host, 'Bina');

    final guests = host.start();
    expect(guests.keys, [1]);
    expect(guests[1]!.name, 'Bina');

    final (_, late) = await join(host, 'Chandra');
    expect((late as Rejected).reason, 'The game has already started.');
  });

  test('a whole turn is played over real sockets', () async {
    final lobby = await openLobby(seats: 2);
    final (session, _) = await join(lobby, 'Bina');
    final guests = lobby.start();

    final host = ProviderContainer(
      overrides: [
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        roundFactoryProvider.overrideWithValue(
          (seat) => Round.fromCards(
            config: GameConfig(playerCount: 2),
            random: Random(0),
            hands: [
              [c(Suit.spades, Rank.king), c(Suit.hearts, Rank.two)],
              [c(Suit.clubs, Rank.four), c(Suit.diamonds, Rank.nine)],
            ],
            stock: [c(Suit.clubs, Rank.five), c(Suit.hearts, Rank.seven)],
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
            remote: {
              for (final MapEntry(key: seat, value: guest) in guests.entries)
                seat: RemotePlayer(
                  name: guest.name,
                  connection: guest.connection,
                ),
            },
          ),
        );
    host.read(tableProvider);
    await session.firstUpdate.timeout(const Duration(seconds: 5));

    final guest = ProviderContainer(
      overrides: [
        remoteSessionProvider.overrideWithValue(session),
        tableProvider.overrideWith(RemoteTableController.new),
      ],
    );
    addTearDown(guest.dispose);
    expect(guest.read(tableProvider).view.you.name, 'Bina');

    // Mohit plays; Bina's device hears about it across the network.
    final hostTable = host.read(tableProvider.notifier)..draw(DrawSource.stock);
    final yourTurn = session.messages
        .where((m) => m is SeatUpdate)
        .cast<SeatUpdate>()
        .firstWhere((u) => u.view.isYourTurn);
    await hostTable.discard(host.read(tableProvider).hand.first.id);
    await yourTurn.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);

    expect(guest.read(tableProvider).view.isYourTurn, isTrue);
    expect(
      guest.read(tableProvider).view.topDiscard,
      c(Suit.spades, Rank.king),
    );
  });

  test('this device\'s address, if on a network, is a private one', () async {
    final address = await localAddress();
    if (address != null) {
      expect(address, matches(RegExp(r'^(10|172|192)\.')));
    }
  });
}
