import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../table/card_view.dart';
import '../telemetry/crash_reports.dart';
import '../theme/table_theme.dart';
import 'about.dart';
import 'feedback.dart';
import 'how_to_play_screen.dart';
import 'profile_dialog.dart';
import 'settings.dart';

/// Opens the settings as a popover under the top-right corner: tiles for
/// sound, vibration and the hand helper that switch on and off, tiles that
/// open the profile and the rules, and a choice of table theme.
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
    final testCrash = ref.watch(testCrashProvider);
    return Material(
      key: const Key('settings-popover'),
      color: const Color(0xF2263238),
      borderRadius: BorderRadius.circular(18),
      // Scrolls if a short screen can't fit it all.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
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
                          settings: const RouteSettings(name: 'how_to_play'),
                          builder: (_) => const HowToPlayScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingTile(
                    key: const Key('setting-feedback'),
                    label: 'Feedback',
                    icon: Icons.feedback_outlined,
                    onTap: () {
                      // Read before the popover, and its ref, are gone.
                      final open = ref.read(openLinkProvider);
                      final navigator = Navigator.of(context)..pop();
                      sendFeedback(navigator.context, open);
                    },
                  ),
                  _SettingTile(
                    key: const Key('setting-about'),
                    label: 'About',
                    icon: Icons.info_outline,
                    onTap: () {
                      // The popover's context goes as it closes; the
                      // navigator's stays.
                      final navigator = Navigator.of(context)..pop();
                      showAbout(navigator.context);
                    },
                  ),
                  // A developer's check that crash reports arrive.
                  if (kDebugMode && testCrash != null)
                    _SettingTile(
                      key: const Key('setting-test-crash'),
                      label: 'Test crash',
                      icon: Icons.bug_report_outlined,
                      onTap: testCrash,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Table theme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final (i, theme) in TableThemeId.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _ThemeSwatch(
                      theme: theme,
                      chosen: settings.tableTheme == theme,
                      onTap: () => controller.setTableTheme(theme),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small preview of a table theme: its felt with a card back on it, and
/// its name. The chosen theme is outlined in its highlight colour.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.chosen,
    required this.onTap,
  });

  final TableThemeId theme;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = theme.theme;
    return Semantics(
      selected: chosen,
      button: true,
      label: '${theme.label} table',
      onTap: onTap,
      // One clear label, rather than the label plus the name shown inside.
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('theme-${theme.name}'),
        onTap: onTap,
        child: Container(
          width: 98,
          height: 56,
          decoration: look.feltDecoration.copyWith(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chosen ? look.accent : const Color(0x33FFFFFF),
              width: chosen ? 2.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // The card back in the theme's own colours, whichever theme
              // is showing now.
              Theme(
                data: Theme.of(context).copyWith(extensions: [look]),
                child: const CardBack(width: 22),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    theme.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
