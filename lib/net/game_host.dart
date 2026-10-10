import 'dart:async';
import 'dart:io';

import 'connection.dart';
import 'remote_session.dart';
import 'room_code.dart';
import 'websocket_connection.dart';
import 'wire.dart';

/// Someone who has joined the lobby from another device.
class Guest {
  Guest(this.name, this.connection);

  final String name;
  final Connection connection;

  /// Watches for the guest leaving while still in the lobby.
  StreamSubscription<WireMessage>? _lobbyListening;
}

/// A game's lobby on the host's device: who has joined, the table's size,
/// and handing the guests over when the game starts.
abstract interface class Lobby {
  /// The host's name.
  String get hostName;

  /// Everyone at the table so far, the host first.
  List<String> get names;

  /// The table's size, including the host.
  int get seats;

  /// The names at the table, each time someone joins or leaves.
  Stream<List<String>> get changes;

  /// Changes the table's size, if everyone who has joined still fits.
  void resize(int seats);

  /// Closes the lobby to newcomers and hands over the guests by seat.
  Map<int, Guest> start();

  /// Shuts the lobby and every link to it.
  Future<void> close();
}

/// Hosts a game on this device for players on others on the same network:
/// takes them into the lobby as they join, tells everyone who's there, and
/// hands them over as the game starts.
///
/// The host is seat 0; guests take the next seats in the order they join.
/// Anyone joining once the table is full or the game has started is turned
/// away, and someone who leaves the lobby frees their place.
class GameHost implements Lobby {
  GameHost._(this._server, this.hostName, this._seats);

  /// Opens the lobby on [port] at [address] (every network the device is
  /// on, unless given), for a table of [seats] including the host.
  static Future<GameHost> open({
    required String hostName,
    required int seats,
    InternetAddress? address,
    int port = hostPort,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    final host = GameHost._(server, hostName, seats);
    server.listen(host._onRequest);
    return host;
  }

  final HttpServer _server;
  @override
  final String hostName;
  int _seats;
  final _guests = <Guest>[];
  final _changes = StreamController<List<String>>.broadcast();
  var _started = false;
  var _closing = false;

  /// The port the lobby is open on.
  int get port => _server.port;

  @override
  List<String> get names => [hostName, for (final guest in _guests) guest.name];

  @override
  int get seats => _seats;

  @override
  Stream<List<String>> get changes => _changes.stream;

  @override
  void resize(int seats) {
    if (seats < _guests.length + 1) return;
    _seats = seats;
    _announce();
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final connection = WebSocketConnection(
      await WebSocketTransformer.upgrade(request),
    );
    // The first word from a phone must be its player's name.
    late final StreamSubscription<WireMessage> listening;
    listening = connection.messages.listen((message) {
      if (message is! Hello) return;
      unawaited(listening.cancel());
      _admit(message.name, connection);
    }, onDone: () => connection.close());
  }

  void _admit(String name, Connection connection) {
    if (_started) {
      connection
        ..send(const Rejected('The game has already started.'))
        ..close();
      return;
    }
    if (_guests.length + 1 >= _seats) {
      connection
        ..send(const Rejected('The table is full.'))
        ..close();
      return;
    }
    final guest = Guest(_uniqueName(name.trim()), connection);
    _guests.add(guest);
    connection.send(Welcome(_guests.length));
    // Until the game starts, a guest who leaves gives up their place.
    late final StreamSubscription<WireMessage> listening;
    listening = connection.messages.listen(
      (_) {},
      onDone: () {
        if (_started || _closing) return;
        _guests.remove(guest);
        _announce();
      },
    );
    guest._lobbyListening = listening;
    _announce();
  }

  /// [name], or with a number added if it's taken, so everyone at the table
  /// can tell whose turn it is.
  String _uniqueName(String name) {
    final base = name.isEmpty ? 'Player' : name;
    var candidate = base;
    for (var n = 2; names.contains(candidate); n++) {
      candidate = '$base $n';
    }
    return candidate;
  }

  void _announce() {
    final update = LobbyUpdate(names: names, seats: _seats);
    for (final guest in _guests) {
      guest.connection.send(update);
    }
    _changes.add(names);
  }

  @override
  Map<int, Guest> start() {
    _started = true;
    for (final guest in _guests) {
      unawaited(guest._lobbyListening?.cancel());
    }
    return {for (final (i, guest) in _guests.indexed) i + 1: guest};
  }

  @override
  Future<void> close() async {
    _closing = true;
    for (final guest in [..._guests]) {
      await guest.connection.close();
    }
    await _changes.close();
    await _server.close(force: true);
  }
}

/// The address other devices on the network can reach this one at: its
/// private IPv4 address on Wi-Fi or its own hotspot, or `null` if it isn't
/// on such a network.
Future<String?> localAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  final private = [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (_isPrivate(address.address)) address.address,
  ];
  // Wi-Fi and hotspot networks use 192.168.x.x more than anything else.
  private.sort(
    (a, b) =>
        (b.startsWith('192.168.') ? 1 : 0) - (a.startsWith('192.168.') ? 1 : 0),
  );
  return private.firstOrNull;
}

bool _isPrivate(String address) {
  final parts = address.split('.').map(int.parse).toList();
  return parts[0] == 10 ||
      (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
      (parts[0] == 192 && parts[1] == 168);
}

/// Connects to the game hosted at [address] and introduces [name]. The
/// host answers on the session with [Welcome] or [Rejected].
Future<RemoteSession> joinGame(
  String address,
  String name, {
  int port = hostPort,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final socket = await WebSocket.connect(
    'ws://$address:$port',
  ).timeout(timeout);
  // Listening starts before the hello, so no answer can be missed.
  return RemoteSession(WebSocketConnection(socket))..send(Hello(name));
}
