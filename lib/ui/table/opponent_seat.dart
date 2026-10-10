import 'package:flutter/material.dart';

import '../state/table_view.dart';
import 'card_view.dart';

/// An opponent at the table: avatar beside their name, how many cards they
/// hold, and whether they've seen the joker. Laid out in a row to stay short,
/// so seats along the top leave room for the piles below. The seat glows
/// while it's their turn.
class OpponentSeat extends StatelessWidget {
  const OpponentSeat({
    super.key,
    required this.seat,
    this.isCurrentTurn = false,
    this.lastMove,
  });

  final SeatView seat;
  final bool isCurrentTurn;

  /// The player's latest move in a few words, such as "Took 7♣, threw 9♦".
  final String? lastMove;

  static const _glow = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: Key('seat-${seat.seat}'),
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? _glow : Colors.transparent,
          width: 2,
        ),
        boxShadow: isCurrentTurn
            ? const [BoxShadow(color: Color(0x99FFD54F), blurRadius: 12)]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(seat.avatarColor ?? 0xFFFFE0B2),
            foregroundColor: const Color(0xFF4E342E),
            child: Text(
              seat.name.characters.first,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CardBack(width: 10),
                  const SizedBox(width: 4),
                  Text(
                    '${seat.cardCount}',
                    key: Key('card-count-${seat.seat}'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (seat.hasSeenJoker) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: Key('seen-${seat.seat}'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Seen',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
              if (lastMove != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    lastMove!,
                    key: Key('last-move-${seat.seat}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
