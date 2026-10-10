import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'how_to_play_screen.dart';
import 'profile_dialog.dart';
import 'settings.dart';

/// Opens the settings as a popover under the top-right corner: tiles for
/// sound, vibration and the hand helper that switch on and off, and tiles
/// that open the profile and the rules.
Future<void> showSettingsPopover(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close settings',
    barrierColor: const Color(0x55000000),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => const SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: 56, right: 12),
          child: _SettingsPopover(),
        ),
      ),
    ),
  );
}

class _SettingsPopover extends ConsumerWidget {
  const _SettingsPopover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Material(
      key: const Key('settings-popover'),
      color: const Color(0xF2263238),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 330,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SettingTile(
                key: const Key('setting-sound'),
                label: 'Sound',
                icon: settings.sound ? Icons.volume_up : Icons.volume_off,
                on: settings.sound,
                onTap: () => controller.setSound(!settings.sound),
              ),
              _SettingTile(
                key: const Key('setting-vibration'),
                label: 'Vibration',
                icon: settings.vibration
                    ? Icons.vibration
                    : Icons.phonelink_erase,
                on: settings.vibration,
                onTap: () => controller.setVibration(!settings.vibration),
              ),
              _SettingTile(
                key: const Key('setting-hand-helper'),
                label: 'Hand helper',
                icon: Icons.lightbulb_outline,
                on: settings.handHelper,
                onTap: () => controller.setHandHelper(!settings.handHelper),
              ),
              _SettingTile(
                key: const Key('setting-profile'),
                label: 'Profile',
                icon: Icons.person_outline,
                onTap: () {
                  Navigator.of(context).pop();
                  showProfileDialog(context);
                },
              ),
              _SettingTile(
                key: const Key('setting-how-to-play'),
                label: 'How to play',
                icon: Icons.menu_book_outlined,
                onTap: () {
                  final navigator = Navigator.of(context)..pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HowToPlayScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tile in the settings popover. A tile with [on] set switches
/// something on or off and is lit when on; one without opens something.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.on,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool? on;

  @override
  Widget build(BuildContext context) {
    final lit = on ?? true;
    final colour = lit ? Colors.white : const Color(0x88FFFFFF);
    return Semantics(
      toggled: on,
      button: on == null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 98,
          height: 78,
          decoration: BoxDecoration(
            color: on == null
                ? const Color(0x22FFFFFF)
                : (lit ? const Color(0x553FA34D) : const Color(0x11FFFFFF)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colour, size: 26),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    on == null ? label : '$label ${lit ? 'on' : 'off'}',
                    maxLines: 1,
                    style: TextStyle(color: colour, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
