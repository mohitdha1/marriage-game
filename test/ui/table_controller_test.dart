import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_state.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
final twoOfDiamonds = c(Suit.diamonds, Rank.two);
final queenOfDiamonds = c(Suit.diamonds, Rank.queen);
final kingOfClubs = c(Suit.clubs, Rank.king);

/// The human player's usual hand: 3 pure runs and a few loose cards.
final yourCards = [
  ...heartsRun,
  ...spadesRun,
  ...clubsRun,
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  twoOfDiamonds,
];

/// A bot hand with nothing to show, so the bot only draws and discards.
final idleBotCards = run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]);

/// A container whose round deals [yourHand] to the human player (seat 0)
/// and [botHand] to one bot, with the stock's top card last.
ProviderContainer tableWith({
  List<PlayingCard>? yourHand,
  List<PlayingCard>? botHand,
  List<PlayingCard>? stock,
  List<PlayingCard>? discardPile,
  int firstSeat = 0,
}) {
  final container = ProviderContainer(
    overrides: [
      randomProvider.overrideWithValue(Random(0)),
      roundFactoryProvider.overrideWithValue(
        () => Round.fromCards(
          config: GameConfig(playerCount: 2),
          random: Random(0),
          hands: [yourHand ?? yourCards, botHand ?? idleBotCards],
          stock:
              stock ??
              [
                c(Suit.clubs, Rank.five),
                c(Suit.hearts, Rank.seven),
                c(Suit.clubs, Rank.two),
                queenOfDiamonds,
              ],
          discardPile: discardPile ?? [kingOfClubs],
          firstSeat: firstSeat,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

extension on ProviderContainer {
  TableState get table => read(tableProvider);
  TableController get controller => read(tableProvider.notifier);

  /// Selects the hand cards equal to [cards] (one copy each) and groups
  /// them.
  void group(List<PlayingCard> cards) {
    final used = <int>{};
    for (final card in cards) {
      final id = table.hand
          .firstWhere((c) => c.card == card && !used.contains(c.id))
          .id;
      used.add(id);
      controller.toggleSelected(id);
    }
    controller.groupSelected();
  }

  /// The id of the first card in hand equal to [card].
  int idOf(PlayingCard card) =>
      table.hand.firstWhere((handCard) => handCard.card == card).id;
}

void main() {
  group('Dealing', () {
    test('the hand is shown in dealt order, every card with its own id', () {
      final table = tableWith().table;

      expect(table.hand.map((c) => c.card), yourCards);
      expect(table.hand.map((c) => c.id).toSet(), hasLength(yourCards.length));
      expect(table.view.isYourTurn, isTrue);
    });

    test('dealt tunnellas are laid down automatically', () {
      final kings = tunnellaOf(c(Suit.spades, Rank.king));
      final table = tableWith(yourHand: [...heartsRun, ...kings]).table;

      expect(table.hand.map((c) => c.card), heartsRun);
      expect(table.openingChoice, isNull);
    });
  });

  group('Opening with more than 3 tunnellas', () {
    final fourTunnellas = [
      for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
        ...tunnellaOf(c(Suit.clubs, rank)),
    ];

    test('the player is asked to choose, and play waits', () {
      final container = tableWith(yourHand: fourTunnellas);

      expect(container.table.openingChoice, hasLength(4));
      expect(container.table.hand, hasLength(12));

      container.controller.draw(DrawSource.stock);
      expect(
        container.table.notice,
        'Every player must make their opening show first',
      );
    });

    test('an invalid choice is refused', () {
      final container = tableWith(yourHand: fourTunnellas);

      container.controller.chooseOpeningTunnellas([0, 0, 1]);

      expect(container.table.notice, 'Choose 3 different tunnellas.');
      expect(container.table.openingChoice, isNotNull);
    });

    test('choosing 3 lays them down and play starts', () {
      final container = tableWith(yourHand: fourTunnellas);

      container.controller.chooseOpeningTunnellas([0, 1, 3]);

      expect(container.table.openingChoice, isNull);
      expect(
        container.table.hand.map((c) => c.card),
        tunnellaOf(c(Suit.clubs, Rank.nine)),
      );
      container.controller.draw(DrawSource.stock);
      expect(container.table.view.youHaveDrawn, isTrue);
    });
  });

  group('Selecting and sorting', () {
    test('tapping a card selects it, tapping again deselects it', () {
      final container = tableWith();
      final id = container.idOf(twoOfDiamonds);

      container.controller.toggleSelected(id);
      expect(container.table.selected, {id});

      container.controller.toggleSelected(id);
      expect(container.table.selected, isEmpty);
    });

    test('identical cards are selected separately', () {
      final container = tableWith(yourHand: [...yourCards, twoOfDiamonds]);
      final twos = container.table.hand
          .where((c) => c.card == twoOfDiamonds)
          .map((c) => c.id)
          .toList();

      container.controller.toggleSelected(twos.first);

      expect(container.table.selected, {twos.first});
    });

    test(
      'Sort orders the hand by suit, then rank, keeping each card\'s id',
      () {
        final container = tableWith();
        final idsBefore = {for (final c in container.table.hand) c.id: c.card};

        container.controller.sortHand();

        final sorted = container.table.hand;
        for (var i = 1; i < sorted.length; i++) {
          final a = sorted[i - 1].card;
          final b = sorted[i].card;
          expect(
            a.suit.index < b.suit.index ||
                (a.suit == b.suit && a.rank.order <= b.rank.order),
            isTrue,
            reason: '$a should come before $b',
          );
        }
        for (final handCard in sorted) {
          expect(idsBefore[handCard.id], handCard.card);
        }
      },
    );
  });

  group('Drawing', () {
    test('drawing from the stock adds the card at the right-hand end', () {
      final container = tableWith();

      container.controller.draw(DrawSource.stock);

      expect(container.table.hand.last.card, queenOfDiamonds);
      expect(container.table.hand, hasLength(yourCards.length + 1));
      expect(container.table.view.youHaveDrawn, isTrue);
    });

    test('a second draw is refused with the engine\'s reason', () {
      final container = tableWith();

      container.controller
        ..draw(DrawSource.stock)
        ..draw(DrawSource.stock);

      expect(container.table.notice, 'Already drew this turn; discard first');
      expect(container.table.hand, hasLength(yourCards.length + 1));
    });

    test('tapping the discard pile before drawing takes its top card', () {
      final container = tableWith();

      container.controller.tapDiscardPile();

      expect(container.table.hand.last.card, kingOfClubs);
      expect(container.table.view.topDiscard, isNull);
    });

    test('a sorted hand stays in place when a card is drawn', () {
      final container = tableWith()..controller.sortHand();
      final sorted = container.table.hand;

      container.controller.draw(DrawSource.stock);

      expect(container.table.hand.take(sorted.length), sorted);
    });
  });

  group('Discarding', () {
    test(
      'discarding ends the turn; the bot plays and it is your turn again',
      () {
        final container = tableWith()..controller.draw(DrawSource.stock);

        container.controller.discard(container.idOf(twoOfDiamonds));

        final table = container.table;
        expect(table.hand.map((c) => c.card), isNot(contains(twoOfDiamonds)));
        expect(table.view.isYourTurn, isTrue);
        expect(table.view.youHaveDrawn, isFalse);
        expect(table.view.stockCount, 2, reason: 'you and the bot each drew');
      },
    );

    test('tapping the pile discards the selected card', () {
      final container = tableWith()..controller.draw(DrawSource.stock);
      container.controller
        ..toggleSelected(container.idOf(twoOfDiamonds))
        ..tapDiscardPile();

      expect(
        container.table.hand.map((c) => c.card),
        isNot(contains(twoOfDiamonds)),
      );
      expect(container.table.selected, isEmpty);
    });

    test('tapping the pile with nothing selected explains what to do', () {
      final container = tableWith()..controller.draw(DrawSource.stock);

      container.controller.tapDiscardPile();

      expect(
        container.table.notice,
        'Select one card, then tap the discard pile.',
      );
    });

    test('a card just taken from the discard pile cannot be discarded', () {
      final container = tableWith()..controller.tapDiscardPile();
      container.controller.discard(container.idOf(kingOfClubs));

      expect(
        container.table.notice,
        'K♣ was just taken from the discard pile and must be kept this turn',
      );
      expect(container.table.view.isYourTurn, isTrue);
    });

    test('discarding one of two identical cards removes just that one', () {
      final container = tableWith(yourHand: [...yourCards, twoOfDiamonds])
        ..controller.draw(DrawSource.stock);

      container.controller.discard(container.idOf(twoOfDiamonds));

      expect(
        container.table.hand.where((c) => c.card == twoOfDiamonds),
        hasLength(1),
      );
    });
  });

  group('Bots', () {
    test('a bot that wins ends the round, and the player is told', () {
      // The bot holds 3 runs and 8♥ Q♣ Q♦. After you discard 3♥ it draws
      // 2♣, shows, picks 7♥ (the only stock card left) as the tiplu, and
      // wins with 8♥ as a joker in a Q trial.
      final container = tableWith(
        botHand: [
          ...run(Suit.spades, [Rank.jack, Rank.queen, Rank.king]),
          ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
          ...run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]),
          c(Suit.hearts, Rank.eight),
          c(Suit.clubs, Rank.queen),
          queenOfDiamonds,
        ],
        stock: [c(Suit.hearts, Rank.seven), c(Suit.clubs, Rank.two)],
      )..controller.tapDiscardPile();

      container.controller.discard(container.idOf(c(Suit.hearts, Rank.three)));

      final table = container.table;
      expect(table.view.winner?.name, 'Bot 1');
      expect(table.notice, 'Bot 1 won the round.');
      expect(table.view.isYourTurn, isFalse);
    });
  });

  group('Grouping', () {
    test('grouping needs at least 2 selected cards', () {
      final container = tableWith();
      container.controller
        ..toggleSelected(container.idOf(twoOfDiamonds))
        ..groupSelected();

      expect(container.table.notice, 'Select 2 or more cards to group.');
      expect(container.table.groups, isEmpty);
    });

    test('grouped cards move to the left, in the order they were grouped', () {
      final container = tableWith()
        ..group(clubsRun)
        ..group(heartsRun);

      expect(container.table.hand.take(6).map((c) => c.card), [
        ...clubsRun,
        ...heartsRun,
      ]);
      expect(container.table.groups, hasLength(2));
      expect(container.table.groupOf(container.idOf(clubsRun.first)), 0);
      expect(container.table.groupOf(container.idOf(heartsRun.first)), 1);
      expect(container.table.groupOf(container.idOf(twoOfDiamonds)), isNull);
      expect(container.table.selected, isEmpty);
    });

    test('grouping a card that is already grouped moves it', () {
      final container = tableWith()
        ..group(heartsRun)
        ..group([heartsRun.first, twoOfDiamonds]);

      expect(container.table.groups, hasLength(2));
      expect(container.table.groups.first, hasLength(2));
    });

    test('Ungroup clears every group', () {
      final container = tableWith()..group(heartsRun);

      container.controller.clearGroups();

      expect(container.table.groups, isEmpty);
    });
  });

  group('Showing', () {
    test('Show with nothing grouped explains what to do', () {
      final container = tableWith()..controller.showGroups();

      expect(container.table.notice, 'Group your sets first, then tap Show.');
    });

    test('the first to show picks the tiplu, then sees the joker', () {
      final container = tableWith()
        ..controller.draw(DrawSource.stock) // Q♦; stock is now 2♣, 7♥, 5♣
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun);

      container.controller.showGroups();
      expect(container.table.pickingTiplu, isTrue);
      expect(container.table.view.isJokerChosen, isFalse);

      container.controller.pickTiplu(1);

      final table = container.table;
      expect(table.pickingTiplu, isFalse);
      expect(table.view.yourJokers?.tiplu, c(Suit.hearts, Rank.seven));
      expect(table.view.youHaveSeenJoker, isTrue);
      expect(table.revealingJoker, isTrue);
      expect(table.groups, isEmpty);
      expect(table.view.you.laidDown, [heartsRun, spadesRun, clubsRun]);
      expect(
        table.hand.map((c) => c.card),
        isNot(anyElement(isIn([...heartsRun, ...spadesRun, ...clubsRun]))),
      );

      container.controller.dismissReveal();
      expect(container.table.revealingJoker, isFalse);
    });

    test('a refused show keeps the groups and does not use up the tiplu', () {
      final container = tableWith()
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..group(spadesRun)
        ..controller.showGroups()
        ..controller.pickTiplu(1);

      expect(container.table.notice, 'must show exactly 3');
      expect(container.table.view.isJokerChosen, isFalse);
      expect(container.table.groups, hasLength(2));
      expect(container.table.revealingJoker, isFalse);
    });

    test('cancelling the tiplu pick shows nothing', () {
      final container = tableWith()
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..controller.showGroups()
        ..controller.cancelTipluPick();

      expect(container.table.pickingTiplu, isFalse);
      expect(container.table.view.youHaveSeenJoker, isFalse);
    });

    test('once a bot has picked the tiplu, Show sees it straight away', () {
      // The bot shows on its first turn (picking the tiplu) but can't win.
      final container = tableWith(
        botHand: [
          ...run(Suit.spades, [Rank.jack, Rank.queen, Rank.king]),
          ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
          ...run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]),
          c(Suit.hearts, Rank.nine),
          c(Suit.clubs, Rank.queen),
        ],
      )..controller.draw(DrawSource.stock);
      container.controller.discard(container.idOf(twoOfDiamonds));
      expect(container.table.view.isJokerChosen, isTrue);
      expect(container.table.view.yourJokers, isNull);
      expect(container.table.view.opponents.single.hasSeenJoker, isTrue);

      container
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun)
        ..controller.showGroups();

      expect(container.table.pickingTiplu, isFalse);
      expect(container.table.view.yourJokers, isNotNull);
      expect(container.table.revealingJoker, isTrue);
    });

    test('7 grouped pairs are shown as doublees', () {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.three,
          Rank.four,
          Rank.five,
          Rank.nine,
          Rank.ten,
          Rank.jack,
        ])
          [c(Suit.clubs, rank), c(Suit.clubs, rank)],
      ];
      final container = tableWith(
        yourHand: [...pairs.expand((p) => p), c(Suit.spades, Rank.king)],
      )..controller.draw(DrawSource.stock);
      for (final pair in pairs) {
        container.group(pair);
      }

      container.controller
        ..showGroups()
        ..pickTiplu(1);

      expect(container.table.view.youHaveSeenJoker, isTrue);
      expect(container.table.view.you.laidDown, pairs);
    });
  });

  group('Winning', () {
    // After drawing Q♦ and showing the 3 runs with 7♥ as the tiplu, the hand
    // is K♠ K♦ 7♣ 10♦ J♦ 8♥ 2♦ Q♦: discarding 2♦ wins (K♠ K♦ + joker,
    // 10♦ J♦ Q♦ + joker), discarding 10♦ doesn't.
    ProviderContainer readyToWin() =>
        tableWith(
            yourHand: [
              ...yourCards.take(9),
              c(Suit.spades, Rank.king),
              c(Suit.diamonds, Rank.king),
              c(Suit.clubs, Rank.seven),
              c(Suit.diamonds, Rank.ten),
              c(Suit.diamonds, Rank.jack),
              c(Suit.hearts, Rank.eight),
              twoOfDiamonds,
            ],
          )
          ..controller.draw(DrawSource.stock)
          ..group(heartsRun)
          ..group(spadesRun)
          ..group(clubsRun)
          ..controller.showGroups()
          ..controller.pickTiplu(1);

    test('the cards that would win if discarded are known', () {
      final container = readyToWin();

      expect(
        container.table.winningDiscards,
        contains(container.idOf(twoOfDiamonds)),
      );
      expect(
        container.table.winningDiscards,
        isNot(contains(container.idOf(c(Suit.diamonds, Rank.ten)))),
      );
    });

    test('Win with nothing selected explains what to do', () {
      final container = readyToWin()..controller.declareWin();

      expect(
        container.table.notice,
        'Select the card to discard, then tap Win.',
      );
    });

    test('a discard that does not win is refused', () {
      final container = readyToWin();
      container.controller
        ..toggleSelected(container.idOf(c(Suit.diamonds, Rank.ten)))
        ..declareWin();

      expect(
        container.table.notice,
        '10♦ does not leave a winning hand when discarded',
      );
      expect(container.table.view.winner, isNull);
    });

    test('a winning discard ends the round', () {
      final container = readyToWin();
      container.controller
        ..toggleSelected(container.idOf(twoOfDiamonds))
        ..declareWin();

      expect(container.table.view.winner?.name, 'You');
      expect(container.table.notice, 'You won the round!');
      expect(container.table.winningDiscards, isEmpty);
    });

    test('nothing wins before the joker is seen', () {
      final container = tableWith()..controller.draw(DrawSource.stock);

      expect(container.table.winningDiscards, isEmpty);
    });
  });
}
