import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/net/connection.dart';
import 'package:marriage_game/net/remote_session.dart';
import 'package:marriage_game/net/wire.dart';
import 'package:marriage_game/ui/state/table_view.dart';

const c = PlayingCard.new;

/// A look at a small table, as the host would send it.
SeatUpdate anUpdate() {
  final round = Round.fromCards(
    config: GameConfig(playerCount: 2),
    random: Random(0),
    hands: [
      [c(Suit.spades, Rank.king)],
      [c(Suit.clubs, Rank.four)],
    ],
    stock: [c(Suit.clubs, Rank.five)],
    discardPile: [c(Suit.clubs, Rank.king)],
  );
  return SeatUpdate(
    view: TableView.fromRound(round, humanSeat: 1, nameOf: (s) => '$s'),
    handProgress: null,
    winningCards: const [],
    roundNumber: 1,
    seatNames: const ['0', '1'],
    roundScores: const [],
    totals: const [0, 0],
    jokerPenalty: true,
  );
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a dropped link mid-game comes back with the token, and messages '
      'carry on', () async {
    final (firstHostEnd, firstGuestEnd) = InMemoryConnection.pair();
    final (secondHostEnd, secondGuestEnd) = InMemoryConnection.pair();
    final heardAgain = <WireMessage>[];
    secondHostEnd.messages.listen(heardAgain.add);

    final session = RemoteSession(
      firstGuestEnd,
      name: 'Bina',
      reconnect: () async => secondGuestEnd,
      retryEvery: Duration.zero,
    );
    addTearDown(session.close);
    final heard = <WireMessage>[];
    final changes = <bool>[];
    session.messages.listen(heard.add);
    session.connectionChanges.listen(changes.add);

    firstHostEnd
      ..send(const Welcome(1, token: 'bina-token'))
      ..send(anUpdate());
    await settle();

    await firstHostEnd.close();
    await settle();

    expect(changes, [false, true]);
    final hello = heardAgain.single as Hello;
    expect(hello.name, 'Bina');
    expect(hello.token, 'bina-token');

    // The host's messages keep arriving on the same stream.
    secondHostEnd.send(const Refused('Wait for Mohit to play.'));
    await settle();
    expect(heard.last, isA<Refused>());
  });

  test('it gives up once the time is up, ending the messages', () async {
    final (hostEnd, guestEnd) = InMemoryConnection.pair();
    final session = RemoteSession(
      guestEnd,
      name: 'Bina',
      reconnect: () async => throw const SocketishFailure(),
      retryEvery: const Duration(milliseconds: 5),
      giveUpAfter: const Duration(milliseconds: 30),
    );
    final ended = Completer<void>();
    session.messages.listen((_) {}, onDone: ended.complete);
    hostEnd
      ..send(const Welcome(1, token: 't'))
      ..send(anUpdate());
    await settle();

    await hostEnd.close();

    await ended.future.timeout(const Duration(seconds: 2));
  });

  test('a link that drops in the lobby isn\'t retried', () async {
    final (hostEnd, guestEnd) = InMemoryConnection.pair();
    var tries = 0;
    final session = RemoteSession(
      guestEnd,
      reconnect: () async {
        tries++;
        throw const SocketishFailure();
      },
    );
    final ended = Completer<void>();
    session.messages.listen((_) {}, onDone: ended.complete);
    hostEnd.send(const Welcome(1, token: 't'));
    await settle();

    await hostEnd.close();
    await ended.future.timeout(const Duration(seconds: 2));

    expect(tries, 0);
  });
}

class SocketishFailure implements Exception {
  const SocketishFailure();
}
