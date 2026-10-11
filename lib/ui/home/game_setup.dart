import '../../bots/bot_player.dart';
import '../state/table_controller.dart';
import 'stake_table_picker.dart';

/// A few words on how bots at [difficulty] play.
String describeDifficulty(BotDifficulty difficulty) => switch (difficulty) {
  BotDifficulty.easy => 'Relaxed bots that sometimes slip up.',
  BotDifficulty.medium => 'Solid bots that keep their sets and jokers.',
  BotDifficulty.hard => 'Sharp bots that remember every discard.',
};

/// [setup] summed up, as on the Quick Play button: "4 bots · Medium", and
/// at a stake table "4 bots · Easy · 50 table".
String describeSetup(MatchSetup setup) {
  final bots = setup.playerCount - 1;
  final level = setup.difficulty.name;
  final stake = setup.stake;
  return '$bots ${bots == 1 ? 'bot' : 'bots'} · '
      '${level[0].toUpperCase()}${level.substring(1)}'
      '${stake == null ? '' : ' · ${formatStake(stake)} table'}';
}
