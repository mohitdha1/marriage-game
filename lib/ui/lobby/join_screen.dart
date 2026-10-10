import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../net/game_host.dart';
import '../../net/remote_session.dart';
import '../../net/room_code.dart';
import '../../net/wire.dart';
import '../home/home_screen.dart';
import '../settings/settings.dart';
import '../state/remote_table_controller.dart';
import '../state/table_controller.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';

/// Connects to the game at an address as a named player. Tests swap it.
final joinGameProvider =
    Provider<Future<RemoteSession> Function(String address, String name)>(
      (ref) => joinGame,
    );

/// Joins a game hosted on another device on the same network: the player's
/// name and the host's room code, then who's in the lobby while the host
/// gets ready, and the table once the game starts.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _name = TextEditingController(
    text: ref.read(settingsProvider).playerName,
  );
  final _code = TextEditingController();

  RemoteSession? _session;
  StreamSubscription<WireMessage>? _listening;
  var _connecting = false;
  String? _problem;
  List<String> _lobby = const [];

  /// Whether the session has been handed to the game's table.
  var _handedOver = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    unawaited(_listening?.cancel());
    if (!_handedOver) unawaited(_session?.close());
    super.dispose();
  }

  Future<void> _join() async {
    final address = addressFromRoomCode(_code.text);
    if (address == null) {
      setState(
        () => _problem = 'That isn\'t a room code. It looks like K7Q-2XB4.',
      );
      return;
    }
    setState(() {
      _connecting = true;
      _problem = null;
    });
    try {
      final session = await ref.read(joinGameProvider)(
        address,
        _name.text.trim(),
      );
      if (!mounted) {
        unawaited(session.close());
        return;
      }
      _session = session;
      _listening = session.messages.listen(
        _onMessage,
        onDone: () {
          if (_handedOver || !mounted) return;
          setState(() {
            _session = null;
            _connecting = false;
            _problem ??= 'The host closed the game.';
          });
        },
      );
      unawaited(session.firstUpdate.then((_) => _enterTable()));
    } on Object catch (e) {
      if (e is! SocketException &&
          e is! TimeoutException &&
          e is! WebSocketException) {
        rethrow;
      }
      if (mounted) {
        setState(() {
          _connecting = false;
          _problem =
              'Couldn\'t reach that game. Check you\'re on the same Wi-Fi as '
              'the host, and the code is right.';
        });
      }
    }
  }

  void _onMessage(WireMessage message) {
    switch (message) {
      case Welcome():
        setState(() => _connecting = false);
      case LobbyUpdate(:final names):
        setState(() => _lobby = names);
      case Rejected(:final reason):
        setState(() => _problem = reason);
        unawaited(_session?.close());
      case _:
        break;
    }
  }

  void _enterTable() {
    final session = _session;
    if (!mounted || session == null) return;
    _handedOver = true;
    unawaited(_listening?.cancel());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => JoinedTable(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    final waiting = _session != null && !_connecting;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Join a game'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: TableFelt(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: waiting
                    ? _Waiting(lobby: _lobby, accent: theme.accent)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Field(
                            key: const Key('join-name'),
                            controller: _name,
                            label: 'Your name',
                            maxLength: 12,
                          ),
                          const SizedBox(height: 8),
                          _Field(
                            key: const Key('join-code'),
                            controller: _code,
                            label: 'Room code',
                            hint: 'K7Q-2XB4',
                            maxLength: 9,
                            onSubmitted: (_) => _join(),
                          ),
                          if (_problem case final problem?) ...[
                            const SizedBox(height: 8),
                            Text(
                              problem,
                              key: const Key('join-problem'),
                              style: const TextStyle(color: Color(0xFFFFAB91)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              key: const Key('join-button'),
                              onPressed: _connecting ? null : _join,
                              icon: _connecting
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Join'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who's in the lobby, while the host gets ready to start.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.lobby, required this.accent});

  final List<String> lobby;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('join-waiting'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        lobby.isEmpty
            ? 'Joined. Waiting for the host to start…'
            : 'Waiting for ${lobby.first} to start…',
        style: TextStyle(color: accent, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      for (final name in lobby)
        Text(name, style: const TextStyle(color: Colors.white)),
    ],
  );
}

/// A text field styled for the dark panel.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.maxLength,
    this.hint,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.characters,
    onSubmitted: onSubmitted,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: const TextStyle(color: Color(0xCCFFFFFF)),
      hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0x99FFFFFF)),
      ),
    ),
  );
}

/// The table for a game joined on this device: played through the link to
/// the host, which closes when the player leaves the table.
class JoinedTable extends StatefulWidget {
  const JoinedTable({super.key, required this.session});

  final RemoteSession session;

  @override
  State<JoinedTable> createState() => _JoinedTableState();
}

class _JoinedTableState extends State<JoinedTable> {
  @override
  void dispose() {
    unawaited(widget.session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      remoteSessionProvider.overrideWithValue(widget.session),
      tableProvider.overrideWith(RemoteTableController.new),
    ],
    child: singlePlayerTable,
  );
}
