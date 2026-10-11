import 'dart:math';

/// A named bot character. Difficulty decides how well a bot plays; its
/// personality nudges how it plays, so bots at the same level still feel
/// different.
class BotPersonality {
  const BotPersonality({
    required this.name,
    required this.tagline,
    required this.avatarColor,
    this.pickupThreshold = 2,
    this.caution = 1.0,
    this.pairBonus = 0,
  });

  final String name;

  /// A few words describing the character, for the lobby and profile.
  final String tagline;

  /// Avatar background colour, as 0xAARRGGBB.
  final int avatarColor;

  /// How useful the top discard must look before the bot takes it instead
  /// of drawing from the stock. Lower means keener on the discard pile.
  final int pickupThreshold;

  /// How much a Hard bot cares about not feeding the next player, as a
  /// multiplier: above 1 is careful, below 1 is bold.
  final double caution;

  /// Extra value placed on holding identical cards, for a bot that likes
  /// building doublees.
  final int pairBonus;

  /// The full cast, all with Nepali names.
  static const all = [
    BotPersonality(
      name: 'Bishal',
      tagline: 'Can never resist the discard pile',
      avatarColor: 0xFFFFCC80,
      pickupThreshold: 1,
    ),
    BotPersonality(
      name: 'Priya',
      tagline: 'Plays it safe, gives nothing away',
      avatarColor: 0xFFF8BBD0,
      pickupThreshold: 3,
      caution: 1.6,
    ),
    BotPersonality(
      name: 'Kiran',
      tagline: 'Bold, fast and a little reckless',
      avatarColor: 0xFFB3E5FC,
      caution: 0.5,
    ),
    BotPersonality(
      name: 'Sunita',
      tagline: 'Steady and patient',
      avatarColor: 0xFFC8E6C9,
    ),
    BotPersonality(
      name: 'Arjun',
      tagline: 'Collects pairs, dreams of a dublee',
      avatarColor: 0xFFD1C4E9,
      pairBonus: 2,
    ),
    BotPersonality(
      name: 'Sabina',
      tagline: 'Watches everyone\'s discards',
      avatarColor: 0xFFFFF59D,
      caution: 1.2,
    ),
  ];

  /// [count] different personalities, chosen at random.
  static List<BotPersonality> pick(int count, Random random) {
    if (count > all.length) {
      throw ArgumentError.value(count, 'count', 'is more than ${all.length}');
    }
    final shuffled = [...all]..shuffle(random);
    return shuffled.take(count).toList();
  }
}
