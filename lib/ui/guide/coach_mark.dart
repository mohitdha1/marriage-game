import 'package:flutter/material.dart';

/// A tip in a slim pill, about 30 pixels tall: a light bulb, a line of
/// advice, a Got it button if the tip doesn't go away by itself, and a
/// close button that skips the whole guide.
///
/// Only the buttons catch touches, so a tip lying over the table never
/// stops a card being tapped or dragged underneath it.
class CoachMark extends StatelessWidget {
  const CoachMark({
    super.key,
    required this.text,
    required this.onSkip,
    this.onGotIt,
  });

  final String text;
  final VoidCallback onSkip;

  /// Shows a Got it button when set.
  final VoidCallback? onGotIt;

  static const _paper = Color(0xFFFFFDF5);
  static const _ink = Color(0xFF3E2723);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
            child: Row(
              children: [
                const IgnorePointer(
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Color(0xFFE09B00),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: IgnorePointer(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                if (onGotIt != null)
                  TextButton(
                    key: const Key('guide-got-it'),
                    onPressed: onGotIt,
                    style: TextButton.styleFrom(
                      foregroundColor: _ink,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Got it'),
                  ),
                IconButton(
                  key: const Key('guide-skip'),
                  onPressed: onSkip,
                  tooltip: 'Skip guide',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0x993E2723),
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
