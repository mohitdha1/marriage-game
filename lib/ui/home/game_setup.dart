import '../../bots/bot_player.dart';
import '../../engine/game_config.dart';
import '../state/table_controller.dart';
import 'stake_table_picker.dart';

/// A few words on how bots at [difficulty] play.
String describeDifficulty(BotDifficulty difficulty) => switch (difficulty) {
  BotDifficulty.easy => 'Relaxed bots that sometimes slip up.',
  BotDifficulty.medium => 'Solid bots that keep their sets and jokers.',
  BotDifficulty.hard => 'Sharp bots that remember every discard.',
};

/// [mode]'s name, as on the mode picker: "Standard", "Kidnap", "Murder".
String modeName(GameMode mode) =>
    '${mode.name[0].toUpperCase()}${mode.name.substring(1)}';

/// One line on what sets [mode] apart.
String describeMode(GameMode mode) => switch (mode) {
  GameMode.standard => 'Players who haven\'t seen the joker lose their maal.',
  GameMode.kidnap =>
    'The winner takes the maal of players who haven\'t seen the joker.',
  GameMode.murder =>
    'Players who haven\'t seen the joker also pay the winner\'s maal.',
};

/// What's printed on the felt: the mode, and the coins a point at a
/// stake table, as "KIDNAP · 1K/PT". `null` for a Standard game with no
/// stake, which needs no label.
String? feltLabel(GameMode mode, int? stake) {
  if (mode == GameMode.standard && stake == null) return null;
  return [
    modeName(mode).toUpperCase(),
    if (stake != null) '${formatStake(stake)}/PT',
  ].join(' · ');
}

/// [setup] summed up, as on the Quick Play button: "4 bots · Medium", and
/// at a stake table "4 bots · Easy · 50 table". A mode other than Standard
/// is named at the end: "4 bots · Easy · 50 table · Kidnap".
String describeSetup(MatchSetup setup) {
  final bots = setup.playerCount - 1;
  final level = setup.difficulty.name;
  final stake = setup.stake;
  return '$bots ${bots == 1 ? 'bot' : 'bots'} · '
      '${level[0].toUpperCase()}${level.substring(1)}'
      '${stake == null ? '' : ' · ${formatStake(stake)} table'}'
      '${setup.mode == GameMode.standard ? '' : ' · ${modeName(setup.mode)}'}';
}
