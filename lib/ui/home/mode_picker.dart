import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/game_config.dart';
import '../settings/settings.dart';
import 'game_setup.dart';

/// Standard, Kidnap or Murder as chips, with a line on the one chosen. The choice is
/// saved in [Settings.rules] and played in the next game this device starts.
///
/// [onDark] draws it for a dark background, such as the felt; otherwise it
/// suits a light dialog. Without [describe], the line on the chosen mode is
/// left for the screen to place.
class ModePicker extends ConsumerWidget {
  const ModePicker({super.key, this.onDark = false, this.describe = true});

  final bool onDark;
  final bool describe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.rules.mode));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wraps onto a second line where it's too narrow for one.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'Mode',
                style: onDark ? const TextStyle(color: Colors.white) : null,
              ),
            ),
            for (final choice in GameMode.values)
              ChoiceChip(
                key: Key('mode-${choice.name}'),
                label: Text(modeName(choice)),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selected: mode == choice,
                onSelected: (_) =>
                    ref.read(settingsProvider.notifier).setMode(choice),
              ),
          ],
        ),
        if (describe) ...[
          const SizedBox(height: 4),
          ModeDescription(mode: mode, onDark: onDark),
        ],
      ],
    );
  }
}

/// One line on what sets [mode] apart, under a [ModePicker].
class ModeDescription extends StatelessWidget {
  const ModeDescription({super.key, required this.mode, this.onDark = false});

  final GameMode mode;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text(
    describeMode(mode),
    key: const Key('mode-description'),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 12,
      color: onDark ? const Color(0xCCFFFFFF) : null,
    ),
  );
}
