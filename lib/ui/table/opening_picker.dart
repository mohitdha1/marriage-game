import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../../engine/player_hand.dart';
import 'card_view.dart';

/// Shown when the human player was dealt more than 3 tunnellas: they pick
/// which 3 to lay down in the opening show.
class OpeningPicker extends StatefulWidget {
  const OpeningPicker({
    super.key,
    required this.tunnellas,
    required this.onConfirm,
  });

  final List<List<PlayingCard>> tunnellas;

  /// Called with the indexes of the 3 chosen tunnellas.
  final void Function(List<int> picks) onConfirm;

  @override
  State<OpeningPicker> createState() => _OpeningPickerState();
}

class _OpeningPickerState extends State<OpeningPicker> {
  final _picks = <int>[];

  void _toggle(int index) {
    setState(() {
      if (!_picks.remove(index) &&
          _picks.length < PlayerHand.maxOpeningTunnellas) {
        _picks.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _picks.length == PlayerHand.maxOpeningTunnellas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You were dealt ${widget.tunnellas.length} tunnellas. '
              'Choose 3 to show.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < widget.tunnellas.length; i++)
                  GestureDetector(
                    key: Key('opening-tunnella-$i'),
                    onTap: () => _toggle(i),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final card in widget.tunnellas[i])
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: CardFace(
                              card,
                              width: 36,
                              highlighted: _picks.contains(i),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ready ? () => widget.onConfirm([..._picks]) : null,
              child: const Text('Show these 3'),
            ),
          ],
        ),
      ),
    );
  }
}
