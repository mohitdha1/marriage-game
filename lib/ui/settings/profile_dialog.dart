import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_data.dart';
import '../home/player_data_provider.dart';
import '../scoreboard/scoreboard_screen.dart';
import 'profile_editor.dart';

/// Opens the player's profile: their name and avatar to change, and their
/// record.
Future<void> showProfileDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ProfileDialog());

class _ProfileDialog extends ConsumerWidget {
  const _ProfileDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playerDataProvider).value;
    return Dialog(
      key: const Key('profile-dialog'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  key: const Key('profile-close'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (data == null)
              const Center(child: CircularProgressIndicator())
            else
              ProfileEditor(
                name: data.profile.name,
                look: data.profile.look,
                saveLabel: 'Save',
                onSave: (name, look) {
                  ref
                      .read(playerDataProvider.notifier)
                      .saveProfile(name: name, look: look);
                  Navigator.of(context).pop();
                },
                footer: Text(
                  describeStats(data.stats),
                  key: const Key('profile-stats'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [stats] in a line for the profile: "Rounds 12 · Won 5 (42%) · Best +38".
String describeStats(PlayerStats stats) {
  if (stats.roundsPlayed == 0) {
    return 'Your record starts with your first round.';
  }
  final percent = (stats.winRate * 100).round();
  return 'Rounds ${stats.roundsPlayed} · Won ${stats.roundsWon} ($percent%) · '
      'Best ${signed(stats.bestRound!)}';
}
