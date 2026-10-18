import 'dart:convert';
import 'dart:math';

/// Coins and gems given together, as a reward.
class Reward {
  const Reward({this.coins = 0, this.gems = 0});

  /// Reads a reward written as `{"coins": 500}`, `{"gems": 1}` or both.
  factory Reward.fromJson(Map<String, Object?> json) => Reward(
    coins: json['coins'] as int? ?? 0,
    gems: json['gems'] as int? ?? 0,
  );

  final int coins;
  final int gems;

  /// This reward given twice.
  Reward get doubled => Reward(coins: coins * 2, gems: gems * 2);

  Map<String, Object?> toJson() => {
    if (coins != 0) 'coins': coins,
    if (gems != 0) 'gems': gems,
  };

  @override
  bool operator ==(Object other) =>
      other is Reward && other.coins == coins && other.gems == gems;

  @override
  int get hashCode => Object.hash(coins, gems);

  @override
  String toString() => 'Reward(coins: $coins, gems: $gems)';
}

/// One kind of card in the hourly gift: its [reward], and how often it
/// comes up compared with the others, as a [weight].
class GiftCard {
  const GiftCard(this.reward, this.weight);

  final Reward reward;
  final int weight;
}

/// The free gift a player can collect once every [interval]: a pick of one
/// card from [boardSize] face-down ones, each turning up one of [cards] by
/// their weights. Rewarded ads can then double the pick, pick another card,
/// or add the [bonus].
class HourlyGift {
  const HourlyGift({
    required this.interval,
    required this.cards,
    required this.bonus,
  });

  /// How many cards are laid out to pick from.
  static const boardSize = 10;

  final Duration interval;
  final List<GiftCard> cards;
  final Reward bonus;

  /// A card's reward, drawn by the weights. Which card the player tapped
  /// plays no part.
  Reward draw(Random random) {
    var roll = random.nextInt(cards.fold(0, (sum, card) => sum + card.weight));
    for (final card in cards) {
      roll -= card.weight;
      if (roll < 0) return card.reward;
    }
    throw StateError('The gift has no cards');
  }

  /// The [boardSize] rewards shown on the cards not picked, drawn by the
  /// weights from [seed], so the same collection always shows the same
  /// board.
  List<Reward> board(int seed) {
    final random = Random(seed);
    return [for (var i = 0; i < boardSize; i++) draw(random)];
  }
}

/// The game's two currencies.
enum Currency { coins, gems }

/// The rewarded ad: watching one ([length] long, as told to the player)
/// pays [coins], or [gems] when watched for gems, up to [perDay] times a
/// day.
class RewardedAd {
  const RewardedAd({
    required this.coins,
    this.gems = 0,
    required this.perDay,
    required this.length,
  });

  final int coins;
  final int gems;
  final int perDay;
  final Duration length;

  /// What watching one pays in [currency].
  Reward rewardIn(Currency currency) => switch (currency) {
    Currency.coins => Reward(coins: coins),
    Currency.gems => Reward(gems: gems),
  };
}

/// A pack sold in the shop: its store [id], the [reward] it gives, and its
/// [price] as shown until the store gives its own.
class ShopPack {
  const ShopPack({required this.id, required this.reward, required this.price});

  final String id;
  final Reward reward;
  final String price;
}

/// The packs on sale, coins and gems.
class Shop {
  const Shop({required this.coinPacks, required this.gemPacks});

  final List<ShopPack> coinPacks;
  final List<ShopPack> gemPacks;

  /// The packs of [currency].
  List<ShopPack> packsOf(Currency currency) => switch (currency) {
    Currency.coins => coinPacks,
    Currency.gems => gemPacks,
  };
}

/// The gems it costs to start a match at a stake table: [gems] at any
/// table whose stake, in coins a point, is above [aboveStake]. Tables at
/// or below it are free.
class EntryFee {
  const EntryFee({required this.gems, required this.aboveStake});

  final int gems;
  final int aboveStake;

  /// The gems a match at [stake] costs; 0 away from a stake table, when
  /// [stake] is `null`.
  int gemsFor(int? stake) => stake != null && stake > aboveStake ? gems : 0;
}

/// Every amount in the game's coin and gem economy, read from the data file
/// `assets/config/economy.json`, so the amounts can be tuned there without
/// touching the code.
class EconomyConfig {
  const EconomyConfig({
    required this.startingGems,
    required this.hourlyGift,
    required this.rewardedAd,
    required this.entryFee,
    required this.shop,
  });

