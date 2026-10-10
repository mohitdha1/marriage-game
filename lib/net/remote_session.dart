import 'dart:async';

import 'connection.dart';
import 'wire.dart';

/// A joining device's link to the game's host. It listens from the moment
/// the device connects, so nothing the host sends is missed while screens
/// change: it keeps the host's latest look at the table, and passes every
/// message on to whoever listens to [messages].
class RemoteSession {
  RemoteSession(this.connection) {
    _listening = connection.messages.listen((message) {
      if (message is SeatUpdate) {
        latest = message;
        if (!_firstUpdate.isCompleted) _firstUpdate.complete(message);
      }
      _messages.add(message);
    }, onDone: _messages.close);
  }

  final Connection connection;
  late final StreamSubscription<WireMessage> _listening;
  final _messages = StreamController<WireMessage>.broadcast();
  final _firstUpdate = Completer<SeatUpdate>();

  /// The host's latest look at the table, once the game has started.
  SeatUpdate? latest;

  /// Everything the host sends from now on.
  Stream<WireMessage> get messages => _messages.stream;

  /// Completes with the host's first look at the table, when the game
  /// starts.
  Future<SeatUpdate> get firstUpdate => _firstUpdate.future;

  void send(WireMessage message) => connection.send(message);

  Future<void> close() async {
    await _listening.cancel();
    await connection.close();
  }
}
