import 'dart:async';

import 'wire.dart';

/// One end of a link between the host and a joining phone: messages go out
/// with [send] and arrive on [messages].
abstract interface class Connection {
  Stream<WireMessage> get messages;

  void send(WireMessage message);

  /// Closes the link; [messages] then ends at both ends.
  Future<void> close();
}

/// Two connected ends that pass messages in memory, for tests. Messages go
/// through JSON on the way, as they would over the network, so anything
/// that wouldn't survive the wire fails here too.
class InMemoryConnection implements Connection {
  InMemoryConnection._(this._incoming, this._outgoing);

  /// A pair of linked ends: what one sends, the other receives.
  static (InMemoryConnection, InMemoryConnection) pair() {
    final aToB = StreamController<WireMessage>();
    final bToA = StreamController<WireMessage>();
    return (InMemoryConnection._(bToA, aToB), InMemoryConnection._(aToB, bToA));
  }

  final StreamController<WireMessage> _incoming;
  final StreamController<WireMessage> _outgoing;

  @override
  Stream<WireMessage> get messages => _incoming.stream;

  @override
  void send(WireMessage message) {
    if (_outgoing.isClosed) return;
    _outgoing.add(WireMessage.fromJson(message.toJson()));
  }

  @override
  Future<void> close() async {
    await _outgoing.close();
    await _incoming.close();
  }
}
