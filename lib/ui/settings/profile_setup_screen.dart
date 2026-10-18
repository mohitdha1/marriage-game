import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/player_data_provider.dart';
import '../theme/table_felt.dart';
import 'profile_editor.dart';

/// Shows [child] once the player has a profile, and until then the first
/// launch's screen for choosing a name and avatar. While the player's data
/// loads, [child] shows, so a returning player never sees the setup flash
/// by.
class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerDataProvider).value?.profile;
    if (profile == null || profile.chosen) return child;
    return ProfileSetupScreen(name: profile.name, look: profile.look);
  }
}

/// The first launch: a welcome, then a name and an avatar to choose,
/// starting from the [name] and [look] already kept.
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key, required this.name, required this.look});

  final String name;
  final int look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('profile-setup'),
      body: TableFelt(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome to Marriage!',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the name and avatar others see at the table. '
                        'You can change them later in your profile.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      ProfileEditor(
                        name: name,
                        look: look,
                        saveLabel: 'Continue',
                        onSave: (name, look) => ref
                            .read(playerDataProvider.notifier)
                            .saveProfile(name: name, look: look),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
