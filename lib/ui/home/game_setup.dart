import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_player.dart';
import '../settings/settings.dart';

/// Opens the setup for a game against bots: how many play and how well the
/// bots play. The choices are saved as they're made, so Quick Play uses
/// them next time. Completes with `true` when the player taps Play.
Future<bool> showGameSetup(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _GameSetupDialog(),
    ) ??
    false;

/// A few words on how bots at [difficulty] play.
String describeDifficulty(BotDifficulty difficulty) => switch (difficulty) {
  BotDifficulty.easy => 'Relaxed bots that sometimes slip up.',
  BotDifficulty.medium => 'Solid bots that keep their sets and jokers.',
  BotDifficulty.hard => 'Sharp bots that remember every discard.',
};

/// The setup's summary, as shown on the Quick Play button: "4 bots · Medium".
String describeSetup(Settings settings) {
  final bots = settings.playerCount - 1;
  final level = settings.botDifficulty.name;
  return '$bots ${bots == 1 ? 'bot' : 'bots'} · '
      '${level[0].toUpperCase()}${level.substring(1)}';
}

class _GameSetupDialog extends ConsumerWidget {
  const _GameSetupDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final labelStyle = Theme.of(context).textTheme.titleSmall;

    final players = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Players', style: labelStyle),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (
              var count = Settings.minPlayers;
              count <= Settings.maxPlayers;
              count++
            )
              ChoiceChip(
                key: Key('players-$count'),
                label: Text('$count'),
                showCheckmark: false,
                selected: settings.playerCount == count,
                onSelected: (_) => controller.setPlayerCount(count),
              ),
          ],
        ),
      ],
    );
    final bots = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bots', style: labelStyle),
        const SizedBox(height: 6),
        SegmentedButton<BotDifficulty>(
          key: const Key('difficulty'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BotDifficulty.easy, label: Text('Easy')),
            ButtonSegment(value: BotDifficulty.medium, label: Text('Medium')),
            ButtonSegment(value: BotDifficulty.hard, label: Text('Hard')),
          ],
          selected: {settings.botDifficulty},
          onSelectionChanged: (chosen) =>
              controller.setBotDifficulty(chosen.single),
        ),
        const SizedBox(height: 6),
        Text(
          describeDifficulty(settings.botDifficulty),
          key: const Key('difficulty-description'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    // Side by side, so it fits the height of a phone held sideways.
    return AlertDialog(
      key: const Key('game-setup'),
      title: const Text('Play against bots'),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      content: SingleChildScrollView(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            players,
            const SizedBox(width: 28),
            SizedBox(width: 250, child: bots),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('setup-play'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play'),
        ),
      ],
    );
  }
}
