import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/player_avatar.dart';
import 'settings.dart';

/// Opens a dialog to change the player's name and avatar colour.
Future<void> showProfileDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ProfileDialog());

class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog();

  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(settingsProvider).playerName,
  );
  late int _color = ref.read(settingsProvider).avatarColor;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsProvider.notifier)
      ..setPlayerName(_name.text)
      ..setAvatarColor(_color);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('profile-dialog'),
      title: const Text('Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(name: _name.text, color: Color(_color), radius: 30),
            const SizedBox(height: 12),
            TextField(
              key: const Key('profile-name'),
              controller: _name,
              maxLength: 16,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            Wrap(
              spacing: 10,
              children: [
                for (final (i, colour) in Settings.avatarColors.indexed)
                  GestureDetector(
                    key: Key('avatar-colour-$i'),
                    onTap: () => setState(() => _color = colour),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(colour),
                      child: _color == colour
                          ? const Icon(Icons.check, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('profile-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
