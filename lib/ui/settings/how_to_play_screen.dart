import 'package:flutter/material.dart';

import '../../engine/scoring.dart';
import '../table/suit_icon.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';

/// The rules as this game plays them, and how to handle the cards, in short
/// sections on the table's felt.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static final sections = [
    (
      'The aim',
      'Arrange all 21 of your cards into sets, then make one final discard '
          'to win the round. Sets are sequences (3 or more cards in a row of '
          'one suit), trials (3 cards of one rank in different suits) and '
          'tunnellas (3 identical cards).',
    ),
    (
      'Each turn',
      'Draw a card from the stock or take the top of the discard pile, then '
          'discard one card. A card you take from the discard pile must be '
          'kept that turn.',
    ),
    (
      'Handling your cards',
      'Tap the stock or the discard pile to draw, or drag it onto your '
          'hand. To discard, drag a card up onto the pile, flick it '
          'upwards, or tap it and then tap the pile. Long-press a card to '
          'move it within your hand, or tap Sort. Select cards and tap '
          'Group to make a set, then Show when you have enough.',
    ),
    (
      'Seeing the joker',
      'Before you can use jokers, show 3 pure sets (sequences or '
          'tunnellas with no jokers) or 7 doublees (pairs of identical '
          'cards). Tunnellas you\'re dealt are shown at the start and count '
          'toward the 3. The first player to show picks the joker card '
          '(the tiplu) from the stock.',
    ),
    (
      'Jokers',
      'Once you\'ve seen it, every card of the tiplu\'s rank is wild, and '
          'so are the cards one rank below and above it in its suit (the '
          'jhiplu and poplu). Wild cards can fill gaps in sequences and '
          'trials. Wild cards in your hand glow gold. Once you\'ve seen '
          'the joker, throwing a wild card away costs '
          '${ScoringTable.jokerDiscardPenalty} points, paid to the round\'s '
          'winner, so the game asks first.',
    ),
    (
      'Maal',
      'After seeing the joker, these cards earn points: tiplu, jhiplu, '
          'poplu and alter (same rank and colour as the tiplu). A jhiplu, '
          'tiplu and poplu together make a marriage, worth more.',
    ),
    (
      'Winning and scoring',
      'When someone wins, everyone\'s maal is settled between players, and '
          'the winner collects 3 from each player who saw the joker and 10 '
          'from each who didn\'t (5 more each for a doublee win). Your '
          'result each round adds to or takes from your coins.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('How to play'),
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: TableFelt(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              for (final (title, body) in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: theme.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          DefaultTextStyle.merge(
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.35,
                            ),
                            child: SuitText(body),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
