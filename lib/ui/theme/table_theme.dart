import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The table themes a player can choose from.
enum TableThemeId {
  classic('Classic'),
  midnight('Midnight'),
  dashain('Dashain');

  const TableThemeId(this.label);

  /// The theme's name in the settings.
  final String label;

  TableTheme get theme => switch (this) {
    classic => TableTheme.classic,
    midnight => TableTheme.midnight,
    dashain => TableTheme.dashain,
  };
}

/// The colours of the table and the cards' backs: one set per
/// [TableThemeId], attached to the app's [ThemeData] so any widget can read
/// it with [TableTheme.of].
///
/// A [ThemeExtension] rather than a plain provider, so the theme switches
/// the same way Material's own colours do and animates between themes.
@immutable
class TableTheme extends ThemeExtension<TableTheme> {
  const TableTheme({
    required this.felt,
    required this.panel,
    required this.cardBack,
    required this.cardBackEdge,
    required this.accent,
    required this.seed,
    required this.wood,
    this.inlay,
    this.motif = 0,
  });

  /// Green baize in a walnut rim, under warm light, with a red-backed deck.
  static const classic = TableTheme(
    felt: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0D3B12)],
    panel: Color(0xCC0D3B12),
    cardBack: [Color(0xFFB71C1C), Color(0xFF6D1010)],
    cardBackEdge: Color(0xFF8E1B1B),
    accent: Color(0xFFFFD54F),
    seed: Color(0xFF1B5E20),
    wood: [Color(0xFF8D5A3B), Color(0xFF6B4226), Color(0xFF3E2414)],
  );

  /// A dark slate table in an ebony rim, with a navy deck and cool teal
  /// highlights.
  static const midnight = TableTheme(
    felt: [Color(0xFF37474F), Color(0xFF232E35), Color(0xFF11181C)],
    panel: Color(0xCC11181C),
    cardBack: [Color(0xFF1E4F8A), Color(0xFF0D2A4F)],
    cardBackEdge: Color(0xFF123761),
    accent: Color(0xFF4DD0E1),
    seed: Color(0xFF37474F),
    wood: [Color(0xFF4A4038), Color(0xFF2B2420), Color(0xFF141110)],
  );

  /// Festival colours: a deep red table scattered with faint kites, in a
  /// rosewood rim with a gold inlay, and a marigold deck.
  static const dashain = TableTheme(
    felt: [Color(0xFF9C2A2A), Color(0xFF6E1A22), Color(0xFF3E0C14)],
    panel: Color(0xCC3E0C14),
    cardBack: [Color(0xFFFFA000), Color(0xFFD84315)],
    cardBackEdge: Color(0xFFBF5B00),
    accent: Color(0xFFFFCA28),
    seed: Color(0xFF9C2A2A),
    wood: [Color(0xFF9A4A35), Color(0xFF6E2C20), Color(0xFF3D1510)],
    inlay: Color(0xFFE0B04A),
    motif: 1,
  );

  /// The table's background, from the centre outwards.
  final List<Color> felt;

  /// Behind small labels and badges laid over the table.
  final Color panel;

  /// The face-down card's gradient, top left to bottom right.
  final List<Color> cardBack;

  /// The darker colour a face-down card's pattern is printed in.
  final Color cardBackEdge;

  /// Highlights: whose turn it is, and selected things.
  final Color accent;

  /// The colour Material's own widgets (buttons, dialogs) are derived from.
  final Color seed;

  /// The table's wooden rim, light to dark: where the light catches it,
  /// its body, and its grain and shadows.
  final List<Color> wood;

  /// A thin line set into the middle of the rim, if the theme has one.
  final Color? inlay;

  /// How strongly the theme's kite pattern shows on the felt, from 0 (no
  /// pattern) to 1.
  final double motif;

  /// The table theme in [context], or [classic] when none is attached.
  static TableTheme of(BuildContext context) =>
      Theme.of(context).extension<TableTheme>() ?? classic;

  /// The felt as a decoration, for a screen's background.
  BoxDecoration get feltDecoration =>
      BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: felt));

  @override
  TableTheme copyWith({
    List<Color>? felt,
    Color? panel,
    List<Color>? cardBack,
    Color? cardBackEdge,
    Color? accent,
    Color? seed,
    List<Color>? wood,
    Color? inlay,
    double? motif,
  }) => TableTheme(
    felt: felt ?? this.felt,
    panel: panel ?? this.panel,
    cardBack: cardBack ?? this.cardBack,
    cardBackEdge: cardBackEdge ?? this.cardBackEdge,
    accent: accent ?? this.accent,
    seed: seed ?? this.seed,
    wood: wood ?? this.wood,
    inlay: inlay ?? this.inlay,
    motif: motif ?? this.motif,
  );

  @override
  TableTheme lerp(TableTheme? other, double t) {
    if (other == null) return this;
    List<Color> colors(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
    return TableTheme(
      felt: colors(felt, other.felt),
      panel: Color.lerp(panel, other.panel, t)!,
      cardBack: colors(cardBack, other.cardBack),
      cardBackEdge: Color.lerp(cardBackEdge, other.cardBackEdge, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      seed: Color.lerp(seed, other.seed, t)!,
      wood: colors(wood, other.wood),
      inlay: Color.lerp(inlay, other.inlay, t),
      motif: lerpDouble(motif, other.motif, t)!,
    );
  }
}
