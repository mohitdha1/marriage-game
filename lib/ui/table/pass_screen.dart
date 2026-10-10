import 'package:flutter/material.dart';

import '../../engine/table_event.dart';
import '../home/player_avatar.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';
import 'move_log.dart';
import 'suit_icon.dart';

/// Covers the whole table while the device is passed to [name], so nobody
/// else sees their cards. Says what happened since their last turn, and
/// uncovers the table when they tap to say they have the device.
class PassScreen extends StatelessWidget {
  const PassScreen({
    super.key,
    required this.name,
    required this.color,
    required this.since,
    required this.onReady,
    this.choosingOpening = false,
  });

  final String name;

  /// [name]'s avatar colour.
  final Color color;

  /// The moves made since [name] last played, oldest first.
  final List<String> since;

  /// Whether [name] is being passed the device to choose their opening
  /// tunnellas, rather than to play a turn.
  final bool choosingOpening;

  final VoidCallback onReady;

  /// The most moves listed, the latest ones.
  static const maxMoves = 5;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    final moves = since.length > maxMoves
        ? since.sublist(since.length - maxMoves)
        : since;
    return Stack(
      key: const Key('pass-screen'),
      children: [
        // Nothing underneath can be touched while the device changes hands.
        const ModalBarrier(dismissible: false),
        TableFelt(
          rim: true,
          child: SafeArea(
            minimum: const EdgeInsets.all(TableFelt.rimWidth),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(name: name, color: color, radius: 28),
                    const SizedBox(height: 10),
                    Text(
                      'Pass the device to $name',
                      key: const Key('pass-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choosingOpening
                          ? 'to choose their opening tunnellas'
                          : 'It\'s their turn',
                      style: const TextStyle(color: Color(0xCCFFFFFF)),
                    ),
                    if (moves.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const Key('pass-since'),
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Since $name\'s last turn',
                              style: TextStyle(
                                color: theme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (final move in moves)
                              DefaultTextStyle.merge(
                                style: const TextStyle(color: Colors.white),
                                child: SuitText(move),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('pass-ready'),
                      onPressed: onReady,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.visibility),
                      label: Text('I\'m $name: show my cards'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What's happened since [seat] last acted, oldest first, as the move log
/// words it: everything after their own latest move, or the whole round if
/// they haven't moved yet.
List<String> movesSince(
  List<TableEvent> events,
  int seat,
  String Function(int seat) nameOf,
) {
  final last = events.lastIndexWhere((e) => e.seat == seat);
  return [
    for (final event in events.skip(last + 1)) describeEvent(event, nameOf),
  ];
}
