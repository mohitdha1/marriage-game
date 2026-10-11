import 'dart:async';

import 'connection.dart';
import 'wire.dart';

/// A joining device's link to the game's host. It listens from the moment
/// the device connects, so nothing the host sends is missed while screens
/// change: it keeps the host's latest look at the table, and passes every
/// message on to whoever listens to [messages].
///
/// If the link drops once the game has started, it keeps trying to come
/// back with [reconnect], presenting the token the host gave when the
/// player joined, so they take their seat again. [messages] only ends if it
/// gives up, or the session is closed.
class RemoteSession {
  RemoteSession(
    Connection connection, {
    this.name = '',
    this.reconnect,
    this.retryEvery = const Duration(seconds: 2),
    this.giveUpAfter = const Duration(minutes: 2),
  }) {
    _attach(connection);
  }

  /// The player's name, for introducing them again after a drop.
  final String name;

  /// Opens a new link to the same host, or `null` to never come back.
  final Future<Connection> Function()? reconnect;

  final Duration retryEvery;
  final Duration giveUpAfter;

  late Connection _connection;
  StreamSubscription<WireMessage>? _listening;
  final _messages = StreamController<WireMessage>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  final _firstUpdate = Completer<SeatUpdate>();
  String? _token;
  var _closed = false;

  /// Whether the host turned the player away, so there's no coming back.
  var _refused = false;

  /// The host's latest look at the table, once the game has started.
  SeatUpdate? latest;

  /// Everything the host sends from now on.
  Stream<WireMessage> get messages => _messages.stream;

  /// `false` when the link drops and the session starts trying to come
  /// back; `true` once it has.
  Stream<bool> get connectionChanges => _connected.stream;

  /// Completes with the host's first look at the table, when the game
  /// starts.
  Future<SeatUpdate> get firstUpdate => _firstUpdate.future;

  void _attach(Connection connection) {
    _connection = connection;
    _listening = connection.messages.listen((message) {
      switch (message) {
        case Welcome(:final token):
          _token = token;
        case SeatUpdate():
          latest = message;
          if (!_firstUpdate.isCompleted) _firstUpdate.complete(message);
        case Rejected():
          _refused = true;
        case _:
          break;
      }
      _messages.add(message);
    }, onDone: _onDropped);
  }

  Future<void> _onDropped() async {
    if (_closed) return;
    final token = _token;
    // Only a game under way can be rejoined; a lobby is simply left.
    if (reconnect == null || token == null || latest == null || _refused) {
      await _end();
      return;
    }
    _connected.add(false);
    final deadline = DateTime.now().add(giveUpAfter);
    while (!_closed && DateTime.now().isBefore(deadline)) {
      try {
        final connection = await reconnect!();
        if (_closed) {
          await connection.close();
          return;
        }
        _attach(connection);
        connection.send(Hello(name, token: token));
        _connected.add(true);
        return;
      } on Object {
        await Future<void>.delayed(retryEvery);
      }
    }
    await _end();
  }

  Future<void> _end() async {
    if (!_messages.isClosed) await _messages.close();
    if (!_connected.isClosed) await _connected.close();
  }

  void send(WireMessage message) => _connection.send(message);

  Future<void> close() async {
    _closed = true;
    await _listening?.cancel();
    await _connection.close();
    await _end();
  }
}
