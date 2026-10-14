import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/scoring.dart';
import '../home/mode_picker.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';
import 'settings.dart';

/// Opens the [HouseRulesScreen].
void openHouseRules(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'house_rules'),
    builder: (_) => const HouseRulesScreen(),
  ),
);

/// A button that opens the [HouseRulesScreen], for the screens that start
/// a game. [onDark] draws it for the felt; otherwise it suits a dialog.
class HouseRulesButton extends StatelessWidget {
  const HouseRulesButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('house-rules-button'),
    style: onDark ? TextButton.styleFrom(foregroundColor: Colors.white) : null,
    onPressed: () => openHouseRules(context),
    icon: const Icon(Icons.tune),
    label: const Text('House rules'),
  );
}

/// [ScoringTable]'s escalating maal for 1, 2 and 3 of a card, written out:
/// "1 = 5, 2 = 15, 3 = 25".
String _byCount(List<int> table) => [
  for (var count = 1; count < table.length; count++) '$count = ${table[count]}',
].join(', ');

/// The mode and every optional house rule, each with a line on what it
/// does. Choices are saved in [Settings.rules] and apply from the next game
/// this device starts; in a hosted game, the host's rules apply to all.
class HouseRulesScreen extends ConsumerWidget {
  const HouseRulesScreen({super.key});

  static final manCardsDescription =
      'Three printed jokers, one per deck. Dead until you see the joker, '
      'then wild. Maal: ${_byCount(ScoringTable.manByCount)}; all three '
      'dealt to you are an opening tunnella worth '
      '${ScoringTable.manTunnella}.';

  static final supermanDescription =
      'One extra printed joker, always wild. It can fill one card of a set '
      'you show to see the joker, or pair with any card as a doublee. Worth '
      '${ScoringTable.superman} maal.';

  static final alterDescription =
      'The alter (the tiplu\'s rank, in the other suit of its colour) is '
      'maal: ${_byCount(ScoringTable.alterByCount)}. Off, it scores like an '
      'ordinary joker.';

  static final penaltyDescription =
      'Throwing away a wild card after seeing the joker, or the Superman at '
      'any time, costs ${ScoringTable.jokerDiscardPenalty} points, paid to '
      'the round\'s winner.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = TableTheme.of(context);
    final rules = ref.watch(settingsProvider.select((s) => s.rules));
    final controller = ref.read(settingsProvider.notifier);
    const white = TextStyle(color: Colors.white);
    const faint = TextStyle(color: Color(0xCCFFFFFF), fontSize: 12);

    Widget rule({
      required String key,
      required String title,
      required String description,
      required bool on,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      key: Key(key),
      value: on,
      onChanged: onChanged,
      activeThumbColor: theme.accent,
      title: Text(title, style: white),
      subtitle: Text(description, style: faint),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('House rules'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: TableFelt(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                key: const Key('house-rules'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          const ModePicker(onDark: true),
                          const Divider(color: Color(0x33FFFFFF)),
                          rule(
                            key: 'rule-man-cards',
                            title: 'Man cards',
                            description: manCardsDescription,
                            on: rules.manCards,
                            onChanged: controller.setManCards,
                          ),
                          rule(
                            key: 'rule-superman',
                            title: 'Superman',
                            description: supermanDescription,
                            on: rules.superman,
                            onChanged: controller.setSuperman,
                          ),
                          rule(
                            key: 'rule-alter-maal',
                            title: 'Alter as maal',
                            description: alterDescription,
                            on: rules.alterIsMaal,
                            onChanged: controller.setAlterIsMaal,
                          ),
                          rule(
                            key: 'rule-joker-penalty',
                            title: 'Joker penalty',
                            description: penaltyDescription,
                            on: rules.jokerPenalty,
                            onChanged: controller.setJokerPenalty,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rules apply from the next game you start. In a game '
                    'you join, the host\'s rules apply.',
                    textAlign: TextAlign.center,
                    style: faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
