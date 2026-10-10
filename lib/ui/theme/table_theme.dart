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
    this.motif = 0,
  });

  /// Green baize under warm light, with a red-backed deck.
  static const classic = TableTheme(
    felt: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0D3B12)],
    panel: Color(0xCC0D3B12),
    cardBack: [Color(0xFFB71C1C), Color(0xFF6D1010)],
    cardBackEdge: Color(0xFF8E1B1B),
    accent: Color(0xFFFFD54F),
    seed: Color(0xFF1B5E20),
  );

  /// A dark slate table with a navy deck and cool teal highlights.
  static const midnight = TableTheme(
    felt: [Color(0xFF37474F), Color(0xFF232E35), Color(0xFF11181C)],
    panel: Color(0xCC11181C),
    cardBack: [Color(0xFF1E4F8A), Color(0xFF0D2A4F)],
    cardBackEdge: Color(0xFF123761),
    accent: Color(0xFF4DD0E1),
    seed: Color(0xFF37474F),
  );

  /// Festival colours: a deep red table scattered with faint kites, and a
  /// marigold deck.
  static const dashain = TableTheme(
    felt: [Color(0xFF9C2A2A), Color(0xFF6E1A22), Color(0xFF3E0C14)],
    panel: Color(0xCC3E0C14),
    cardBack: [Color(0xFFFFA000), Color(0xFFD84315)],
    cardBackEdge: Color(0xFFBF5B00),
    accent: Color(0xFFFFCA28),
    seed: Color(0xFF9C2A2A),
    motif: 1,
  );

  /// The table's background, from the centre outwards.
  final List<Color> felt;

  /// Behind small labels and badges laid over the table.
  final Color panel;

  /// The face-down card's gradient, top left to bottom right.
  final List<Color> cardBack;

  /// The border round a face-down card.
  final Color cardBackEdge;

  /// Highlights: whose turn it is, and selected things.
  final Color accent;

  /// The colour Material's own widgets (buttons, dialogs) are derived from.
  final Color seed;

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
    double? motif,
  }) => TableTheme(
    felt: felt ?? this.felt,
    panel: panel ?? this.panel,
    cardBack: cardBack ?? this.cardBack,
    cardBackEdge: cardBackEdge ?? this.cardBackEdge,
    accent: accent ?? this.accent,
    seed: seed ?? this.seed,
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
      motif: lerpDouble(motif, other.motif, t)!,
    );
  }
}

/// The felt of the current [TableTheme], filling its space, with the
/// theme's faint kite pattern when it has one.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return DecoratedBox(
      decoration: theme.feltDecoration,
      child: theme.motif == 0
          ? child
          : CustomPaint(
              key: const Key('felt-motif'),
              painter: _KitePainter(theme.motif),
              child: child,
            ),
    );
  }
}

/// Faint diamond kites with tails, scattered in a loose grid.
class _KitePainter extends CustomPainter {
  const _KitePainter(this.strength);

  final double strength;

  static const _spacing = 150.0;
  static const _size = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.06 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    var row = 0;
    for (var y = _spacing / 2; y < size.height + _size; y += _spacing * 0.7) {
      // Every other row shifts half a step, so the kites don't line up.
      final shift = row.isOdd ? _spacing / 2 : 0.0;
      for (var x = shift; x < size.width + _size; x += _spacing) {
        final kite = Path()
          ..moveTo(x, y - _size)
          ..lineTo(x + _size * 0.7, y)
          ..lineTo(x, y + _size)
          ..lineTo(x - _size * 0.7, y)
          ..close()
          ..moveTo(x, y - _size)
          ..lineTo(x, y + _size)
          ..moveTo(x - _size * 0.7, y)
          ..lineTo(x + _size * 0.7, y)
          // The tail.
          ..moveTo(x, y + _size)
          ..quadraticBezierTo(
            x + _size * 0.5,
            y + _size * 1.5,
            x,
            y + _size * 2,
          );
        canvas.drawPath(kite, paint);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_KitePainter old) => old.strength != strength;
}
