/// The hair an avatar is drawn with.
enum HairStyle { short, side, cropped, curly, long, bun, ponytail, bald }

/// Something an avatar wears or has: a pair of glasses, a dhaka topi (the
/// patterned Nepali cap), earrings, a scarf, a moustache or a beard.
enum AvatarExtra { none, glasses, topi, earrings, scarf, moustache, beard }

/// How an avatar is drawn: a cartoon face built from parts, so every look
/// is crisp at any size and needs no image files. Colours are 0xAARRGGBB.
class AvatarLook {
  const AvatarLook({
    required this.background,
    required this.skin,
    required this.hair,
    required this.hairColor,
    required this.shirt,
    this.extra = AvatarExtra.none,
  });

  final int background;
  final int skin;
  final HairStyle hair;
  final int hairColor;
  final int shirt;
  final AvatarExtra extra;

  static const _brown = 0xFFC68642;
  static const _tan = 0xFFE0AC69;
  static const _light = 0xFFF1C27D;
  static const _deep = 0xFF8D5524;
  static const _black = 0xFF1B1B1B;
  static const _darkBrown = 0xFF3B2314;
  static const _grey = 0xFF9E9E9E;

  /// Every look to choose from, by its number. Players pick from all of
  /// them; each bot has its own.
  static const presets = [
    AvatarLook(
      background: 0xFFFFCC80,
      skin: _brown,
      hair: HairStyle.short,
      hairColor: _black,
      shirt: 0xFF1E88E5,
    ),
    AvatarLook(
      background: 0xFFF8BBD0,
      skin: _tan,
      hair: HairStyle.long,
      hairColor: _black,
      shirt: 0xFFD81B60,
      extra: AvatarExtra.earrings,
    ),
    AvatarLook(
      background: 0xFFB3E5FC,
      skin: _light,
      hair: HairStyle.side,
      hairColor: _darkBrown,
      shirt: 0xFF43A047,
      extra: AvatarExtra.glasses,
    ),
    AvatarLook(
      background: 0xFFC8E6C9,
      skin: _brown,
      hair: HairStyle.bun,
      hairColor: _black,
      shirt: 0xFF8E24AA,
    ),
    AvatarLook(
      background: 0xFFD1C4E9,
      skin: _tan,
      hair: HairStyle.cropped,
      hairColor: _black,
      shirt: 0xFFE53935,
      extra: AvatarExtra.topi,
    ),
    AvatarLook(
      background: 0xFFFFF59D,
      skin: _deep,
      hair: HairStyle.ponytail,
      hairColor: _black,
      shirt: 0xFF00897B,
      extra: AvatarExtra.scarf,
    ),
    AvatarLook(
      background: 0xFFFFAB91,
      skin: _brown,
      hair: HairStyle.short,
      hairColor: _darkBrown,
      shirt: 0xFF3949AB,
      extra: AvatarExtra.moustache,
    ),
    AvatarLook(
      background: 0xFFB2EBF2,
      skin: _light,
      hair: HairStyle.long,
      hairColor: _darkBrown,
      shirt: 0xFFFB8C00,
    ),
    AvatarLook(
      background: 0xFFDCEDC8,
      skin: _deep,
      hair: HairStyle.curly,
      hairColor: _black,
      shirt: 0xFF6D4C41,
    ),
    AvatarLook(
      background: 0xFFF0F4C3,
      skin: _tan,
      hair: HairStyle.bald,
      hairColor: _grey,
      shirt: 0xFF546E7A,
      extra: AvatarExtra.beard,
    ),
    AvatarLook(
      background: 0xFFE1BEE7,
      skin: _brown,
      hair: HairStyle.ponytail,
      hairColor: _darkBrown,
      shirt: 0xFF1E88E5,
      extra: AvatarExtra.glasses,
    ),
    AvatarLook(
      background: 0xFFFFE0B2,
      skin: _light,
      hair: HairStyle.cropped,
      hairColor: _black,
      shirt: 0xFF2E7D32,
      extra: AvatarExtra.topi,
    ),
    AvatarLook(
      background: 0xFFC5CAE9,
      skin: _tan,
      hair: HairStyle.bun,
      hairColor: _darkBrown,
      shirt: 0xFFC62828,
      extra: AvatarExtra.earrings,
    ),
    AvatarLook(
      background: 0xFFB2DFDB,
      skin: _deep,
      hair: HairStyle.side,
      hairColor: _black,
      shirt: 0xFFF9A825,
      extra: AvatarExtra.beard,
    ),
    AvatarLook(
      background: 0xFFFFCDD2,
      skin: _brown,
      hair: HairStyle.curly,
      hairColor: _darkBrown,
      shirt: 0xFF5E35B1,
      extra: AvatarExtra.scarf,
    ),
    AvatarLook(
      background: 0xFFCFD8DC,
      skin: _light,
      hair: HairStyle.short,
      hairColor: _grey,
      shirt: 0xFF00838F,
      extra: AvatarExtra.glasses,
    ),
    AvatarLook(
      background: 0xFFFFECB3,
      skin: _tan,
      hair: HairStyle.long,
      hairColor: 0xFF5D4037,
      shirt: 0xFF7CB342,
      extra: AvatarExtra.scarf,
    ),
    AvatarLook(
      background: 0xFFBBDEFB,
      skin: _deep,
      hair: HairStyle.cropped,
      hairColor: _black,
      shirt: 0xFFEF6C00,
      extra: AvatarExtra.moustache,
    ),
    AvatarLook(
      background: 0xFFF3E5F5,
      skin: _light,
      hair: HairStyle.ponytail,
      hairColor: 0xFF8D6E63,
      shirt: 0xFFAD1457,
      extra: AvatarExtra.earrings,
    ),
    AvatarLook(
      background: 0xFFE6EE9C,
      skin: _brown,
      hair: HairStyle.bald,
      hairColor: _black,
      shirt: 0xFF283593,
      extra: AvatarExtra.topi,
    ),
  ];
}
