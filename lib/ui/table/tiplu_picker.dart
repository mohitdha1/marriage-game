import 'package:flutter/material.dart';

import 'card_view.dart';

/// Shown when the human player is the first to show: the stock is spread out
/// face down, and they tap any card to make it the tiplu. [again] says
/// their last pick was a printed joker, kept aside; there's no cancelling then,
/// since the sets are already shown.
class TipluPicker extends StatelessWidget {
  const TipluPicker({
    super.key,
    required this.stockCount,
    required this.onPick,
    required this.onCancel,
    this.again = false,
  });

  final int stockCount;

  /// Called with the picked card's position in the stock, 0 being the top.
  final void Function(int position) onPick;
  final VoidCallback onCancel;
  final bool again;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                again
                    ? 'That card can\'t be the joker, so it\'s kept aside '
                          'as your maal. Pick another card to be the joker.'
                    : 'You are the first to show. Pick any card from the '
                          'stock to be the joker.',
                key: const Key('tiplu-picker-title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < stockCount; i++)
                        GestureDetector(
                          key: Key('stock-card-$i'),
                          onTap: () => onPick(i),
                          child: const CardBack(width: 28),
                        ),
                    ],
                  ),
                ),
              ),
              if (!again) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
