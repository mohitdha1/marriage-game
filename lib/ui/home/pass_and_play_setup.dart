import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import 'mode_picker.dart';

/// Opens the setup for a game passed round this device: how many people
/// play and their names, in seat order. Completes with the names when the
/// players tap Play, or `null` if they cancel.
Future<List<String>?> showPassAndPlaySetup(BuildContext context) =>
    showDialog<List<String>>(
      context: context,
      builder: (_) => const _PassAndPlayDialog(),
    );

/// [typed] tidied into names to play under: blanks become "Player 2" and so
/// on by seat, and a repeated name gets its seat number, so everyone at the
/// table can tell whose turn it is.
List<String> tidyNames(List<String> typed) {
  final names = <String>[];
  for (final (i, raw) in typed.indexed) {
    var name = raw.trim();
    if (name.isEmpty) name = 'Player ${i + 1}';
    if (names.contains(name)) name = '$name ${i + 1}';
    names.add(name);
  }
  return names;
}

class _PassAndPlayDialog extends ConsumerStatefulWidget {
  const _PassAndPlayDialog();

  @override
  ConsumerState<_PassAndPlayDialog> createState() => _PassAndPlayState();
}

class _PassAndPlayState extends ConsumerState<_PassAndPlayDialog> {
  var _count = 2;

  /// A name field for every seat there could be; the first starts with the
  /// player's own name.
  late final _names = [
    for (var i = 0; i < Settings.maxPlayers; i++)
      TextEditingController(
        text: i == 0 ? ref.read(settingsProvider).playerName : '',
      ),
  ];

  @override
  void dispose() {
    for (final name in _names) {
      name.dispose();
    }
    super.dispose();
  }

  void _play() => Navigator.of(
    context,
  ).pop(tidyNames([for (final name in _names.take(_count)) name.text]));

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall;
    return AlertDialog(
      key: const Key('pass-and-play-setup'),
      title: const Text('Pass and play'),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take turns on this device; it hides your cards between '
                'turns.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('People', style: labelStyle),
                  const SizedBox(width: 12),
                  for (
                    var count = Settings.minPlayers;
                    count <= Settings.maxPlayers;
                    count++
                  )
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('people-$count'),
                        label: Text('$count'),
                        showCheckmark: false,
                        selected: _count == count,
                        onSelected: (_) => setState(() => _count = count),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _count; i++)
                    SizedBox(
                      width: 104,
                      child: TextField(
                        key: Key('person-name-$i'),
                        controller: _names[i],
                        maxLength: 12,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Player ${i + 1}',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(child: ModePicker()),
              const SizedBox(height: 10),
              Text(
                'Playing on separate phones over Wi-Fi is coming soon.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('pass-and-play-start'),
          onPressed: _play,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play'),
        ),
      ],
    );
  }
}
