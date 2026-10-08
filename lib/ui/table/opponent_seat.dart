import 'package:flutter/material.dart';

import '../state/table_view.dart';
import 'card_view.dart';

/// An opponent at the table: avatar, name, and how many cards they hold.
class OpponentSeat extends StatelessWidget {
  const OpponentSeat({super.key, required this.seat});

  final SeatView seat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFFE0B2),
            foregroundColor: const Color(0xFF4E342E),
            child: Text(
              seat.name.characters.first,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
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
            ],
          ),
        ],
      ),
    );
  }
}
