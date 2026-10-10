import 'package:flutter/material.dart';

import '../table/suit_icon.dart';

/// The rules as this game plays them, in short sections.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const sections = [
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
          'trials. Wild cards in your hand glow gold.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('How to play'), toolbarHeight: 44),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (title, body) in sections) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              SuitText(body, redColor: redSuitColor),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
