import 'economy_config.dart';

/// A card picked from the hourly gift's board: where it lay, and what it
/// turned up.
class GiftPick {
  const GiftPick({required this.card, required this.reward});

  /// Its place on the board, from 0.
  final int card;
  final Reward reward;

  Map<String, Object?> toJson() => {'card': card, 'reward': reward.toJson()};

  static GiftPick fromJson(Map<String, Object?> json) => GiftPick(
    card: json['card'] as int,
    reward: Reward.fromJson(json['reward'] as Map<String, Object?>),
  );

  @override
  bool operator ==(Object other) =>
      other is GiftPick && other.card == card && other.reward == reward;

  @override
  int get hashCode => Object.hash(card, reward);
}

/// What became of one hourly gift: the free [pick], and which of the
/// rewarded-ad extras have been taken since. Each extra can be taken once,
/// until the next gift is ready.
class GiftSession {
  const GiftSession({
    required this.pick,
    this.doubled = false,
    this.extraPick,
    this.bonusTaken = false,
  });

  final GiftPick pick;

  /// Whether an ad doubled the free pick.
  final bool doubled;

  /// The card an ad let the player pick as well, if any.
  final GiftPick? extraPick;

  /// Whether an ad gave the bonus.
  final bool bonusTaken;

  /// Whether every extra has been taken.
  bool get isFinished => doubled && extraPick != null && bonusTaken;

  GiftSession copyWith({
    bool? doubled,
    GiftPick? extraPick,
    bool? bonusTaken,
  }) => GiftSession(
    pick: pick,
    doubled: doubled ?? this.doubled,
    extraPick: extraPick ?? this.extraPick,
    bonusTaken: bonusTaken ?? this.bonusTaken,
  );

  Map<String, Object?> toJson() => {
    'pick': pick.toJson(),
    'doubled': doubled,
    if (extraPick case final extra?) 'extra': extra.toJson(),
    'bonus': bonusTaken,
  };

  static GiftSession fromJson(Map<String, Object?> json) => GiftSession(
    pick: GiftPick.fromJson(json['pick'] as Map<String, Object?>),
    doubled: json['doubled'] as bool? ?? false,
    extraPick: switch (json['extra']) {
      final Map<String, Object?> extra => GiftPick.fromJson(extra),
      _ => null,
    },
    bonusTaken: json['bonus'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is GiftSession &&
      other.pick == pick &&
      other.doubled == doubled &&
      other.extraPick == extraPick &&
      other.bonusTaken == bonusTaken;

  @override
  int get hashCode => Object.hash(pick, doubled, extraPick, bonusTaken);
}
