import 'dart:math';

import 'bot_player.dart' show BotDifficulty;

/// A named bot character. Each belongs to one [difficulty] and only sits
/// at tables of it, so the faces met change on the way up; within that
/// level, its personality nudges how it plays, so bots at the same level
/// still feel different.
class BotPersonality {
  const BotPersonality({
    required this.name,
    required this.tagline,
    this.difficulty = BotDifficulty.medium,
    this.look = 0,
    this.pickupThreshold = 2,
    this.caution = 1.0,
    this.pairBonus = 0,
  });

  final String name;

  /// A few words describing the character, for the lobby and profile.
  final String tagline;

  /// The level whose tables this bot sits at.
  final BotDifficulty difficulty;

  /// The bot's avatar: its number among the drawn avatar looks.
  final int look;

  /// How useful the top discard must look before the bot takes it instead
  /// of drawing from the stock. Lower means keener on the discard pile.
  final int pickupThreshold;

  /// How much a Hard bot cares about not feeding the next player, as a
  /// multiplier: above 1 is careful, below 1 is bold.
  final double caution;

  /// Extra value placed on holding identical cards, for a bot that likes
  /// building doublees.
  final int pairBonus;

  /// The full cast, all with Nepali names: five at each level.
  static const all = [
    // Easy: friendly players who make mistakes.
    BotPersonality(
      name: 'Bishal',
      tagline: 'Can never resist the discard pile',
      difficulty: BotDifficulty.easy,
      look: 0,
      pickupThreshold: 1,
    ),
    BotPersonality(
      name: 'Gita',
      tagline: 'Plays for fun and laughs at her own mistakes',
      difficulty: BotDifficulty.easy,
      look: 7,
    ),
    BotPersonality(
      name: 'Ramesh',
      tagline: 'Chatty, and easily distracted',
      difficulty: BotDifficulty.easy,
      look: 6,
      pickupThreshold: 1,
    ),
    BotPersonality(
      name: 'Maya',
      tagline: 'Just learning, and loving it',
      difficulty: BotDifficulty.easy,
      look: 18,
      pairBonus: 1,
    ),
    BotPersonality(
      name: 'Hari',
      tagline: 'Keeps every card, just in case',
      difficulty: BotDifficulty.easy,
      look: 9,
      pickupThreshold: 3,
    ),
    // Medium: solid players with a style of their own.
    BotPersonality(
      name: 'Kiran',
      tagline: 'Bold, fast and a little reckless',
      look: 2,
      caution: 0.5,
    ),
    BotPersonality(name: 'Sunita', tagline: 'Steady and patient', look: 3),
    BotPersonality(
      name: 'Anjali',
      tagline: 'Loves a long run of hearts',
      look: 12,
      pickupThreshold: 1,
    ),
    BotPersonality(
      name: 'Suman',
      tagline: 'Quiet, then suddenly shows',
      look: 11,
      caution: 1.3,
    ),
    BotPersonality(
      name: 'Dipak',
      tagline: 'Never says no to a pair',
      look: 17,
      pairBonus: 2,
    ),
    // Hard: careful, sharp players.
    BotPersonality(
      name: 'Priya',
      tagline: 'Plays it safe, gives nothing away',
      difficulty: BotDifficulty.hard,
      look: 1,
      pickupThreshold: 3,
      caution: 1.6,
    ),
    BotPersonality(
      name: 'Sabina',
      tagline: 'Watches everyone\'s discards',
      difficulty: BotDifficulty.hard,
      look: 5,
      caution: 1.2,
    ),
    BotPersonality(
      name: 'Arjun',
      tagline: 'Collects pairs, dreams of a dublee',
      difficulty: BotDifficulty.hard,
      look: 4,
      pairBonus: 2,
    ),
    BotPersonality(
      name: 'Nabin',
      tagline: 'Counts every card that\'s gone',
      difficulty: BotDifficulty.hard,
      look: 15,
      caution: 1.4,
    ),
    BotPersonality(
      name: 'Sarita',
      tagline: 'Patient as the mountains',
      difficulty: BotDifficulty.hard,
      look: 10,
      pickupThreshold: 3,
    ),
  ];

  /// The bots who sit at [difficulty]'s tables.
  static List<BotPersonality> at(BotDifficulty difficulty) => [
    for (final bot in all)
      if (bot.difficulty == difficulty) bot,
  ];

  /// The bot named [name], if there is one.
  static BotPersonality? named(String name) {
    for (final bot in all) {
      if (bot.name == name) return bot;
    }
    return null;
  }

  /// [count] different bots of [difficulty], chosen at random, leaving out
  /// any whose names are in [seated], so nobody at a table shares a name.
  static List<BotPersonality> pick(
    int count,
    Random random,
    BotDifficulty difficulty, {
    Iterable<String> seated = const [],
  }) {
    final taken = seated.toSet();
    final pool = [
      for (final bot in at(difficulty))
        if (!taken.contains(bot.name)) bot,
    ];
    if (count > pool.length) {
      throw ArgumentError.value(
        count,
        'count',
        'is more than the ${pool.length} ${difficulty.name} bots free',
      );
    }
    return (pool..shuffle(random)).take(count).toList();
  }
}
