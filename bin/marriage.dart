import 'dart:io';
import 'dart:math';

import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/console/console_game.dart';
import 'package:marriage_game/engine/game_config.dart';

const _usage = '''
Play Marriage in the terminal against computer players.

Usage: dart run bin/marriage.dart [options]

  --players=N         number of players, 2 to 5 (default 5)
  --difficulty=LEVEL  easy, medium or hard bots (default medium)
  --seed=N            seed the shuffle so a game can be replayed
  --bots-only         watch bots play instead of playing seat 1 yourself
  --rounds=N          rounds to play in --bots-only mode (default 1)
  --help              show this message
''';

void main(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      stderr.write('Unexpected argument "$arg".\n\n$_usage');
      exitCode = 64;
      return;
    }
    final [name, ...value] = arg.substring(2).split('=');
    options[name] = value.join('=');
  }
  if (options.containsKey('help')) {
    stdout.write(_usage);
    return;
  }

  final int playerCount;
  final int? seed;
  final int rounds;
  final BotDifficulty difficulty;
  final GameConfig config;
  try {
    playerCount = _intOption(options, 'players') ?? 5;
    seed = _intOption(options, 'seed');
    rounds = _intOption(options, 'rounds') ?? 1;
    difficulty = _difficultyOption(options['difficulty']);
    config = GameConfig(playerCount: playerCount);
  } on FormatException catch (e) {
    stderr.write('${e.message}\n\n$_usage');
    exitCode = 64;
    return;
  } on ArgumentError catch (e) {
    stderr.write('${e.message}\n\n$_usage');
    exitCode = 64;
    return;
  }

  ConsoleGame(
    config: config,
    random: Random(seed),
    readLine: stdin.readLineSync,
    writeLine: print,
    humanSeat: options.containsKey('bots-only') ? null : 0,
    difficulty: difficulty,
  ).playMatch(rounds: rounds);
}

int? _intOption(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null) return null;
  final number = int.tryParse(value);
  if (number == null) {
    throw FormatException('--$name needs a whole number, got "$value".');
  }
  return number;
}

BotDifficulty _difficultyOption(String? value) {
  if (value == null) return BotDifficulty.medium;
  for (final level in BotDifficulty.values) {
    if (level.name == value) return level;
  }
  throw FormatException(
    '--difficulty must be easy, medium or hard, got "$value".',
  );
}
