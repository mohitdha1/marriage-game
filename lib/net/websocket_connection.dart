import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'connection.dart';
import 'wire.dart';

/// A [Connection] over a WebSocket on the local network. Messages travel as
/// JSON text; anything that doesn't read as a message is dropped rather
/// than breaking the game.
class WebSocketConnection implements Connection {
  WebSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  late final Stream<WireMessage> messages = _socket
      .where((data) => data is String)
      .map((data) {
        try {
          return WireMessage.fromJson(
            jsonDecode(data as String) as Map<String, Object?>,
          );
        } on FormatException {
          return null;
        } on TypeError {
          return null;
        }
      })
      .where((message) => message != null)
      .cast<WireMessage>()
      .handleError((Object _) {}, test: (e) => e is SocketException)
      // Host and lobby listen in turn, so more than one listener is fine.
      .asBroadcastStream();

  @override
  void send(WireMessage message) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(jsonEncode(message.toJson()));
    }
  }

  @override
  Future<void> close() => _socket.close();
}
