/// Who the player is at the table: their [name] and avatar [look], and
/// whether they've [chosen] them yet, which a new player does before
/// their first game.
class PlayerProfile {
  const PlayerProfile({
    this.name = defaultName,
    this.look = 0,
    this.chosen = false,
  });

  /// The name a player has before choosing one.
  static const defaultName = 'Player';

  final String name;

  /// The avatar, as its number among the drawn avatar looks.
  final int look;

  final bool chosen;

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile &&
      other.name == name &&
      other.look == look &&
      other.chosen == chosen;

  @override
  int get hashCode => Object.hash(name, look, chosen);
}