  /// Reads the amounts from the data file's JSON:
  ///
  /// ```json
  /// {
  ///   "startingGems": 3,
  ///   "hourlyGift": {
  ///     "minutes": 60,
  ///     "cards": [{"coins": 500, "weight": 30}, {"gems": 1, "weight": 8}],
  ///     "bonus": {"gems": 1}
  ///   },
  ///   "rewardedAd": {"coins": 1000, "gems": 1, "perDay": 5, "seconds": 30},
  ///   "entryFee": {"gems": 1, "aboveStake": 100},
  ///   "shop": {
  ///     "coins": [{"id": "coins_25k", "coins": 25000, "price": "\$0.99"}],
  ///     "gems": [{"id": "gems_10", "gems": 10, "price": "\$0.99"}]
  ///   }
  /// }
  /// ```
  ///
  /// Throws a [FormatException] naming the problem if the file is malformed
  /// or an amount doesn't make sense.
  factory EconomyConfig.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('The economy is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The economy needs a JSON object');
    }
    final gift = _object(decoded, 'hourlyGift');
    final ad = _object(decoded, 'rewardedAd');
    final fee = _object(decoded, 'entryFee');
    final shop = _object(decoded, 'shop');
    return EconomyConfig(
      startingGems: _count(decoded, 'startingGems'),
      hourlyGift: HourlyGift(
        interval: Duration(
          minutes: _count(gift, 'minutes', within: 'hourlyGift', least: 1),
        ),
        cards: _giftCards(gift),
        bonus: _reward(
          _object(gift, 'bonus', within: 'hourlyGift'),
          'hourlyGift.bonus',
        ),
      ),
      rewardedAd: RewardedAd(
        coins: _count(ad, 'coins', within: 'rewardedAd'),
        gems: ad.containsKey('gems')
            ? _count(ad, 'gems', within: 'rewardedAd')
            : 0,
        perDay: _count(ad, 'perDay', within: 'rewardedAd'),
        length: Duration(
          seconds: _count(ad, 'seconds', within: 'rewardedAd', least: 1),
        ),
      ),
      entryFee: EntryFee(
        gems: _count(fee, 'gems', within: 'entryFee'),
        aboveStake: _count(fee, 'aboveStake', within: 'entryFee'),
      ),
      shop: Shop(
        coinPacks: _packs(shop, 'coins'),
        gemPacks: _packs(shop, 'gems'),
      ),
    );
  }

  /// The data file, as listed in pubspec.yaml.
  static const asset = 'assets/config/economy.json';

  /// The gems a new player starts with.
  final int startingGems;

  final HourlyGift hourlyGift;
  final RewardedAd rewardedAd;
  final EntryFee entryFee;
  final Shop shop;

  /// The shop's packs of [kind], "coins" or "gems": each with an id, a
  /// price, and an amount of that kind.
  static List<ShopPack> _packs(Map<String, Object?> shop, String kind) {
    final packs = shop[kind];
    if (packs is! List<Object?>) {
      throw FormatException('The economy needs "shop.$kind", a list of packs');
    }
    return List.unmodifiable([
      for (final (i, pack) in packs.indexed)
        if (pack case {'id': final String id, 'price': final String price})
          ShopPack(
            id: id,
            price: price,
            reward: Reward.fromJson({
              kind: _count(
                pack as Map<String, Object?>,
                kind,
                within: 'shop.$kind[$i]',
                least: 1,
              ),
            }),
          )
        else
          throw FormatException(
            'The economy needs "shop.$kind[$i]" to have an id and a price',
          ),
    ]);
  }

  /// The gift's cards: a list of rewards, each with a weight from 1.
  static List<GiftCard> _giftCards(Map<String, Object?> gift) {
    final cards = gift['cards'];
    if (cards is! List<Object?> || cards.isEmpty) {
      throw const FormatException(
        'The economy needs "hourlyGift.cards", a list of rewards',
      );
    }
    return List.unmodifiable([
      for (final (i, card) in cards.indexed)
        if (card case final Map<String, Object?> card)
          GiftCard(
            _reward(card, 'hourlyGift.cards[$i]'),
            _count(card, 'weight', within: 'hourlyGift.cards[$i]', least: 1),
          )
        else
          throw FormatException(
            'The economy needs "hourlyGift.cards[$i]" to be an object',
          ),
    ]);
  }

  /// The reward in [json], the object named [within]: some coins, gems or
  /// both, and never nothing.
  static Reward _reward(Map<String, Object?> json, String within) {
    final reward = Reward(
      coins: json.containsKey('coins')
          ? _count(json, 'coins', within: within)
          : 0,
      gems: json.containsKey('gems') ? _count(json, 'gems', within: within) : 0,
    );
    if (reward == const Reward()) {
      throw FormatException(
        'The economy needs "$within" to give coins or gems',
      );
    }
    return reward;
  }

  /// The object under [key] in [json], which is the object named [within]
  /// if given.
  static Map<String, Object?> _object(
    Map<String, Object?> json,
    String key, {
    String? within,
  }) {
    if (json[key] case final Map<String, Object?> object) return object;
    final name = within == null ? key : '$within.$key';
    throw FormatException('The economy needs a "$name" object');
  }

  /// The whole number, [least] or more, under [key] in [json], which is the
  /// object named [within] if given.
  static int _count(
    Map<String, Object?> json,
    String key, {
    String? within,
    int least = 0,
  }) {
    if (json[key] case final int value when value >= least) return value;
    final name = within == null ? '"$key"' : '"$within.$key"';
    throw FormatException(
      'The economy needs $name, a whole number from $least',
    );
  }
}
