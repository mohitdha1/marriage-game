import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_player.dart';
import '../../net/game_host.dart';
import '../../net/room_code.dart';
import '../home/home_screen.dart';
import '../home/mode_picker.dart';
import '../home/player_avatar.dart';
import '../settings/house_rules_screen.dart';
import '../settings/settings.dart';
import '../state/table_controller.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';

/// Finds the address other devices can reach this one at. Tests swap it.
final localAddressProvider = Provider<Future<String?> Function()>(
  (ref) => localAddress,
);

/// Opens the lobby for [hostName]'s game at a table of [seats]. Tests swap
/// it for one on the loopback address.
final openLobbyProvider =
    Provider<Future<Lobby> Function(String hostName, int seats)>(
      (ref) =>
          (hostName, seats) => GameHost.open(hostName: hostName, seats: seats),
    );

/// The lobby for a game this device hosts: the room code for friends to
/// type in, who has joined, the table's size and the bots' level for empty
/// seats, and Start.
class HostLobbyScreen extends ConsumerStatefulWidget {
  const HostLobbyScreen({super.key});

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  Lobby? _host;
  String? _code;
  String? _problem;
  StreamSubscription<List<String>>? _changes;
  late BotDifficulty _difficulty = ref.read(settingsProvider).botDifficulty;

  /// Whether the lobby has been handed to the game, which closes it later.
  var _handedOver = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() => _problem = null);
    final address = await ref.read(localAddressProvider)();
    if (!mounted) return;
    if (address == null) {
      setState(
        () => _problem =
            'Connect to Wi-Fi, or turn on your phone\'s hotspot, so friends '
            'can join.',
      );
      return;
    }
    try {
      final host = await ref.read(openLobbyProvider)(
        ref.read(settingsProvider).playerName,
        4,
      );
      if (!mounted) {
        unawaited(host.close());
        return;
      }
      _changes = host.changes.listen((_) => setState(() {}));
      setState(() {
        _host = host;
        _code = roomCodeFor(address);
      });
    } on SocketException {
      if (mounted) {
        setState(
          () => _problem =
              'Couldn\'t open the game here. Another game may already be '
              'hosted on this device.',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    if (!_handedOver) unawaited(_host?.close());
    super.dispose();
  }

  void _start() {
    final host = _host!;
    final guests = host.start();
    startMatchWith(
      ref,
      MatchSetup.hosted(
        hostName: host.hostName,
        playerCount: host.seats,
        difficulty: _difficulty,
        rejoins: host.rejoins,
        rules: ref.read(settingsProvider).rules,
        remote: {
          for (final MapEntry(key: seat, value: guest) in guests.entries)
            seat: RemotePlayer(name: guest.name, connection: guest.connection),
        },
      ),
    );
    _handedOver = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => HostedTable(host: host)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    final host = _host;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Host a game'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: TableFelt(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: switch ((host, _problem)) {
                (_, final problem?) => _Problem(
                  message: problem,
                  onRetry: _open,
                ),
                (null, _) => const CircularProgressIndicator(),
                (final host?, _) => Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Panel(
                      color: theme.panel,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Room code',
                            style: TextStyle(color: Color(0xCCFFFFFF)),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _code!,
                            key: const Key('room-code'),
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(
                            width: 240,
                            child: Text(
                              'Friends on the same Wi-Fi tap Play with '
                              'Friends, then Join with a code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 280,
                            child: ModePicker(onDark: true),
                          ),
                          const HouseRulesButton(onDark: true),
                        ],
                      ),
                    ),
                    _Panel(
                      color: theme.panel,
                      child: _Seats(
                        host: host,
                        difficulty: _difficulty,
                        onDifficulty: (d) => setState(() => _difficulty = d),
                        onStart: _start,
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Who's at the table, seat by seat, with the table's size, the bots' level
/// and Start.
class _Seats extends StatelessWidget {
  const _Seats({
    required this.host,
    required this.difficulty,
    required this.onDifficulty,
    required this.onStart,
  });

  final Lobby host;
  final BotDifficulty difficulty;
  final ValueChanged<BotDifficulty> onDifficulty;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final names = host.names;
    const white = TextStyle(color: Colors.white);
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var seat = 0; seat < host.seats; seat++)
            Padding(
              key: Key('lobby-seat-$seat'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (seat < names.length)
                    PlayerAvatar(
                      name: names[seat],
                      color: Color(
                        Settings.avatarColors[seat %
                            Settings.avatarColors.length],
                      ),
                      radius: 12,
                    )
                  else
                    const Icon(
                      Icons.smart_toy_outlined,
                      color: Color(0x99FFFFFF),
                      size: 24,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    seat < names.length ? names[seat] : 'Bot',
                    style: seat < names.length
                        ? white
                        : const TextStyle(color: Color(0x99FFFFFF)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Seats', style: white),
              const SizedBox(width: 8),
              for (
                var seats = Settings.minPlayers;
                seats <= Settings.maxPlayers;
                seats++
              )
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    key: Key('lobby-seats-$seats'),
                    label: Text('$seats'),
                    showCheckmark: false,
                    selected: host.seats == seats,
                    // The table can't shrink below who's already joined.
                    onSelected: seats < names.length
                        ? null
                        : (_) => host.resize(seats),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<BotDifficulty>(
            showSelectedIcon: false,
            // Readable on the dark panel: white, and the chosen level in
            // the theme's highlight colour.
            style: SegmentedButton.styleFrom(
              foregroundColor: Colors.white,
              selectedForegroundColor: const Color(0xFF1A1A1A),
              selectedBackgroundColor: TableTheme.of(context).accent,
              side: const BorderSide(color: Color(0x99FFFFFF)),
            ),
            segments: const [
              ButtonSegment(value: BotDifficulty.easy, label: Text('Easy')),
              ButtonSegment(value: BotDifficulty.medium, label: Text('Medium')),
              ButtonSegment(value: BotDifficulty.hard, label: Text('Hard')),
            ],
            selected: {difficulty},
            onSelectionChanged: (chosen) => onDifficulty(chosen.single),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('lobby-start'),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                names.length == 1 ? 'Start with bots' : 'Start the game',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the lobby couldn't open, and a way to try again.
class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('lobby-problem'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.wifi_off, color: Colors.white, size: 48),
      const SizedBox(height: 8),
      SizedBox(
        width: 340,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}

/// The theme's dark panel.
class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: child,
  );
}

/// The table for a game this device hosts, keeping the lobby's links to
/// the other devices open until the host leaves the table.
class HostedTable extends StatefulWidget {
  const HostedTable({super.key, required this.host});

  final Lobby host;

  @override
  State<HostedTable> createState() => _HostedTableState();
}

class _HostedTableState extends State<HostedTable> {
  @override
  void dispose() {
    unawaited(widget.host.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => singlePlayerTable;
}
